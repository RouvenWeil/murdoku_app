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
