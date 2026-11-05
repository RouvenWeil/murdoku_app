import 'package:flutter/material.dart';

import '../../domain/case_definition.dart';

class BoardViewportStub extends StatelessWidget {
  const BoardViewportStub({super.key, required this.caseData});

  final CaseDefinition caseData;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const margin = 16.0;
        final availableWidth = (constraints.maxWidth - margin * 2)
            .clamp(1.0, double.infinity).toDouble();
        final availableHeight = (constraints.maxHeight - margin * 2)
            .clamp(1.0, double.infinity).toDouble();
        final cellSide = [
          availableWidth / caseData.columns,
          availableHeight / caseData.rows,
        ].reduce((a, b) => a < b ? a : b);

        return Center(
          child: SizedBox(
            width: cellSide * caseData.columns,
            height: cellSide * caseData.rows,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CaseGridPreviewPainter(caseData),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    color: const Color(0xDD222330),
                    child: const Text(
                      'Board preview · gestures pending',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CaseGridPreviewPainter extends CustomPainter {
  const _CaseGridPreviewPainter(this.caseData);

  final CaseDefinition caseData;

  static const _rooms = <Color>[
    Color(0xFF777F9E),
    Color(0xFF839A91),
    Color(0xFF9F8699),
    Color(0xFFA39283),
    Color(0xFF7B91A3),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / caseData.columns;
    final cellHeight = size.height / caseData.rows;
    final fill = Paint()..style = PaintingStyle.fill;
    final border = Paint()
      ..color = const Color(0x99322F40)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    final wall = Paint()
      ..color = const Color(0xFF181824)
      ..strokeWidth = 2.6;
    final marker = Paint()..color = const Color(0xFF263242);

    // Static room geometry only with visual markers for catalog objects
    for (var row = 0; row < caseData.rows; row++) {
      for (var col = 0; col < caseData.columns; col++) {
        final roomId = caseData.roomGrid[row][col];
        final rect = Rect.fromLTWH(
          col * cellWidth,
          row * cellHeight,
          cellWidth,
          cellHeight,
        );
        fill.color = roomId == null
            ? const Color(0xFF292837)
            : _rooms[roomId.abs() % _rooms.length];
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, border);

        if (roomId == null) continue;
        if (caseData.objectGrid[row][col] != null) {
          canvas.drawCircle(
            rect.center,
            (cellWidth < cellHeight ? cellWidth : cellHeight) * 0.16,
            marker,
          );
        }

        if (col == 0 || caseData.roomGrid[row][col - 1] != roomId) {
          canvas.drawLine(rect.topLeft, rect.bottomLeft, wall);
        }
        if (row == 0 || caseData.roomGrid[row - 1][col] != roomId) {
          canvas.drawLine(rect.topLeft, rect.topRight, wall);
        }
        if (col == caseData.columns - 1 ||
            caseData.roomGrid[row][col + 1] != roomId) {
          canvas.drawLine(rect.topRight, rect.bottomRight, wall);
        }
        if (row == caseData.rows - 1 ||
            caseData.roomGrid[row + 1][col] != roomId) {
          canvas.drawLine(rect.bottomLeft, rect.bottomRight, wall);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CaseGridPreviewPainter oldDelegate) =>
      oldDelegate.caseData != caseData;
}
