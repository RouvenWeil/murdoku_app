import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/domain/board_actions.dart';
import 'package:murdoku_app/domain/board_state.dart';

void main() {
  group('ToggleCross', () {
    // Checks that toggling an empty cell adds an X.
    test('Adds a cross to an empty cell', () {
      final board = BoardState.empty(6, 6);
      final position = (row: 2, column: 3);

      final updated = toggleCross(board, position);

      expect(updated.cellAt(position).crossed, isTrue);
      expect(board.cellAt(position).crossed, isFalse);
    });

    // Checks that toggling twice removes the X.
    test('Toggling twice removes the cross', () {
      final board = BoardState.empty(6, 6);
      final position = (row: 2, column: 3);

      final once = toggleCross(board, position);
      final twice = toggleCross(once, position);

      expect(once.cellAt(position).crossed, isTrue);
      expect(twice.cellAt(position).crossed, isFalse);
    });

    // Checks that a committed character protects its cell.
    test('Cannot cross a cell containing a character', () {
      final position = (row: 2, column: 3);

      final board = BoardState.empty(
        6,
        6,
      ).withCell(position, CellState(characterId: 'suspectA'));

      final updated = toggleCross(board, position);

      expect(identical(board, updated), isTrue);
      expect(updated.cellAt(position).crossed, isFalse);
      expect(updated.cellAt(position).characterId, 'suspectA');
    });

    // Checks that a cross overwrites the notes in the cell.
    test('Adding a cross overwrites notes', () {
      // Create a board with two notes in one cell.
      final position = (row: 2, column: 3);
      final original = BoardState.empty(
        6,
        6,
      ).withCell(position, CellState(notes: {'suspectA', 'suspectB'}));

      // Adding a cross should remove the notes.
      final crossed = toggleCross(original, position);

      // Removing the cross should not recreate them.
      final uncrossed = toggleCross(crossed, position);

      // The original board must still contain both notes.
      expect(original.cellAt(position).notes, hasLength(2));
      expect(original.cellAt(position).crossed, isFalse);

      // The crossed cell must contain an X but no notes.
      expect(crossed.cellAt(position).crossed, isTrue);
      expect(crossed.cellAt(position).notes, isEmpty);

      // Removing the X must leave the cell empty.
      expect(uncrossed.cellAt(position).isEmpty, isTrue);
    });

    // Checks that invalid coordinates can't get targeted by the toggleCross action
    test('Rejects coordinates outside the board', () {
      final board = BoardState.empty(6, 6);

      // Negative row is invalid.
      expect(() => toggleCross(board, (row: -1, column: 2)), throwsRangeError);

      // Row 6 is outside a zero-indexed 6x6 board.
      expect(() => toggleCross(board, (row: 6, column: 2)), throwsRangeError);

      // Column 6 is also outside the board.
      expect(() => toggleCross(board, (row: 2, column: 6)), throwsRangeError);
    });
  });
}
