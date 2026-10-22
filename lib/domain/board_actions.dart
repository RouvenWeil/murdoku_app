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
