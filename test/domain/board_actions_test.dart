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

  group('ToggleNote', () {
    // Checks that a note can be added and removed.
    test('Toggles a note', () {
      final board = BoardState.empty(6, 6);
      final position = (row: 2, column: 3);

      final added = toggleNote(board, position, 'suspectA');
      final removed = toggleNote(added, position, 'suspectA');

      expect(added.cellAt(position).notes, {'suspectA'});
      expect(removed.cellAt(position).notes, isEmpty);
      expect(board.cellAt(position).notes, isEmpty);
    });

    // Checks that multiple notes can coexist.
    test('Combines notes without overwriting them', () {
      final board = BoardState.empty(6, 6);
      final position = (row: 2, column: 3);

      final first = toggleNote(board, position, 'suspectA');
      final second = toggleNote(first, position, 'suspectB');
      final third = toggleNote(second, position, 'suspectA');

      expect(second.cellAt(position).notes, {'suspectA', 'suspectB'});

      // Removing A must leave B untouched.
      expect(third.cellAt(position).notes, {'suspectB'});
    });

    // Checks that notes cannot be added over characters.
    test('Rejects notes on occupied cells', () {
      final position = (row: 2, column: 3);
      final board = BoardState.empty(
        6,
        6,
      ).withCell(position, CellState(characterId: 'suspectA'));

      final updated = toggleNote(board, position, 'suspectB');

      expect(identical(updated, board), isTrue);
    });

    // Checks that notes cannot be added over crosses.
    test('Rejects notes on crossed cells', () {
      final board = BoardState.empty(6, 6);
      final position = (row: 2, column: 3);

      final crossed = toggleCross(board, position);
      final updated = toggleNote(crossed, position, 'suspectA');

      expect(identical(updated, crossed), isTrue);
      expect(updated.cellAt(position).notes, isEmpty);
    });

    // Checks that invalid coordinates can't get targeted by the toggleNotes action
    test('Rejects invalid coordinates', () {
      final board = BoardState.empty(6, 6);

      // Coordinates outside the board must be rejected.
      expect(
        () => toggleNote(board, (row: -1, column: 2), 'suspectA'),
        throwsRangeError,
      );

      expect(
        () => toggleNote(board, (row: 2, column: 6), 'suspectA'),
        throwsRangeError,
      );
    });
  });

  group('Action interactions', () {
    // Checks that crossing a noted cell removes all its notes.
    test('Cross overwrites multiple notes', () {
      final position = (row: 2, column: 3);
      final original = BoardState.empty(6, 6);

      // Add two different notes to the same cell.
      final withA = toggleNote(original, position, 'suspectA');
      final withAB = toggleNote(withA, position, 'suspectB');

      // Replace the notes with a cross.
      final crossed = toggleCross(withAB, position);

      expect(withAB.cellAt(position).notes, {'suspectA', 'suspectB'});
      expect(crossed.cellAt(position).crossed, isTrue);
      expect(crossed.cellAt(position).notes, isEmpty);
    });

    // Checks that adding a note to a cross does nothing.
    test('Cross blocks notes until removed', () {
      final position = (row: 2, column: 3);
      final original = BoardState.empty(6, 6);

      // Add a cross and attempt to place a note.
      final crossed = toggleCross(original, position);
      final blocked = toggleNote(crossed, position, 'suspectA');

      expect(identical(blocked, crossed), isTrue);

      // Remove the cross and try again.
      final cleared = toggleCross(blocked, position);
      final noted = toggleNote(cleared, position, 'suspectA');

      expect(noted.cellAt(position).notes, {'suspectA'});
      expect(noted.cellAt(position).crossed, isFalse);
    });

    // Checks that removing a cross does not restore old notes.
    test('Removing a cross does not restore overwritten notes', () {
      final position = (row: 2, column: 3);
      final original = BoardState.empty(6, 6);

      // Add a note, replace it with a cross, then remove the cross.
      final noted = toggleNote(original, position, 'suspectA');
      final crossed = toggleCross(noted, position);
      final cleared = toggleCross(crossed, position);

      // Only the original noted state retains the note.
      expect(noted.cellAt(position).notes, {'suspectA'});
      expect(crossed.cellAt(position).notes, isEmpty);
      expect(cleared.cellAt(position).isEmpty, isTrue);
    });

    // Checks that actions only change their targeted cells.
    test('Actions on different cells remain independent', () {
      final original = BoardState.empty(6, 6);
      final notePosition = (row: 1, column: 1);
      final crossPosition = (row: 4, column: 4);

      // Add a note in one cell and a cross in another.
      final noted = toggleNote(original, notePosition, 'suspectA');
      final crossed = toggleCross(noted, crossPosition);

      // Both markings must still exist.
      expect(crossed.cellAt(notePosition).notes, {'suspectA'});
      expect(crossed.cellAt(crossPosition).crossed, isTrue);

      // The previous board must remain unchanged.
      expect(noted.cellAt(crossPosition).isEmpty, isTrue);
      expect(original.cellAt(notePosition).isEmpty, isTrue);
    });
  });
}
