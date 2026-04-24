import 'dart:async';

import 'package:flutter/material.dart';

import '../flow/dataleon_flow_controller.dart';

/// Full-page loader with animated progress bar (like the React FullPageLoader).
/// The display progress smoothly catches up to the real progress value.
class DataleonLoadingPage extends StatefulWidget {
  final DataleonFlowController controller;

  const DataleonLoadingPage({
    super.key,
    required this.controller,
  });

  @override
  State<DataleonLoadingPage> createState() => _DataleonLoadingPageState();
}

class _DataleonLoadingPageState extends State<DataleonLoadingPage> {
  double _displayProgress = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startAnimation() {
    // ~60fps smooth animation, easing toward actual progress
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      final target = widget.controller.progress;
      setState(() {
        if (target >= 100 && _displayProgress >= 99.5) {
          _displayProgress = 100;
          return;
        }
        final diff = target - _displayProgress;
        _displayProgress += diff * 0.1;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Main centered content
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress bar
                  SizedBox(
                    width: 160,
                    height: 8,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _displayProgress / 100,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Percentage text
                  Text(
                    '${_displayProgress.round()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom disclaimer
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text.rich(
              TextSpan(
                text: 'Cette opération est effectuée via la plateforme certifiée et sécurisée ',
                children: [
                  TextSpan(
                    text: 'Dataleon',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
