import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:smartnotes/core/theme/theme.dart';

class MarkdownPreview extends StatelessWidget {
  const MarkdownPreview({super.key, required this.markdown, this.maxLines = 2});

  final String markdown;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium!;
    final textScaler = MediaQuery.textScalerOf(context);
    final lineHeight = (style.fontSize ?? 14.0) * (style.height ?? 1.0);
    final maxHeight = textScaler.scale(lineHeight * maxLines);

    return SizedBox(
      height: maxHeight,
      child: ClipRect(
        child: MarkdownBody(
          data: markdown,
          selectable: false,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: style,
            h1: style,
            h2: style,
            h3: style,
            h4: style,
            h5: style,
            h6: style,
            listBullet: style,
            code: style.copyWith(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
            blockSpacing: 0,
            listIndent: AppSpacing.md,
            pPadding: EdgeInsets.zero,
            h1Padding: EdgeInsets.zero,
            h2Padding: EdgeInsets.zero,
            h3Padding: EdgeInsets.zero,
            h4Padding: EdgeInsets.zero,
            h5Padding: EdgeInsets.zero,
            h6Padding: EdgeInsets.zero,
            listBulletPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}
