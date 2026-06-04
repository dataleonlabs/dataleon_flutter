import 'package:flutter/material.dart';

import '../flow/dataleon_flow_controller.dart';

class DataleonThemeWrapper extends StatelessWidget {
  const DataleonThemeWrapper({
    super.key,
    required this.controller,
    required this.child,
  });

  final DataleonFlowController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fontFamily = controller.customFontFamily;

    if (fontFamily == null || fontFamily.isEmpty) {
      return child;
    }

    final baseTheme = Theme.of(context);

    return Theme(
      data: baseTheme.copyWith(
        textTheme: baseTheme.textTheme.apply(
          fontFamily: fontFamily,
        ),
        primaryTextTheme: baseTheme.primaryTextTheme.apply(
          fontFamily: fontFamily,
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontFamily: fontFamily,
        ),
        child: child,
      ),
    );
  }
}