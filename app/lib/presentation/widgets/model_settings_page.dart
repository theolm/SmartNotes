import 'package:flutter/material.dart';
import 'package:smartnotes/core/theme/theme.dart';

/// Common chrome, reading width, system insets and padding for all model pages.
class ModelSettingsPage extends StatelessWidget {
  const ModelSettingsPage({
    super.key,
    required this.title,
    required this.children,
    this.canPop = true,
  });
  final String title;
  final List<Widget> children;
  final bool canPop;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: canPop,
    child: Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: children,
            ),
          ),
        ),
      ),
    ),
  );
}
