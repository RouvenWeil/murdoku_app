import 'board_state.dart';

// Returns a new board with the X at this position toggled.
BoardState toggleCross(BoardState board, CellPosition position) {
  // Read the cell and reject invalid coordinates.
  final oldCell = board.cellAt(position);

  // Prevent crossing a cell containing a character.
  if (oldCell.characterId != null) {
    return board;
  }

  // Determine whether the new cell should be crossed.
  final newCrossed = !oldCell.crossed;

  // Create the updated cell; adding an X clears its notes.
  final newCell = CellState(
    crossed: newCrossed,
    notes: newCrossed ? const {} : oldCell.notes,
    characterId: oldCell.characterId,
  );

  // Return the new board without modifying the original.
  return board.withCell(position, newCell);
}

// Adds or removes one character note in a cell.
BoardState toggleNote(
  BoardState board,
  CellPosition position,
  String characterId,
) {
  // Read the cell and validate its coordinates.
  final oldCell = board.cellAt(position);

  // Notes cannot be added to crossed or occupied cells.
  if (oldCell.crossed || oldCell.characterId != null) {
    return board;
  }

  // Copy existing notes so the original stays unchanged.
  final newNotes = Set<String>.of(oldCell.notes);

  // Remove the note if it already exists.
  if (newNotes.contains(characterId)) {
    newNotes.remove(characterId);
  } else {
    // Otherwise, add the note alongside existing notes.
    newNotes.add(characterId);
  }

  // Create a new cell containing the updated notes.
  final newCell = CellState(notes: newNotes);

  // Return a new board containing the modified cell.
  return board.withCell(position, newCell);
}

// Adds a cross without removing an existing one.
BoardState _ensureCross(BoardState board, CellPosition position) {
  // Read the cell and validate its coordinates.
  final cell = board.cellAt(position);

  // Preserve existing crosses and characters.
  if (cell.crossed || cell.characterId != null) {
    return board;
  }

  // Add a cross, overwriting existing notes.
  return board.withCell(position, CellState(crossed: true));
}

// Places one character and crosses eligible row/column cells.
BoardState placeCharacter(
  BoardState board,
  CellPosition position,
  String characterId,
) {
  // Read the target and validate its coordinates.
  final target = board.cellAt(position);

  // Reject an empty character ID.
  if (characterId.isEmpty) {
    throw ArgumentError.value(characterId, 'characterId');
  }

  // Characters cannot be placed on crosses or other characters.
  if (target.crossed || target.characterId != null) {
    return board;
  }

  // Check whether this character is already placed anywhere.
  for (var row = 0; row < board.rows; row++) {
    for (var column = 0; column < board.columns; column++) {
      final cell = board.cellAt((row: row, column: column));

      // Reject duplicate character placements.
      if (cell.characterId == characterId) {
        return board;
      }
    }
  }

  // Place the character, replacing any notes in its cell.
  var updated = board.withCell(position, CellState(characterId: characterId));

  // Add crosses to eligible cells in the same row.
  for (var column = 0; column < board.columns; column++) {
    if (column == position.column) continue;

    updated = _ensureCross(updated, (row: position.row, column: column));
  }

  // Add crosses to eligible cells in the same column.
  for (var row = 0; row < board.rows; row++) {
    if (row == position.row) continue;

    updated = _ensureCross(updated, (row: row, column: position.column));
  }

  // Return the entire result as one immutable board.
  return updated;
}
