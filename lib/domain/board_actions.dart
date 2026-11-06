import 'board_state.dart';

// Pure board transformations independent of session history
BoardState toggleCross(BoardState board, CellPosition position) {
  final oldCell = board.cellAt(position);

  // Committed characters cannot be overwritten with crosses
  if (oldCell.characterId != null) {
    return board;
  }

  // Crossing a cell also clears its existing notes
  final newCrossed = !oldCell.crossed;

  final newCell = CellState(
    crossed: newCrossed,
    notes: newCrossed ? const {} : oldCell.notes,
    characterId: oldCell.characterId,
  );

  return board.withCell(position, newCell);
}

BoardState toggleNote(
  BoardState board,
  CellPosition position,
  String characterId,
) {
  final oldCell = board.cellAt(position);

  if (oldCell.crossed || oldCell.characterId != null) {
    return board;
  }

  // Defensive note copy preserves the original board state
  final newNotes = Set<String>.of(oldCell.notes);

  if (newNotes.contains(characterId)) {
    newNotes.remove(characterId);
  } else {
    newNotes.add(characterId);
  }

  final newCell = CellState(notes: newNotes);

  return board.withCell(position, newCell);
}

// Drag painting is additive, unlike the short-tap toggle.
// A cell already containing this note produces no new Undo entry.
BoardState addNote(
  BoardState board,
  CellPosition position,
  String characterId,
) {
  if (characterId.isEmpty) {
    throw ArgumentError.value(characterId, 'characterId');
  }
  final cell = board.cellAt(position);
  if (cell.crossed ||
      cell.characterId != null ||
      cell.notes.contains(characterId)) {
    return board;
  }
  return board.withCell(
    position,
    CellState(notes: {...cell.notes, characterId}),
  );
}

// Generated crosses retain existing characters and crosses
BoardState _ensureCross(BoardState board, CellPosition position) {
  final cell = board.cellAt(position);

  // No-op results preserve board identity for session history checks
  if (cell.crossed || cell.characterId != null) {
    return board;
  }

  return board.withCell(position, CellState(crossed: true));
}

BoardState placeCharacter(
  BoardState board,
  CellPosition position,
  String characterId, {
  bool Function(CellPosition)? canMark,
}) {
  final target = board.cellAt(position);

  if (characterId.isEmpty) {
    throw ArgumentError.value(characterId, 'characterId');
  }

  if (target.crossed || target.characterId != null) {
    return board;
  }

  for (var row = 0; row < board.rows; row++) {
    for (var column = 0; column < board.columns; column++) {
      final cell = board.cellAt((row: row, column: column));

      if (cell.characterId == characterId) {
        return board;
      }
    }
  }

  // One immutable result contains the placement and all row and column crosses
  var updated = board.withCell(position, CellState(characterId: characterId));

  for (var column = 0; column < board.columns; column++) {
    if (column == position.column) continue;

    final crossPosition = (row: position.row, column: column);
    if (canMark == null || canMark(crossPosition)) {
      updated = _ensureCross(updated, crossPosition);
    }
  }

  for (var row = 0; row < board.rows; row++) {
    if (row == position.row) continue;

    final crossPosition = (row: row, column: position.column);
    if (canMark == null || canMark(crossPosition)) {
      updated = _ensureCross(updated, crossPosition);
    }
  }

  return updated;
}

// Erasing one cell does not reverse crosses from earlier placements
BoardState eraseCell(BoardState board, CellPosition position) {
  final cell = board.cellAt(position);

  if (cell.isEmpty) {
    return board;
  }

  return board.withCell(position, CellState());
}
