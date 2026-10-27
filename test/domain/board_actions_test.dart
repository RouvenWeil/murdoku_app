import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/domain/board_actions.dart';
import 'package:murdoku_app/domain/board_state.dart';

void main() {
  // Cross and note actions preserve the original board
  group('ToggleCross', () {
    test('Adds a cross to an empty cell', () {
      final board = BoardState.empty(6, 6);
      final position = (row: 2, column: 3);

      final updated = toggleCross(board, position);

      expect(updated.cellAt(position).crossed, isTrue);
      expect(board.cellAt(position).crossed, isFalse);
    });

    test('Toggling twice removes the cross', () {
      final board = BoardState.empty(6, 6);
      final position = (row: 2, column: 3);

      final once = toggleCross(board, position);
      final twice = toggleCross(once, position);

      expect(once.cellAt(position).crossed, isTrue);
      expect(twice.cellAt(position).crossed, isFalse);
    });

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

    test('Adding a cross overwrites notes', () {
      final position = (row: 2, column: 3);
      final original = BoardState.empty(
        6,
        6,
      ).withCell(position, CellState(notes: {'suspectA', 'suspectB'}));

      final crossed = toggleCross(original, position);

      final uncrossed = toggleCross(crossed, position);

      expect(original.cellAt(position).notes, hasLength(2));
      expect(original.cellAt(position).crossed, isFalse);

      expect(crossed.cellAt(position).crossed, isTrue);
      expect(crossed.cellAt(position).notes, isEmpty);

      expect(uncrossed.cellAt(position).isEmpty, isTrue);
    });

    test('Rejects coordinates outside the board', () {
      final board = BoardState.empty(6, 6);

      expect(() => toggleCross(board, (row: -1, column: 2)), throwsRangeError);

      expect(() => toggleCross(board, (row: 6, column: 2)), throwsRangeError);

      expect(() => toggleCross(board, (row: 2, column: 6)), throwsRangeError);
    });
  });

  group('ToggleNote', () {
    test('Toggles a note', () {
      final board = BoardState.empty(6, 6);
      final position = (row: 2, column: 3);

      final added = toggleNote(board, position, 'suspectA');
      final removed = toggleNote(added, position, 'suspectA');

      expect(added.cellAt(position).notes, {'suspectA'});
      expect(removed.cellAt(position).notes, isEmpty);
      expect(board.cellAt(position).notes, isEmpty);
    });

    test('Combines notes without overwriting them', () {
      final board = BoardState.empty(6, 6);
      final position = (row: 2, column: 3);

      final first = toggleNote(board, position, 'suspectA');
      final second = toggleNote(first, position, 'suspectB');
      final third = toggleNote(second, position, 'suspectA');

      expect(second.cellAt(position).notes, {'suspectA', 'suspectB'});

      expect(third.cellAt(position).notes, {'suspectB'});
    });

    test('Rejects notes on occupied cells', () {
      final position = (row: 2, column: 3);
      final board = BoardState.empty(
        6,
        6,
      ).withCell(position, CellState(characterId: 'suspectA'));

      final updated = toggleNote(board, position, 'suspectB');

      expect(identical(updated, board), isTrue);
    });

    test('Rejects notes on crossed cells', () {
      final board = BoardState.empty(6, 6);
      final position = (row: 2, column: 3);

      final crossed = toggleCross(board, position);
      final updated = toggleNote(crossed, position, 'suspectA');

      expect(identical(updated, crossed), isTrue);
      expect(updated.cellAt(position).notes, isEmpty);
    });

    test('Rejects invalid coordinates', () {
      final board = BoardState.empty(6, 6);

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
    test('Cross overwrites multiple notes', () {
      final position = (row: 2, column: 3);
      final original = BoardState.empty(6, 6);

      final withA = toggleNote(original, position, 'suspectA');
      final withAB = toggleNote(withA, position, 'suspectB');

      final crossed = toggleCross(withAB, position);

      expect(withAB.cellAt(position).notes, {'suspectA', 'suspectB'});
      expect(crossed.cellAt(position).crossed, isTrue);
      expect(crossed.cellAt(position).notes, isEmpty);
    });

    test('Cross blocks notes until removed', () {
      final position = (row: 2, column: 3);
      final original = BoardState.empty(6, 6);

      final crossed = toggleCross(original, position);
      final blocked = toggleNote(crossed, position, 'suspectA');

      expect(identical(blocked, crossed), isTrue);

      final cleared = toggleCross(blocked, position);
      final noted = toggleNote(cleared, position, 'suspectA');

      expect(noted.cellAt(position).notes, {'suspectA'});
      expect(noted.cellAt(position).crossed, isFalse);
    });

    test('Removing a cross does not restore overwritten notes', () {
      final position = (row: 2, column: 3);
      final original = BoardState.empty(6, 6);

      final noted = toggleNote(original, position, 'suspectA');
      final crossed = toggleCross(noted, position);
      final cleared = toggleCross(crossed, position);

      expect(noted.cellAt(position).notes, {'suspectA'});
      expect(crossed.cellAt(position).notes, isEmpty);
      expect(cleared.cellAt(position).isEmpty, isTrue);
    });

    test('Actions on different cells remain independent', () {
      final original = BoardState.empty(6, 6);
      final notePosition = (row: 1, column: 1);
      final crossPosition = (row: 4, column: 4);

      final noted = toggleNote(original, notePosition, 'suspectA');
      final crossed = toggleCross(noted, crossPosition);

      expect(crossed.cellAt(notePosition).notes, {'suspectA'});
      expect(crossed.cellAt(crossPosition).crossed, isTrue);

      expect(noted.cellAt(crossPosition).isEmpty, isTrue);
      expect(original.cellAt(notePosition).isEmpty, isTrue);
    });
  });

  group('PlaceCharacter', () {
    test('Places a character and generates crosses', () {
      final board = BoardState.empty(6, 6);
      final position = (row: 2, column: 3);

      final updated = placeCharacter(board, position, 'suspectA');

      expect(updated.cellAt(position).characterId, 'suspectA');

      expect(updated.cellAt((row: 2, column: 0)).crossed, isTrue);
      expect(updated.cellAt((row: 5, column: 3)).crossed, isTrue);

      expect(updated.cellAt((row: 0, column: 0)).isEmpty, isTrue);

      expect(board.cellAt(position).isEmpty, isTrue);
    });

    test('Placement overwrites target notes', () {
      final position = (row: 2, column: 3);
      final board = toggleNote(BoardState.empty(6, 6), position, 'suspectB');

      final updated = placeCharacter(board, position, 'suspectA');

      expect(updated.cellAt(position).characterId, 'suspectA');
      expect(updated.cellAt(position).notes, isEmpty);
      expect(board.cellAt(position).notes, {'suspectB'});
    });

    test('Rejects placement on a cross', () {
      final position = (row: 2, column: 3);
      final crossed = toggleCross(BoardState.empty(6, 6), position);

      final updated = placeCharacter(crossed, position, 'suspectA');

      expect(identical(updated, crossed), isTrue);
    });

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

    test('Preserves existing characters in the same row', () {
      final firstPosition = (row: 2, column: 1);
      final secondPosition = (row: 2, column: 4);

      final first = placeCharacter(
        BoardState.empty(6, 6),
        firstPosition,
        'suspectA',
      );

      final cleared = toggleCross(first, secondPosition);

      final second = placeCharacter(cleared, secondPosition, 'suspectB');

      expect(second.cellAt(firstPosition).characterId, 'suspectA');
      expect(second.cellAt(secondPosition).characterId, 'suspectB');
    });

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

  // Character placement changes the target and eligible row and column cells atomically
  group('PlaceCharacter interactions', () {
    test('Character replaces target, row and column notes', () {
      final original = BoardState.empty(6, 6);
      final target = (row: 2, column: 3);

      var board = toggleNote(original, target, 'suspectB');
      board = toggleNote(board, (row: 2, column: 0), 'suspectC');
      board = toggleNote(board, (row: 0, column: 3), 'suspectD');
      board = toggleNote(board, (row: 0, column: 0), 'suspectE');

      final placed = placeCharacter(board, target, 'suspectA');

      expect(placed.cellAt(target).characterId, 'suspectA');
      expect(placed.cellAt(target).notes, isEmpty);

      expect(placed.cellAt((row: 2, column: 0)).crossed, isTrue);
      expect(placed.cellAt((row: 2, column: 0)).notes, isEmpty);
      expect(placed.cellAt((row: 0, column: 3)).crossed, isTrue);
      expect(placed.cellAt((row: 0, column: 3)).notes, isEmpty);

      expect(placed.cellAt((row: 0, column: 0)).notes, {'suspectE'});

      expect(board.cellAt(target).notes, {'suspectB'});
      expect(original.cellAt(target).isEmpty, isTrue);
    });

    test('Character placement preserves existing crosses', () {
      final original = BoardState.empty(6, 6);
      final existingCross = (row: 2, column: 4);

      final crossed = toggleCross(original, existingCross);
      final placed = placeCharacter(crossed, (row: 2, column: 2), 'suspectA');

      expect(placed.cellAt(existingCross).crossed, isTrue);

      expect(placed.cellAt((row: 2, column: 0)).crossed, isTrue);
      expect(placed.cellAt((row: 0, column: 2)).crossed, isTrue);
    });

    test('Existing character blocks ToggleCross and ToggleNote', () {
      final position = (row: 2, column: 3);
      final placed = placeCharacter(
        BoardState.empty(6, 6),
        position,
        'suspectA',
      );

      final crossed = toggleCross(placed, position);
      final noted = toggleNote(placed, position, 'suspectB');

      expect(identical(crossed, placed), isTrue);
      expect(identical(noted, placed), isTrue);
      expect(placed.cellAt(position).characterId, 'suspectA');
    });

    test('Automatic cross blocks notes until manually cleared', () {
      final position = (row: 2, column: 4);

      final placed = placeCharacter(BoardState.empty(6, 6), (
        row: 2,
        column: 2,
      ), 'suspectA');

      final blocked = toggleNote(placed, position, 'suspectB');
      expect(identical(blocked, placed), isTrue);

      final cleared = toggleCross(blocked, position);
      final noted = toggleNote(cleared, position, 'suspectB');

      expect(noted.cellAt(position).notes, {'suspectB'});

      final recrossed = toggleCross(noted, position);
      expect(recrossed.cellAt(position).crossed, isTrue);
      expect(recrossed.cellAt(position).notes, isEmpty);
    });

    test('Placement on a cross does not modify the board', () {
      final target = (row: 2, column: 3);
      final original = BoardState.empty(6, 6);

      final crossed = toggleCross(original, target);
      final noted = toggleNote(crossed, (row: 2, column: 0), 'suspectB');

      final result = placeCharacter(noted, target, 'suspectA');

      expect(identical(result, noted), isTrue);
      expect(result.cellAt(target).crossed, isTrue);
      expect(result.cellAt((row: 2, column: 0)).notes, {'suspectB'});
      expect(result.cellAt((row: 0, column: 3)).isEmpty, isTrue);
    });

    test('Two characters can occupy the same column', () {
      final firstPosition = (row: 1, column: 3);
      final secondPosition = (row: 4, column: 3);

      final first = placeCharacter(
        BoardState.empty(6, 6),
        firstPosition,
        'suspectA',
      );

      final cleared = toggleCross(first, secondPosition);

      final second = placeCharacter(cleared, secondPosition, 'suspectB');

      expect(second.cellAt(firstPosition).characterId, 'suspectA');
      expect(second.cellAt(secondPosition).characterId, 'suspectB');

      expect(second.cellAt((row: 4, column: 0)).crossed, isTrue);

      expect(first.cellAt(secondPosition).crossed, isTrue);
    });
  });

  // Erasure affects the selected cell without undoing generated crosses
  group('EraseCell', () {
    test('Erases a cross', () {
      final position = (row: 2, column: 3);
      final crossed = toggleCross(BoardState.empty(6, 6), position);

      final erased = eraseCell(crossed, position);

      expect(erased.cellAt(position).isEmpty, isTrue);
      expect(crossed.cellAt(position).crossed, isTrue);
    });

    test('Erases multiple notes', () {
      final position = (row: 2, column: 3);
      var board = BoardState.empty(6, 6);

      board = toggleNote(board, position, 'suspectA');
      board = toggleNote(board, position, 'suspectB');

      final erased = eraseCell(board, position);

      expect(erased.cellAt(position).isEmpty, isTrue);
      expect(board.cellAt(position).notes, {'suspectA', 'suspectB'});
    });

    test('Erasing a character preserves its generated crosses', () {
      final position = (row: 2, column: 3);

      final placed = placeCharacter(
        BoardState.empty(6, 6),
        position,
        'suspectA',
      );

      final erased = eraseCell(placed, position);

      expect(erased.cellAt(position).isEmpty, isTrue);

      expect(erased.cellAt((row: 2, column: 0)).crossed, isTrue);
      expect(erased.cellAt((row: 0, column: 3)).crossed, isTrue);

      expect(placed.cellAt(position).characterId, 'suspectA');
    });

    test('Erasing an empty cell changes nothing', () {
      final board = BoardState.empty(6, 6);

      final erased = eraseCell(board, (row: 2, column: 3));

      expect(identical(erased, board), isTrue);
    });

    test('Rejects invalid coordinates', () {
      final board = BoardState.empty(6, 6);

      expect(() => eraseCell(board, (row: -1, column: 0)), throwsRangeError);

      expect(() => eraseCell(board, (row: 6, column: 0)), throwsRangeError);
    });
  });
}
