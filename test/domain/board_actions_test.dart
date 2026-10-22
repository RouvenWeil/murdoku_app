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

  group('PlaceCharacter', () {
    // Checks placement and automatic row/column crosses.
    test('Places a character and generates crosses', () {
      final board = BoardState.empty(6, 6);
      final position = (row: 2, column: 3);

      final updated = placeCharacter(board, position, 'suspectA');

      expect(updated.cellAt(position).characterId, 'suspectA');

      // Other cells in the same row or column are crossed.
      expect(updated.cellAt((row: 2, column: 0)).crossed, isTrue);
      expect(updated.cellAt((row: 5, column: 3)).crossed, isTrue);

      // Unrelated cells remain empty.
      expect(updated.cellAt((row: 0, column: 0)).isEmpty, isTrue);

      // The original board remains unchanged.
      expect(board.cellAt(position).isEmpty, isTrue);
    });

    // Checks that character placement overwrites notes.
    test('Placement overwrites target notes', () {
      final position = (row: 2, column: 3);
      final board = toggleNote(BoardState.empty(6, 6), position, 'suspectB');

      final updated = placeCharacter(board, position, 'suspectA');

      expect(updated.cellAt(position).characterId, 'suspectA');
      expect(updated.cellAt(position).notes, isEmpty);
      expect(board.cellAt(position).notes, {'suspectB'});
    });

    // Checks that characters cannot be placed on crosses.
    test('Rejects placement on a cross', () {
      final position = (row: 2, column: 3);
      final crossed = toggleCross(BoardState.empty(6, 6), position);

      final updated = placeCharacter(crossed, position, 'suspectA');

      expect(identical(updated, crossed), isTrue);
    });

    // Checks that a character cannot be placed twice.
    test('Rejects duplicate character placement', () {
      final position = (row: 2, column: 3);
      final board = placeCharacter(
        BoardState.empty(6, 6),
        position,
        'suspectA',
      );

      final updated = placeCharacter(board, (row: 0, column: 0), 'suspectA');

      expect(identical(updated, board), isTrue);
    });

    // Checks that two characters can share a row after clearing an X.
    test('Preserves existing characters in the same row', () {
      final firstPosition = (row: 2, column: 1);
      final secondPosition = (row: 2, column: 4);

      final first = placeCharacter(
        BoardState.empty(6, 6),
        firstPosition,
        'suspectA',
      );

      // Manually remove the generated X blocking the second cell.
      final cleared = toggleCross(first, secondPosition);

      final second = placeCharacter(cleared, secondPosition, 'suspectB');

      expect(second.cellAt(firstPosition).characterId, 'suspectA');
      expect(second.cellAt(secondPosition).characterId, 'suspectB');
    });

    // Checks that invalid positions are rejected.
    test('Rejects invalid coordinates', () {
      final board = BoardState.empty(6, 6);

      expect(
        () => placeCharacter(board, (row: -1, column: 0), 'suspectA'),
        throwsRangeError,
      );

      expect(
        () => placeCharacter(board, (row: 6, column: 0), 'suspectA'),
        throwsRangeError,
      );
    });
  });

  group('PlaceCharacter interactions', () {
    // Checks that placement overwrites notes only where required.
    test('Character replaces target, row and column notes', () {
      final original = BoardState.empty(6, 6);
      final target = (row: 2, column: 3);

      // Add notes to the target, its row, its column and elsewhere.
      var board = toggleNote(original, target, 'suspectB');
      board = toggleNote(board, (row: 2, column: 0), 'suspectC');
      board = toggleNote(board, (row: 0, column: 3), 'suspectD');
      board = toggleNote(board, (row: 0, column: 0), 'suspectE');

      // Place a character on the noted target.
      final placed = placeCharacter(board, target, 'suspectA');

      // The target becomes a character without notes.
      expect(placed.cellAt(target).characterId, 'suspectA');
      expect(placed.cellAt(target).notes, isEmpty);

      // Notes in the same row and column become crosses.
      expect(placed.cellAt((row: 2, column: 0)).crossed, isTrue);
      expect(placed.cellAt((row: 2, column: 0)).notes, isEmpty);
      expect(placed.cellAt((row: 0, column: 3)).crossed, isTrue);
      expect(placed.cellAt((row: 0, column: 3)).notes, isEmpty);

      // Unrelated notes must remain unchanged.
      expect(placed.cellAt((row: 0, column: 0)).notes, {'suspectE'});

      // The previous board retains its markings.
      expect(board.cellAt(target).notes, {'suspectB'});
      expect(original.cellAt(target).isEmpty, isTrue);
    });

    // Checks that automatic crosses never toggle existing crosses off.
    test('Character placement preserves existing crosses', () {
      final original = BoardState.empty(6, 6);
      final existingCross = (row: 2, column: 4);

      // Add a manual cross before placing the character.
      final crossed = toggleCross(original, existingCross);
      final placed = placeCharacter(crossed, (row: 2, column: 2), 'suspectA');

      // The existing cross must still be present.
      expect(placed.cellAt(existingCross).crossed, isTrue);

      // Other eligible cells must also become crossed.
      expect(placed.cellAt((row: 2, column: 0)).crossed, isTrue);
      expect(placed.cellAt((row: 0, column: 2)).crossed, isTrue);
    });

    // Checks that crosses and notes cannot overwrite characters.
    test('Existing character blocks ToggleCross and ToggleNote', () {
      final position = (row: 2, column: 3);
      final placed = placeCharacter(
        BoardState.empty(6, 6),
        position,
        'suspectA',
      );

      // Attempt both marking actions on the occupied cell.
      final crossed = toggleCross(placed, position);
      final noted = toggleNote(placed, position, 'suspectB');

      // Neither action may change the board.
      expect(identical(crossed, placed), isTrue);
      expect(identical(noted, placed), isTrue);
      expect(placed.cellAt(position).characterId, 'suspectA');
    });

    // Checks how notes interact with automatically generated crosses.
    test('Automatic cross blocks notes until manually cleared', () {
      final position = (row: 2, column: 4);

      // Placing a character generates a cross at the test position.
      final placed = placeCharacter(BoardState.empty(6, 6), (
        row: 2,
        column: 2,
      ), 'suspectA');

      // Attempt to add a note on the automatic cross.
      final blocked = toggleNote(placed, position, 'suspectB');
      expect(identical(blocked, placed), isTrue);

      // Manually remove the cross and add a note.
      final cleared = toggleCross(blocked, position);
      final noted = toggleNote(cleared, position, 'suspectB');

      expect(noted.cellAt(position).notes, {'suspectB'});

      // Adding a cross again must overwrite the note.
      final recrossed = toggleCross(noted, position);
      expect(recrossed.cellAt(position).crossed, isTrue);
      expect(recrossed.cellAt(position).notes, isEmpty);
    });

    // Checks that a rejected placement causes no other changes.
    test('Placement on a cross does not modify the board', () {
      final target = (row: 2, column: 3);
      final original = BoardState.empty(6, 6);

      // Add a cross to the target and a note in its row.
      final crossed = toggleCross(original, target);
      final noted = toggleNote(crossed, (row: 2, column: 0), 'suspectB');

      // Attempt to place a character on the crossed target.
      final result = placeCharacter(noted, target, 'suspectA');

      // The rejected action must have no side effects.
      expect(identical(result, noted), isTrue);
      expect(result.cellAt(target).crossed, isTrue);
      expect(result.cellAt((row: 2, column: 0)).notes, {'suspectB'});
      expect(result.cellAt((row: 0, column: 3)).isEmpty, isTrue);
    });

    // Checks that characters can share a column after clearing a cross.
    test('Two characters can occupy the same column', () {
      final firstPosition = (row: 1, column: 3);
      final secondPosition = (row: 4, column: 3);

      // Place the first character.
      final first = placeCharacter(
        BoardState.empty(6, 6),
        firstPosition,
        'suspectA',
      );

      // Manually remove the automatic cross blocking the second.
      final cleared = toggleCross(first, secondPosition);

      // Place another character in the same column.
      final second = placeCharacter(cleared, secondPosition, 'suspectB');

      // Both characters must remain on the board.
      expect(second.cellAt(firstPosition).characterId, 'suspectA');
      expect(second.cellAt(secondPosition).characterId, 'suspectB');

      // The second placement must generate its own row crosses.
      expect(second.cellAt((row: 4, column: 0)).crossed, isTrue);

      // The original first placement must remain unchanged.
      expect(first.cellAt(secondPosition).crossed, isTrue);
    });
  });
}
