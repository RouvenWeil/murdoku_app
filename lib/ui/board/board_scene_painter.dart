import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/board_state.dart';
import '../../domain/case_definition.dart';
import '../../domain/solution_evaluation.dart';

// Shared scene renderer for the navigable board and whole-board minimap
class BoardScenePainter extends CustomPainter {
  const BoardScenePainter({
    required this.caseData,
    required this.cellSize,
    this.originRow = 0,
    this.originColumn = 0,
    this.translation = Offset.zero,
    this.viewportOutline,
    this.boardState,
    this.feedbackByCell = const {},
    this.holdCell,
    this.holdProgress = 0,
    this.paintCrosses = true,
  });

  final CaseDefinition caseData;
  final double cellSize;
  final int originRow;
  final int originColumn;
  final Offset translation;
  final Rect? viewportOutline;
  final BoardState? boardState;
  final Map<CellPosition, PlacementVerdict> feedbackByCell;
  final CellPosition? holdCell;
  final double holdProgress;
  final bool paintCrosses;

  static const _rooms = <Color>[
    Color(0xFF777F9E),
    Color(0xFF839A91),
    Color(0xFF9F8699),
    Color(0xFFA39283),
    Color(0xFF7B91A3),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final fill = Paint()..style = PaintingStyle.fill;
    final border = Paint()
      ..color = const Color(0x99322F40)
      ..strokeWidth = (cellSize * 0.017).clamp(0.25, 0.8).toDouble()
      ..style = PaintingStyle.stroke;
    final wall = Paint()
      ..color = const Color(0xFF181824)
      ..strokeWidth = (cellSize * 0.054).clamp(0.45, 2.6).toDouble();
    final marker = Paint()..color = const Color(0xFF263242);

    for (var row = 0; row < caseData.rows; row++) {
      for (var column = 0; column < caseData.columns; column++) {
        final rect = Rect.fromLTWH(
          (column - originColumn) * cellSize + translation.dx,
          (row - originRow) * cellSize + translation.dy,
          cellSize,
          cellSize,
        );
        if (!rect.overlaps(Offset.zero & size)) {
          continue;
        }

        final roomId = caseData.roomGrid[row][column];
        fill.color = roomId == null
            ? const Color(0xFF292837)
            : _rooms[roomId.abs() % _rooms.length];
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, border);
        if (roomId == null) {
          continue;
        }

        if (caseData.objectGrid[row][column] != null) {
          canvas.drawCircle(rect.center, cellSize * 0.16, marker);
        }
        if (column == 0 || caseData.roomGrid[row][column - 1] != roomId) {
          canvas.drawLine(rect.topLeft, rect.bottomLeft, wall);
        }
        if (row == 0 || caseData.roomGrid[row - 1][column] != roomId) {
          canvas.drawLine(rect.topLeft, rect.topRight, wall);
        }
        if (column == caseData.columns - 1 ||
            caseData.roomGrid[row][column + 1] != roomId) {
          canvas.drawLine(rect.topRight, rect.bottomRight, wall);
        }
        if (row == caseData.rows - 1 ||
            caseData.roomGrid[row + 1][column] != roomId) {
          canvas.drawLine(rect.bottomLeft, rect.bottomRight, wall);
        }

        if (boardState != null &&
            caseData.canOccupy((row: row, column: column))) {
          _paintMarks(
            canvas,
            rect,
            boardState!.cellAt((row: row, column: column)),
          );
        }
        final verdict = feedbackByCell[(row: row, column: column)];
        if (verdict != null) {
          canvas.drawCircle(
            rect.center,
            math.max(1, (cellSize - 16) / 2),
            Paint()
              ..color = verdict == PlacementVerdict.correct
                  ? const Color(0xFF52DF8C)
                  : const Color(0xFFFF6D6D)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4,
          );
        }
      }
    }

