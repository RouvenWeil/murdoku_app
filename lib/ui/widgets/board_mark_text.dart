import 'package:flutter/material.dart';

import '../design/murdoku_tokens.dart';

// Outlined note/placement glyph; the parent board defines cell geometry
class BoardMarkText extends StatelessWidget {
  const BoardMarkText({super.key, required this.value, required this.style});

  final String value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final outline = Paint()
      ..color = MurdokuTokens.boardMarkOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = MurdokuTokens.paintStrokeWidth;
    return Semantics(
      label: value,
      child: ExcludeSemantics(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: style.fontFamily,
                fontSize: style.fontSize,
                fontWeight: style.fontWeight,
                height: style.height,
                foreground: outline,
              ),
            ),
            Text(value, style: style),
          ],
        ),
      ),
    );
  }
}
