import 'package:flutter/material.dart';

class DataleonStepScaffold extends StatelessWidget {
  final String title;
  final String? description;
  final Widget child;
  final Widget? leading;
  final List<Widget>? actions;
  final EdgeInsetsGeometry padding;

  const DataleonStepScaffold({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.leading,
    this.actions,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(height: 16),
            ],
            Text(title, style: theme.textTheme.headlineMedium),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(description!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 24),
            Expanded(child: child),
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(children: actions!),
            ],
          ],
        ),
      ),
    );
  }
}
