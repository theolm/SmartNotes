/// Converts the small Markdown subset used in journal notes into readable text
/// for the compact timeline preview.
String markdownToPlainText(String markdown) {
  final lines = <String>[];
  var inCodeFence = false;

  for (var line in markdown.split('\n')) {
    if (RegExp(r'^\s*```').hasMatch(line)) {
      inCodeFence = !inCodeFence;
      continue;
    }
    if (inCodeFence) {
      lines.add(line.trim());
      continue;
    }
    if (RegExp(r'^\s*(?:[-*_]\s*){3,}$').hasMatch(line)) continue;

    line = line.replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s+'), '');
    line = line.replaceFirst(RegExp(r'^\s*>\s?'), '');
    line = line.replaceFirst(
      RegExp(r'^\s*(?:[-+*]|\d+[.)])\s+'),
      '• ',
    );
    line = line.replaceAllMapped(
      RegExp(r'!?\[([^\]]*)\]\([^)]*\)'),
      (match) => match.group(1)!,
    );
    line = line.replaceAll(RegExp(r'<[^>]+>'), '');
    line = line.replaceAll(RegExp(r'(?<!\\)[*_~]'), '');
    line = line.replaceAllMapped(
      RegExp(r'\\([\\`*_{}\[\]()#+.!\-])'),
      (match) => match.group(1)!,
    );
    line = line.replaceAll('`', '');
    lines.add(line.trimRight());
  }

  return lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}
