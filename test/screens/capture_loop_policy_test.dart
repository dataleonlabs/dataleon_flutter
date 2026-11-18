import 'package:dataleon_flutter/screens/capture_loop_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyCaptureResponse', () {
    test('ok accepts the frame', () {
      final o = classifyCaptureResponse({'status': 'ok', 'message': null});
      expect(o.action, CaptureFrameAction.accept);
      expect(o.invalid, isFalse);
    });

    test('pending keeps going', () {
      final o = classifyCaptureResponse(
          {'status': 'pending', 'message': 'Vérification', 'details': {'reason': 'accept_consensus'}});
      expect(o.action, CaptureFrameAction.retry);
      expect(o.message, 'Vérification');
      expect(o.reason, 'accept_consensus');
    });

    test('ko for one frame is guidance, not a stop', () {
      final o = classifyCaptureResponse({
        'status': 'ko',
        'message': 'Placez la <k>carte</k> dans le cadre',
        'details': {'reason': 'card_not_in_frame'},
      });
      expect(o.action, CaptureFrameAction.retry);
      expect(o.invalid, isFalse);
      expect(o.message, contains('carte'));
    });

    test('ko too_many_attempts stops the step', () {
      final o = classifyCaptureResponse({
        'status': 'ko',
        'message': 'Trop de tentatives',
        'details': {'reason': 'too_many_attempts'},
      });
      expect(o.action, CaptureFrameAction.stop);
      expect(o.errorCode, CaptureErrorCode.tooManyAttempts);
    });

    test('error stops', () {
      final o = classifyCaptureResponse({'status': 'error'});
      expect(o.action, CaptureFrameAction.stop);
      expect(o.errorCode, CaptureErrorCode.apiError);
    });

    for (final data in <Map<String, dynamic>?>[
      {'status': ''},
      {'status': '   '},
      {'status': 'weird'},
      {'status': 42},
      {'message': 'no status'},
      const {},
      null,
    ]) {
      test('empty or unknown status $data is read as pending', () {
        final o = classifyCaptureResponse(data);
        expect(o.action, CaptureFrameAction.retry);
        expect(o.status, 'pending');
        expect(o.invalid, isTrue);
      });
    }

    test('status is normalised', () {
      expect(classifyCaptureResponse({'status': ' OK '}).action,
          CaptureFrameAction.accept);
    });

    test('blank message is dropped', () {
      expect(classifyCaptureResponse({'status': 'ko', 'message': '  '}).message,
          isNull);
    });
  });

  group('CaptureLoopTracker', () {
    late DateTime now;
    CaptureLoopTracker tracker(CaptureLoopSettings settings) =>
        CaptureLoopTracker(settings, clock: () => now);

    setUp(() => now = DateTime(2026, 11, 16, 10));

    test('enforces the minimal interval between sends', () {
      final t = tracker(const CaptureLoopSettings(
          minFrameInterval: Duration(milliseconds: 400)));
      expect(t.canSendNow, isTrue);
      t.recordSend();
      expect(t.canSendNow, isFalse);
      now = now.add(const Duration(milliseconds: 150));
      expect(t.delayBeforeNextSend(), const Duration(milliseconds: 250));
      now = now.add(const Duration(milliseconds: 250));
      expect(t.canSendNow, isTrue);
    });

    test('stops after maxAttempts sends', () {
      final t = tracker(const CaptureLoopSettings(maxAttempts: 3));
      for (var i = 0; i < 3; i++) {
        expect(t.limitReached(), isNull);
        t.recordSend();
      }
      expect(t.limitReached(), CaptureErrorCode.maxAttempts);
    });

    test('stops after the timeout', () {
      final t = tracker(const CaptureLoopSettings(timeout: Duration(seconds: 20)))
        ..start();
      now = now.add(const Duration(seconds: 19));
      expect(t.limitReached(), isNull);
      now = now.add(const Duration(seconds: 1));
      expect(t.limitReached(), CaptureErrorCode.timeout);
    });

    test('default step timeout is 2 minutes', () {
      expect(const CaptureLoopSettings().timeout, const Duration(minutes: 2));
    });

    test('the step clock only runs once started (camera ready)', () {
      final t = tracker(const CaptureLoopSettings());
      now = now.add(const Duration(minutes: 10)); // permission, écran précédent
      expect(t.started, isFalse);
      expect(t.limitReached(), isNull);
      expect(t.remaining, const Duration(minutes: 2));
      t.start();
      now = now.add(const Duration(seconds: 30));
      expect(t.remaining, const Duration(seconds: 90));
    });

    test('start is idempotent: it never extends the step', () {
      final t = tracker(const CaptureLoopSettings())..start();
      now = now.add(const Duration(seconds: 100));
      t.start();
      expect(t.remaining, const Duration(seconds: 20));
      now = now.add(const Duration(seconds: 20));
      expect(t.limitReached(), CaptureErrorCode.timeout);
      expect(t.remaining, Duration.zero);
    });

    test('a send starts the clock if needed', () {
      final t = tracker(const CaptureLoopSettings(timeout: Duration(seconds: 1)));
      t.recordSend();
      now = now.add(const Duration(seconds: 1));
      expect(t.limitReached(), CaptureErrorCode.timeout);
    });

    test('each new step gets the full 2 minutes again', () {
      final t = tracker(const CaptureLoopSettings())..start();
      now = now.add(const Duration(seconds: 119));
      expect(t.remaining, const Duration(seconds: 1));
      t.reset(); // recto validé → verso
      now = now.add(const Duration(minutes: 1)); // confirmation : hors caméra
      t.start();
      expect(t.remaining, const Duration(minutes: 2));
    });

    test('reset starts a fresh step', () {
      final t = tracker(const CaptureLoopSettings(
          maxAttempts: 1, timeout: Duration(seconds: 5)));
      t.recordSend();
      now = now.add(const Duration(seconds: 10));
      expect(t.limitReached(), isNotNull);
      t.reset();
      expect(t.limitReached(), isNull);
      expect(t.attempts, 0);
    });

    test('an empty status never stops the loop (pending)', () {
      final t = tracker(const CaptureLoopSettings(maxConsecutiveErrors: 3));
      final empty = classifyCaptureResponse({'status': ''});
      for (var i = 0; i < 20; i++) {
        expect(t.recordOutcome(empty), isNull);
      }
      expect(t.consecutiveErrors, 0);
    });

    test('a valid response clears the error streak', () {
      final t = tracker(const CaptureLoopSettings(maxConsecutiveErrors: 2));
      t.recordOutcome(classifyCaptureResponse({'status': ''}));
      t.recordOutcome(classifyCaptureResponse({'status': 'ko', 'message': 'x'}));
      expect(t.consecutiveErrors, 0);
      expect(t.recordOutcome(classifyCaptureResponse({'status': ''})), isNull);
    });

    test('network errors stop after the same streak', () {
      final t = tracker(const CaptureLoopSettings(maxConsecutiveErrors: 2));
      expect(t.recordNetworkError(), isNull);
      expect(t.recordNetworkError(), CaptureErrorCode.networkError);
    });

    test('a terminal response stops immediately', () {
      final t = tracker(const CaptureLoopSettings());
      final o = classifyCaptureResponse(
          {'status': 'ko', 'details': {'reason': 'too_many_attempts'}});
      expect(t.recordOutcome(o), CaptureErrorCode.tooManyAttempts);
    });
  });
}
