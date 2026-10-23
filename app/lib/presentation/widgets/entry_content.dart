import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:smartnotes/core/theme/theme.dart';

/// Shared typography for saved entries and unsaved AI proposals.
class EntryContent extends StatelessWidget {
  const EntryContent({super.key, required this.text, required this.markdown});

  final String text;
  final bool markdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!markdown) {
      return SelectableText(text, style: theme.textTheme.bodyLarge);
    }
    final style = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyLarge,
      h1: theme.textTheme.titleLarge,
      h2: theme.textTheme.titleMedium,
      h3: theme.textTheme.titleSmall,
      listBullet: theme.textTheme.bodyLarge,
      blockSpacing: AppSpacing.md,
      code: theme.textTheme.bodySmall?.copyWith(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      ),
    );
    if (text.length > 8192) {
      return _DeferredMarkdown(text: text, style: style);
    }
    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: style,
    );
  }
}

/// Parse the complete document (including cross-block references) off the UI
/// isolate. The state retains its AST across rebuilds, not across journal visits.
class _DeferredMarkdown extends StatefulWidget {
  const _DeferredMarkdown({required this.text, required this.style});
  final String text;
  final MarkdownStyleSheet style;
  @override
  State<_DeferredMarkdown> createState() => _DeferredMarkdownState();
}

class _DeferredMarkdownState extends State<_DeferredMarkdown>
    implements MarkdownBuilderDelegate {
  late Future<List<md.Node>> _parsed;
  List<md.Node>? _nodes;
  List<Widget>? _children;
  final _recognizers = <GestureRecognizer>[];

  void _parse() {
    final source = widget.text;
    _parsed = Isolate.run(
      () => md.Document(
        extensionSet: md.ExtensionSet.gitHubFlavored,
        encodeHtml: false,
      ).parseLines(const LineSplitter().convert(source)),
    );
    _nodes = null;
    _children = null;
  }

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(_DeferredMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _parse();
    if (oldWidget.style != widget.style) _children = null;
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  GestureRecognizer createLink(String text, String? href, String title) {
    final recognizer = TapGestureRecognizer();
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  TextSpan formatText(MarkdownStyleSheet styleSheet, String code) => TextSpan(
    style: styleSheet.code,
    text: code.replaceFirst(RegExp(r'\n$'), ''),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<List<md.Node>>(
    future: _parsed,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LinearProgressIndicator();
      }
      if (snapshot.hasError) {
        return SelectableText(widget.text, style: widget.style.p);
      }
      if (_children == null || !identical(_nodes, snapshot.data)) {
        for (final recognizer in _recognizers) {
          recognizer.dispose();
        }
        _recognizers.clear();
        _nodes = snapshot.data!;
        _children = MarkdownBuilder(
          delegate: this,
          selectable: true,
          styleSheet: widget.style,
          imageDirectory: null,
          imageBuilder: null,
          checkboxBuilder: null,
          bulletBuilder: null,
          builders: const {},
          paddingBuilders: const {},
          listItemCrossAxisAlignment:
              MarkdownListItemCrossAxisAlignment.baseline,
          fitContent: true,
          contextMenuBuilder: (context, state) =>
              AdaptiveTextSelectionToolbar.editableText(
                editableTextState: state,
              ),
        ).build(_nodes!);
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _children!,
      );
    },
  );
}