    if (holdCell != null && holdProgress > 0) {
      final rect = Rect.fromLTWH(
        (holdCell!.column - originColumn) * cellSize + translation.dx,
        (holdCell!.row - originRow) * cellSize + translation.dy,
        cellSize,
        cellSize,
      );
      canvas.drawArc(
        Rect.fromCircle(center: rect.center, radius: cellSize * 0.64),
        -math.pi / 2,
        2 * math.pi * holdProgress,
        false,
        Paint()
          ..color = const Color(0xFFF8EBCC)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    }

    if (viewportOutline != null) {
      canvas.drawRect(
        viewportOutline!.deflate(1),
        Paint()
          ..color = const Color(0xFFFFF7DD)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    }
    canvas.restore();
  }

  void _paintMarks(Canvas canvas, Rect rect, CellState cell) {
    if (cell.crossed && paintCrosses) {
      _drawCrossShape(canvas, rect);
    }

    final character = cell.characterId;
    if (character != null) {
      // Keep placed initials inside the cell with 8dp breathing room
      _drawOutlinedText(
        canvas,
        character,
        rect.center,
        fontSize: math.max(1, cellSize - 16),
        maxWidth: math.max(1, cellSize - 16),
      );
    } else if (cell.notes.isNotEmpty && cellSize >= 24) {
      final notes = cell.notes.toList()..sort();
      final noteSize = (cellSize * 0.19).clamp(9.0, 15.0).toDouble();
      final step = noteSize + 2;
      final columns = math.max(1, ((cellSize - 16) / step).floor());
      for (var i = 0; i < notes.length; i++) {
        final x = rect.left + 8 + i % columns * step;
        final y = rect.top + 8 + i ~/ columns * step;
        if (y + noteSize > rect.bottom - 4) break;
        _drawOutlinedText(
          canvas,
          notes[i],
          Offset(x, y),
          fontSize: noteSize,
          maxWidth: step,
          topLeft: true,
        );
      }
    }
  }

  // Traces the supplied 32×32 Vector-Cross.svg shape for miniature previews.
  // The main board uses that SVG asset directly in BoardViewportStub.
  void _drawCrossShape(Canvas canvas, Rect rect) {
    final target = rect.deflate(
      math.min(8, math.min(rect.width, rect.height) * 0.2),
    );
    if (target.width <= 0 || target.height <= 0) return;
    final path = Path()
      ..moveTo(26.6667, 31.9991)
      ..lineTo(32, 26.6657)
      ..lineTo(21.3333, 15.9995)
      ..lineTo(32, 5.33236)
      ..lineTo(26.6667, 0.000325521)
      ..lineTo(16, 10.6661)
      ..lineTo(5.33333, 0)
      ..lineTo(0, 5.33236)
      ..lineTo(10.6667, 15.9982)
      ..lineTo(0, 26.6657)
      ..lineTo(5.33333, 32)
      ..lineTo(16, 21.3328)
      ..close();
    canvas.save();
    canvas.translate(target.left, target.top);
    canvas.scale(target.width / 32, target.height / 32);
    canvas.drawPath(path, Paint()..color = Colors.black);
    canvas.restore();
  }

  void _drawOutlinedText(
    Canvas canvas,
    String value,
    Offset anchor, {
    required double fontSize,
    required double maxWidth,
    bool topLeft = false,
  }) {
    for (final foreground in <Paint?>[
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.black,
      null,
    ]) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: fontSize,
            height: 1,
            fontWeight: FontWeight.w700,
            color: foreground == null ? const Color(0xFFF7EFDA) : null,
            foreground: foreground,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: maxWidth);
      final offset = topLeft
          ? anchor
          : anchor - Offset(painter.width / 2, painter.height / 2);
      painter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant BoardScenePainter old) =>
      old.caseData != caseData ||
      old.cellSize != cellSize ||
      old.originRow != originRow ||
      old.originColumn != originColumn ||
      old.translation != translation ||
      old.viewportOutline != viewportOutline ||
      old.boardState != boardState ||
      old.feedbackByCell != feedbackByCell ||
      old.holdCell != holdCell ||
      old.holdProgress != holdProgress ||
      old.paintCrosses != paintCrosses;
}
