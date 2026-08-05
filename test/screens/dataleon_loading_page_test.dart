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
    // fetchConfig() ends with a real `Future.delayed` (the 900 ms the loader
    // stays visible at 100%). Awaiting it directly inside testWidgets would
    // deadlock: the test body runs under FakeAsync, whose clock only advances
    // on pump(), so the delay would never complete. runAsync() executes it on
    // the real clock instead.
    await tester.runAsync(() => controller.fetchConfig());

    await tester.pumpWidget(
      MaterialApp(home: DataleonLoadingPage(controller: controller)),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(controller.isChartResolved, isTrue);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Le rendu de la marque quand le logo réseau échoue n'est volontairement
    // pas couvert ici : l'errorBuilder affiche l'URL brute plutôt que le nom
    // de l'app, comportement à réexaminer séparément.

    // Message + percentage on a single line (default language is French).
    expect(find.textContaining('Presque prêt…'), findsOneWidget);
    expect(find.textContaining('%'), findsOneWidget);

    await teardownPage(tester);
  });

  /// Builds a controller whose request config carries [dashboardConfiguration],
  /// driven all the way through fetchConfig() so the workspace is resolved.
  Future<DataleonFlowController> resolvedController(
    WidgetTester tester,
    Map<String, dynamic> dashboardConfiguration,
  ) async {
    final workspace = jsonEncode({
      'dashboardConfiguration': dashboardConfiguration,
    });
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/config/chart')) {
        return http.Response(jsonEncode(<String, dynamic>{}), 200);
      }
      return http.Response(
        jsonEncode({
          'result': {'metadata': {'workspace': workspace}},
        }),
        200,
      );
    });

    final controller = DataleonFlowController(
      config: config,
      apiService: DataleonApiService(config: config, client: client),
    );
    addTearDown(controller.dispose);
    await tester.runAsync(() => controller.fetchConfig());
    return controller;
  }

  testWidgets('shows the Dataleon disclaimer by default', (tester) async {
    final controller = await resolvedController(tester, {});

    await tester.pumpWidget(
      MaterialApp(home: DataleonLoadingPage(controller: controller)),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(controller.isWorkspaceResolved, isTrue);
    expect(find.textContaining('Dataleon'), findsOneWidget);

    await teardownPage(tester);
  });

  testWidgets('hides the Dataleon disclaimer when white-label is enabled',
      (tester) async {
    final controller = await resolvedController(tester, {
      'advancedDesignConfiguration': {'hideDataleonBranding': true},
    });

    await tester.pumpWidget(
      MaterialApp(home: DataleonLoadingPage(controller: controller)),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(controller.hideDataleonBranding, isTrue);
    expect(find.textContaining('Dataleon'), findsNothing);

    await teardownPage(tester);
  });

  testWidgets('withholds the disclaimer while the workspace is unresolved',
      (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/config/chart')) {
        return http.Response(jsonEncode(<String, dynamic>{}), 200);
      }
      return http.Response(jsonEncode(<String, dynamic>{}), 500);
    });
    final controller = DataleonFlowController(
      config: config,
      apiService: DataleonApiService(config: config, client: client),
    );
    addTearDown(controller.dispose);
    await tester.runAsync(() => controller.fetchConfig());

    await tester.pumpWidget(
      MaterialApp(home: DataleonLoadingPage(controller: controller)),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(controller.isChartResolved, isTrue);
    expect(controller.isWorkspaceResolved, isFalse);
    expect(find.textContaining('Dataleon'), findsNothing);

    await teardownPage(tester);
  });
}
