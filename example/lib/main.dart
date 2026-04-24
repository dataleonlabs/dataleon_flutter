import 'package:flutter/material.dart';
import 'package:dataleon_flutter/dataleon_flutter.dart';

void main() {
  runApp(const DataleonExampleApp());
}

class DataleonExampleApp extends StatelessWidget {
  const DataleonExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dataleon SDK — Test Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1A73E8),
        useMaterial3: true,
      ),
      home: const ClientHomePage(),
    );
  }
}

/// Simulates a client app that integrates the Dataleon SDK.
/// Two buttons: full screen mode and modal (bottom sheet) mode.
class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  String _lastResult = 'No verification started yet';

  // This is what the client provides — their session ID and API key.
  static final _config = DataleonConfig(
    sessionId: 'YOUR_SESSION_ID',
    apiKey: 'YOUR_API_KEY',
  );

  void _handleResult(DataleonResult result) {
    setState(() {
      _lastResult = 'Status: ${result.status.value}'
          '${result.error != null ? '\nError: ${result.error}' : ''}';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('SDK result: ${result.status.value}'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (result.status == DataleonStatus.finished ||
        result.status == DataleonStatus.canceled) {
      Navigator.of(context).maybePop();
    }
  }

  /// Example 1: Full screen — the SDK takes over the entire screen.
  /// This is the simplest integration for the client.
  void _openFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DataleonFlowScreen(
          config: _config,
          title: 'Identity Verification',
          onResult: _handleResult,
        ),
      ),
    );
  }

  /// Example 2: Modal bottom sheet — the SDK opens inside a modal.
  /// The client app stays visible underneath.
  void _openModal() {
    DataleonBottomSheet.show(
      context: context,
      config: _config,
      onResult: _handleResult,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Client App'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.verified_user,
                          size: 48, color: theme.colorScheme.primary),
                      const SizedBox(height: 12),
                      Text(
                        'Dataleon SDK Test',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This app simulates a client integrating the Dataleon '
                        'verification SDK. Choose how to open the flow:',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Example 1: Full screen
              FilledButton.icon(
                onPressed: _openFullScreen,
                icon: const Icon(Icons.fullscreen),
                label: const Text('Open Full Screen'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              const SizedBox(height: 12),

              // Example 2: Modal
              OutlinedButton.icon(
                onPressed: _openModal,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open in Modal (Bottom Sheet)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              const Spacer(),

              // Result display
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Last result',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          )),
                      const SizedBox(height: 8),
                      Text(_lastResult, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
