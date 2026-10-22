import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/domain/board_state.dart';

void main() {
  // Groups related tests under one name.
  group('BoardState', () {
    // TEST 1: New boards should contain empty cells.
    test('New board starts empty', () {
      final board = BoardState.empty(6, 6);
      final cell = board.cellAt((row: 2, column: 3));

      expect(cell.crossed, isFalse);
      expect(cell.notes, isEmpty);
      expect(cell.characterId, isNull);
    });

    // TEST 2: Placing an X should create a new board.
    test('Changing a cell preserves the original board', () {
      final original = BoardState.empty(6, 6);
      final position = (row: 2, column: 3);

      final modified = original.withCell(position, CellState(crossed: true));

      expect(original.cellAt(position).crossed, isFalse);
      expect(modified.cellAt(position).crossed, isTrue);
    });

    // TEST 3: Two equal coordinates must identify the same cell.
    test('Coordinates identify cells consistently', () {
      final original = BoardState.empty(6, 6);

      final modified = original.withCell((
        row: 1,
        column: 4,
      ), CellState(crossed: true));

      expect(modified.cellAt((row: 1, column: 4)).crossed, isTrue);
    });

    // TEST 4: Coordinates outside the board must be rejected.
    test('Invalid coordinates are rejected', () {
      final board = BoardState.empty(6, 6);

      expect(() => board.cellAt((row: -1, column: 0)), throwsRangeError);

      expect(() => board.cellAt((row: 6, column: 0)), throwsRangeError);
    });

    // TEST 5: Notes must not be changeable from the outside.
    test('Cell notes cannot be modified externally', () {
      final originalNotes = <String>{'suspectA'};
      final cell = CellState(notes: originalNotes);

      // Changing the input set must not change the cell.
      originalNotes.add('suspectB');

      expect(cell.notes, contains('suspectA'));
      expect(cell.notes, isNot(contains('suspectB')));

      // Directly changing the cell's notes must fail.
      expect(() => cell.notes.add('suspectC'), throwsUnsupportedError);
    });

    // TEST 6: Removing a marking should not alter old states.
    test('Clearing a cell preserves previous versions', () {
      final empty = BoardState.empty(6, 6);
      final position = (row: 0, column: 0);

      final marked = empty.withCell(position, CellState(crossed: true));

      final cleared = marked.withCell(position, CellState());

      expect(empty.cellAt(position).crossed, isFalse);
      expect(marked.cellAt(position).crossed, isTrue);
      expect(cleared.cellAt(position).isEmpty, isTrue);
    });
  });
}
