import 'dart:math' as math;
import 'dart:ui';

import '../../domain/board_state.dart';

// The settled board origin is stored in logical row-first cell coordinates
typedef BoardOrigin = ({int row, int column});

class BoardViewportGeometry {
  BoardViewportGeometry({
    required this.rows,
    required this.columns,
    required this.visibleRows,
    required this.visibleColumns,
    required this.cellSize,
    BoardOrigin origin = const (row: 0, column: 0),
  }) : origin = (
         row: origin.row.clamp(0, math.max(0, rows - visibleRows)).toInt(),
         column: origin.column
             .clamp(0, math.max(0, columns - visibleColumns))
             .toInt(),
       ) {
    if (rows <= 0 ||
        columns <= 0 ||
        visibleRows <= 0 ||
        visibleColumns <= 0 ||
        visibleRows > rows ||
        visibleColumns > columns ||
        !cellSize.isFinite ||
        cellSize <= 0) {
      throw ArgumentError('Invalid board viewport geometry');
    }
  }

  final int rows;
  final int columns;
  final int visibleRows;
  final int visibleColumns;
  final double cellSize;
  final BoardOrigin origin;

  int get maxStartRow => rows - visibleRows;
  int get maxStartColumn => columns - visibleColumns;
  Size get regionSize =>
      Size(visibleColumns * cellSize, visibleRows * cellSize);

  BoardOrigin clampOrigin(BoardOrigin value) => (
    row: value.row.clamp(0, maxStartRow).toInt(),
    column: value.column.clamp(0, maxStartColumn).toInt(),
  );

  // Positive drag moves board artwork right/down, revealing earlier cells
  Offset constrainDrag(Offset shift) => Offset(
    shift.dx
        .clamp(
          (origin.column - maxStartColumn) * cellSize,
          origin.column * cellSize,
        )
        .toDouble(),
    shift.dy
        .clamp((origin.row - maxStartRow) * cellSize, origin.row * cellSize)
        .toDouble(),
  );

  BoardOrigin snappedAfterDrag(Offset shift) => clampOrigin((
    row: origin.row - (shift.dy / cellSize).round(),
    column: origin.column - (shift.dx / cellSize).round(),
  ));

  Offset translationTo(BoardOrigin target) => Offset(
    (origin.column - target.column) * cellSize,
    (origin.row - target.row) * cellSize,
  );

  CellPosition? cellAt(Offset localPoint, {Offset translation = Offset.zero}) {
    if (localPoint.dx < 0 ||
        localPoint.dy < 0 ||
        localPoint.dx >= regionSize.width ||
        localPoint.dy >= regionSize.height) {
      return null;
    }
    final col =
        origin.column + ((localPoint.dx - translation.dx) / cellSize).floor();
    final row =
        origin.row + ((localPoint.dy - translation.dy) / cellSize).floor();
    if (row < 0 || row >= rows || col < 0 || col >= columns) {
      return null;
    }
    return (row: row, column: col);
  }

  BoardOrigin centerOnMinimap(Offset localPoint, Size mapSize) {
    if (mapSize.width <= 0 || mapSize.height <= 0) return origin;
    final col =
        localPoint.dx.clamp(0.0, mapSize.width) / mapSize.width * columns;
    final row =
        localPoint.dy.clamp(0.0, mapSize.height) / mapSize.height * rows;
    return clampOrigin((
      row: (row - visibleRows / 2).round(),
      column: (col - visibleColumns / 2).round(),
    ));
  }

  Rect viewportOnMinimap(Size mapSize, {Offset drag = Offset.zero}) =>
      Rect.fromLTWH(
        (origin.column - drag.dx / cellSize) / columns * mapSize.width,
        (origin.row - drag.dy / cellSize) / rows * mapSize.height,
        visibleColumns / columns * mapSize.width,
        visibleRows / rows * mapSize.height,
      );
}

// Per-case viewport memory survives navigation within one running process
class BoardViewportStore {
  BoardViewportStore();

  static final BoardViewportStore instance = BoardViewportStore();

  final Map<String, BoardOrigin> _origins = {};

  BoardOrigin originFor(String caseId) =>
      _origins[caseId] ?? (row: 0, column: 0);

  void setOrigin(String caseId, BoardOrigin origin) {
    _origins[caseId] = origin;
  }
}
