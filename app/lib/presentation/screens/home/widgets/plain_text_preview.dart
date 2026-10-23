import 'package:flutter/material.dart';

import 'markdown_to_plain_text.dart';

class PlainTextPreview extends StatelessWidget {
  const PlainTextPreview({
    super.key,
    required this.markdown,
    this.maxLines = 3,
  });

  final String markdown;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Text(
    markdownToPlainText(markdown),
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(context).textTheme.bodyLarge,
  );
}
