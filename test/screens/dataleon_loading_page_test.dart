import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dataleon_flutter/core/dataleon_config.dart';
import 'package:dataleon_flutter/flow/dataleon_flow_controller.dart';
import 'package:dataleon_flutter/screens/dataleon_loading_page.dart';
import 'package:dataleon_flutter/services/dataleon_api_service.dart';

void main() {
  late DataleonConfig config;

  setUp(() {
    config = DataleonConfig(sessionId: 'sid', token: 'jwt');
  });

  Future<void> teardownPage(WidgetTester tester) async {
    // Pump an empty tree so the page's State.dispose() cancels its timer.
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('Phase 1: shows only a spinner before the chart resolves',
      (tester) async {
    final controller = DataleonFlowController(config: config);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: DataleonLoadingPage(controller: controller)),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(controller.isChartResolved, isFalse);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await teardownPage(tester);
  });

  testWidgets('Phase 2: shows the determinate bar with branding once resolved',
      (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/config/chart')) {
        return http.Response(
          jsonEncode({
            'applicationName': 'Acme',
            'principalColor': '#112233',
            'logoURLApp': 'https://cdn.example.com/logo.png',
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'result': {'metadata': {}},
        }),
        200,
      );
    });

    final controller = DataleonFlowController(
      config: config,
      apiService: DataleonApiService(config: config, client: client),
    );
    addTearDown(controller.dispose);

    // Drives the chart → resolved state and the branding fields.
    await controller.fetchConfig();

    await tester.pumpWidget(
      MaterialApp(home: DataleonLoadingPage(controller: controller)),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(controller.isChartResolved, isTrue);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // The network logo cannot load in tests → app name text fallback is shown.
    expect(find.text('Acme'), findsOneWidget);

    // Message + percentage on a single line (default language is French).
    expect(find.textContaining('Presque prêt…'), findsOneWidget);
    expect(find.textContaining('%'), findsOneWidget);

    await teardownPage(tester);
  });
}
