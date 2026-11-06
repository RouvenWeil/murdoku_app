import 'package:flutter/material.dart';

// Outlined note/placement glyph; the parent board defines cell geometry
class BoardMarkText extends StatelessWidget {
  const BoardMarkText({super.key, required this.value, required this.style});

  final String value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final outline = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
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
