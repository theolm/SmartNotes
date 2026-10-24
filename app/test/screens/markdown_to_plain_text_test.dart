import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/presentation/screens/home/widgets/markdown_to_plain_text.dart';

void main() {
  test('removes Markdown syntax while preserving readable content', () {
    expect(
      markdownToPlainText(
        '# **Important**\n\n- [Read the _note_](https://example.com)\n- `offline`',
      ),
      'Important\n\n• Read the note\n• offline',
    );
  });

  test('removes code fences and thematic breaks', () {
    expect(
      markdownToPlainText(
        'Before\n\n---\n\n```markdown\n# hidden\n```\n\nAfter',
      ),
      'Before\n\n# hidden\n\nAfter',
    );
  });
}
