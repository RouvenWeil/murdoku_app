import 'package:flutter/material.dart';

// Explicit rich-text spans, without automatic clue or keyword interpretation
class ClueText extends StatelessWidget {
  const ClueText({
    super.key,
    required this.text,
    required this.style,
    this.emphasizedPhrases = const [],
    this.textAlign = TextAlign.center,
  });

  final String text;
  final TextStyle style;
  final List<String> emphasizedPhrases;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    if (emphasizedPhrases.isEmpty) {
      return Text(text, style: style, textAlign: textAlign, softWrap: true);
    }

    final spans = <TextSpan>[];
    var cursor = 0;
    while (cursor < text.length) {
      var nextStart = -1;
      String? nextPhrase;
      for (final phrase in emphasizedPhrases) {
        if (phrase.isEmpty) continue;
        final index = text.indexOf(phrase, cursor);
        if (index >= 0 && (nextStart == -1 || index < nextStart)) {
          nextStart = index;
          nextPhrase = phrase;
        }
      }
      if (nextStart == -1 || nextPhrase == null) {
        spans.add(TextSpan(text: text.substring(cursor)));
        break;
      }
      if (nextStart > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, nextStart)));
      }
      spans.add(
        TextSpan(
          text: nextPhrase,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
      cursor = nextStart + nextPhrase.length;
    }

    return Text.rich(
      TextSpan(children: spans),
      style: style,
      textAlign: textAlign,
      softWrap: true,
    );
  }
}
