import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/domain/board_actions.dart';
import 'package:murdoku_app/session/board_session.dart';
import 'package:murdoku_app/domain/board_state.dart';

void main() {
  group('BoardSession - Atomic Undo', () {
    // Undo restores notes overwritten by a cross.
    test('Restores notes after ToggleCross', () {
      final session = BoardSession(initialBoard: BoardState.empty(6, 6));
      final position = (row: 2, column: 3);

      session.toggleNote(position, 'suspectA');
      session.toggleNote(position, 'suspectB');
      session.toggleCross(position);

      expect(session.board.cellAt(position).crossed, isTrue);
      expect(session.undoDepth, 3);

      // Undo the cross, not the previous note actions.
      expect(session.undo(), isTrue);
      expect(session.board.cellAt(position).notes, {'suspectA', 'suspectB'});
      expect(session.board.cellAt(position).crossed, isFalse);
      expect(session.undoDepth, 2);
    });

    // One Undo reverses a character and all generated crosses.
    test('Character placement is one atomic Undo step', () {
      final target = (row: 2, column: 3);
      final manualCross = (row: 2, column: 0);
      final notedCell = (row: 2, column: 4);

      // Prepare markings that existed before placement.
      var initial = BoardState.empty(6, 6);
      initial = toggleCross(initial, manualCross);
      initial = toggleNote(initial, notedCell, 'suspectB');

      final session = BoardSession(initialBoard: initial);

      session.placeCharacter(target, 'suspectA');

      expect(session.undoDepth, 1);
      expect(session.board.cellAt(target).characterId, 'suspectA');
      expect(session.board.cellAt(notedCell).crossed, isTrue);
      expect(session.board.cellAt((row: 0, column: 3)).crossed, isTrue);

      // Restore the board before the entire placement.
      expect(session.undo(), isTrue);

      expect(session.board.cellAt(target).isEmpty, isTrue);
      expect(session.board.cellAt(manualCross).crossed, isTrue);
      expect(session.board.cellAt(notedCell).notes, {'suspectB'});
      expect(session.board.cellAt((row: 0, column: 3)).isEmpty, isTrue);
      expect(session.canUndo, isFalse);
    });

    // Erasing differs from undoing the original placement.
    test('Erase preserves crosses but Undo restores earlier boards', () {
      final session = BoardSession(initialBoard: BoardState.empty(6, 6));
      final target = (row: 2, column: 3);
      final crossedCell = (row: 2, column: 0);

      session.placeCharacter(target, 'suspectA');
      session.eraseCell(target);

      // Eraser removes the character but leaves generated crosses.
      expect(session.board.cellAt(target).isEmpty, isTrue);
      expect(session.board.cellAt(crossedCell).crossed, isTrue);
      expect(session.undoDepth, 2);

      // First Undo restores the erased character.
      session.undo();
      expect(session.board.cellAt(target).characterId, 'suspectA');
      expect(session.board.cellAt(crossedCell).crossed, isTrue);

      // Second Undo reverses the original placement.
      session.undo();
      expect(session.board.cellAt(target).isEmpty, isTrue);
      expect(session.board.cellAt(crossedCell).isEmpty, isTrue);
      expect(session.canUndo, isFalse);
    });

    // Rejected actions must not create Undo entries.
    test('Rejected actions do not affect history', () {
      final session = BoardSession(initialBoard: BoardState.empty(6, 6));
      final position = (row: 2, column: 3);

      expect(session.eraseCell(position), isFalse);
      expect(session.undoDepth, 0);

      session.toggleCross(position);
      final crossed = session.board;

      expect(session.toggleNote(position, 'suspectA'), isFalse);
      expect(session.placeCharacter(position, 'suspectA'), isFalse);

      expect(identical(session.board, crossed), isTrue);
      expect(session.undoDepth, 1);
    });

    // Invalid coordinates must leave board and history untouched.
    test('Invalid actions do not corrupt the session', () {
      final session = BoardSession(initialBoard: BoardState.empty(6, 6));
      final original = session.board;

      expect(
        () => session.placeCharacter((row: 6, column: 0), 'suspectA'),
        throwsRangeError,
      );

      expect(identical(session.board, original), isTrue);
      expect(session.undoDepth, 0);
    });

    // The oldest snapshots are discarded when history reaches its limit.
    test('Undo history respects its capacity', () {
      final session = BoardSession(
        initialBoard: BoardState.empty(6, 6),
        historyLimit: 2,
      );

      session.toggleNote((row: 0, column: 0), 'suspectA');
      session.toggleNote((row: 0, column: 1), 'suspectB');
      session.toggleNote((row: 0, column: 2), 'suspectC');

      expect(session.undoDepth, 2);

      session.undo();
      session.undo();

      // The earliest action is no longer undoable.
      expect(session.board.cellAt((row: 0, column: 0)).notes, {'suspectA'});
      expect(session.board.cellAt((row: 0, column: 1)).isEmpty, isTrue);
      expect(session.board.cellAt((row: 0, column: 2)).isEmpty, isTrue);
      expect(session.undo(), isFalse);
    });

    // Clear-all is not Undoable.
    test('ClearAll removes markings and history', () {
      final session = BoardSession(initialBoard: BoardState.empty(6, 6));

      session.placeCharacter((row: 2, column: 3), 'suspectA');
      session.clearAll();

      expect(session.board.cellAt((row: 2, column: 3)).isEmpty, isTrue);
      expect(session.board.cellAt((row: 2, column: 0)).isEmpty, isTrue);
      expect(session.board.rows, 6);
      expect(session.board.columns, 6);
      expect(session.undoDepth, 0);
      expect(session.undo(), isFalse);
    });

    // Reopening a board starts a new session without old Undo history.
    test('New session starts with empty history', () {
      final first = BoardSession(initialBoard: BoardState.empty(6, 6));

      first.toggleCross((row: 2, column: 3));

      // Simulate reopening the case with its saved board.
      final reopened = BoardSession(initialBoard: first.board);

      expect(reopened.board.cellAt((row: 2, column: 3)).crossed, isTrue);
      expect(reopened.canUndo, isFalse);
      expect(reopened.undoDepth, 0);
    });
  });
}
