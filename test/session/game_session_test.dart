import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/domain/board_state.dart';
import 'package:murdoku_app/domain/case_definition.dart';
import 'package:murdoku_app/domain/character_definition.dart';
import 'package:murdoku_app/domain/object_definition.dart';
import 'package:murdoku_app/domain/solution_evaluation.dart';
import 'package:murdoku_app/session/game_session.dart';

void main() {
  // Synthetic test case with two suspects and one victim.
  final solution = CaseSolution(
    rows: 6,
    columns: 6,
    characterPositions: {
      'A': (row: 1, column: 1),
      'B': (row: 3, column: 3),
      'V': (row: 4, column: 5),
    },
  );

  // Creates a board with A and V correctly placed.
  BoardState partialBoard() {
    return BoardState.empty(6, 6)
        .withCell((row: 1, column: 1), CellState(characterId: 'A'))
        .withCell((row: 4, column: 5), CellState(characterId: 'V'));
  }

  // Creates a complete board with B at a chosen position.
  BoardState completeBoard(CellPosition bPosition) {
    return partialBoard().withCell(bPosition, CellState(characterId: 'B'));
  }

  // B is in the wrong position, while A and V are correct.
  GameSession incorrectGame() {
    return GameSession(
      initialBoard: completeBoard((row: 3, column: 2)),
      solution: solution,
    );
  }

  // Small case fixture with blocked and absent cells
  CaseDefinition sceneCase() => CaseDefinition(
    id: 'test-scene',
    title: 'Test Scene',
    difficulty: 'test',
    rows: 3,
    columns: 3,
    roomGrid: [
      [0, 0, 0],
      [0, 0, 0],
      [null, 0, 0],
    ],
    roomNames: {0: 'Area'},
    objectGrid: [
      [null, null, 'shelf'],
      [null, 'chair', null],
      [null, null, null],
    ],
    objects: {
      'shelf': const ObjectDefinition(name: 'Shelf', isOccupiable: false),
      'chair': const ObjectDefinition(name: 'Chair', isOccupiable: true),
    },
    generalClues: [],
    characters: [
      const CharacterDefinition(
        id: 'A',
        name: 'A',
        clue: '',
        solution: (row: 0, column: 0),
      ),
      const CharacterDefinition(
        id: 'B',
        name: 'B',
        clue: '',
        solution: (row: 1, column: 1),
      ),
      const CharacterDefinition(
        id: 'V',
        name: 'V',
        clue: '',
        solution: (row: 2, column: 2),
      ),
    ],
    murderId: 'A',
  );

  group('WP-02 - Case-aware GameSession', () {
    test(
      'blocked objects and absent cells reject placement without history',
      () {
        final game = GameSession.fromCase(sceneCase());
        final before = game.board;

        expect(game.placeCharacter((row: 0, column: 2), 'A'), isFalse);
        expect(game.placeCharacter((row: 2, column: 0), 'A'), isFalse);
        expect(identical(game.board, before), isTrue);
        expect(game.canUndo, isFalse);
        expect(game.undoDepth, 0);
      },
    );

    test('unknown characters do not create invalid case placements', () {
      final game = GameSession.fromCase(sceneCase());
      final before = game.board;

      expect(game.placeCharacter((row: 0, column: 0), 'X'), isFalse);
      expect(identical(game.board, before), isTrue);
      expect(game.canUndo, isFalse);
    });

    test('valid placements remain atomic, undoable and submittable', () {
      final game = GameSession.fromCase(sceneCase());

      expect(game.placeCharacter((row: 0, column: 0), 'A'), isTrue);
      expect(game.undoDepth, 1);
      expect(game.board.cellAt((row: 0, column: 1)).crossed, isTrue);
      expect(game.undo(), isTrue);
      expect(game.board.cellAt((row: 0, column: 0)).isEmpty, isTrue);
      expect(game.board.cellAt((row: 0, column: 1)).isEmpty, isTrue);

      expect(game.placeCharacter((row: 0, column: 0), 'A'), isTrue);
      expect(game.placeCharacter((row: 1, column: 1), 'B'), isTrue);
      expect(game.placeCharacter((row: 2, column: 2), 'V'), isTrue);
      expect(game.canSubmit, isTrue);
      expect(game.submit().solved, isTrue);
    });

    test('case boundaries preserve the existing out-of-range contract', () {
      final game = GameSession.fromCase(sceneCase());
      expect(
        () => game.placeCharacter((row: 3, column: 0), 'A'),
        throwsRangeError,
      );
      expect(game.canUndo, isFalse);
    });
  });

  group('WP-01C - GameSession', () {
    test('New session starts active without feedback', () {
      final game = GameSession(
        initialBoard: BoardState.empty(6, 6),
        solution: solution,
      );

      expect(game.isSolved, isFalse);
      expect(game.canSubmit, isFalse);
      expect(game.canUndo, isFalse);
      expect(game.feedbackByCell, isEmpty);
    });

    test('Incomplete board cannot be submitted', () {
      final game = GameSession(
        initialBoard: partialBoard(),
        solution: solution,
      );

      final before = game.board;

      expect(game.canSubmit, isFalse);
      expect(game.submit, throwsStateError);

      expect(identical(game.board, before), isTrue);
      expect(game.isSolved, isFalse);
      expect(game.feedbackByCell, isEmpty);
    });

    test('Incorrect Submit keeps the game active', () {
      final game = incorrectGame();
      final before = game.board;

      expect(game.canSubmit, isTrue);

      final result = game.submit();

      expect(result.solved, isFalse);
      expect(game.isSolved, isFalse);
      expect(game.canSubmit, isTrue);
      expect(identical(game.board, before), isTrue);

      expect(
        game.feedbackByCell[(row: 1, column: 1)],
        PlacementVerdict.correct,
      );
      expect(
        game.feedbackByCell[(row: 3, column: 2)],
        PlacementVerdict.incorrect,
      );
      expect(
        game.feedbackByCell[(row: 4, column: 5)],
        PlacementVerdict.correct,
      );
    });

    test('Feedback map cannot be modified externally', () {
      final game = incorrectGame();
      game.submit();

      expect(
        () =>
            game.feedbackByCell[(row: 0, column: 0)] = PlacementVerdict.correct,
        throwsUnsupportedError,
      );
    });

    test('Unrelated note and cross edits preserve feedback', () {
      final game = incorrectGame();
      game.submit();

      expect(game.toggleNote((row: 0, column: 0), 'A'), isTrue);

      expect(game.toggleCross((row: 0, column: 0)), isTrue);

      expect(game.feedbackByCell.length, 3);
      expect(
        game.feedbackByCell[(row: 3, column: 2)],
        PlacementVerdict.incorrect,
      );

      // An occupied character cannot be crossed.
      expect(game.toggleCross((row: 1, column: 1)), isFalse);

      expect(game.feedbackByCell.length, 3);
    });

    test('Erasing a character invalidates only its feedback', () {
      final game = incorrectGame();
      game.submit();

      expect(game.eraseCell((row: 3, column: 2)), isTrue);

      expect(game.board.cellAt((row: 3, column: 2)).isEmpty, isTrue);

      expect(game.feedbackByCell.containsKey((row: 3, column: 2)), isFalse);

      expect(
        game.feedbackByCell[(row: 1, column: 1)],
        PlacementVerdict.correct,
      );
      expect(
        game.feedbackByCell[(row: 4, column: 5)],
        PlacementVerdict.correct,
      );

      expect(game.canSubmit, isFalse);
    });

    test('Undo restores character but not invalidated feedback', () {
      final game = incorrectGame();
      game.submit();

      game.eraseCell((row: 3, column: 2));

      expect(game.canUndo, isTrue);
      expect(game.undo(), isTrue);

      expect(game.board.cellAt((row: 3, column: 2)).characterId, 'B');

      // Old feedback must not reappear.
      expect(game.feedbackByCell.containsKey((row: 3, column: 2)), isFalse);

      // Unchanged characters retain their feedback.
      expect(game.feedbackByCell.length, 2);

      expect(game.canSubmit, isTrue);
    });

    test('Undo of placement also invalidates its feedback', () {
      final game = GameSession(
        initialBoard: partialBoard(),
        solution: solution,
      );

      expect(game.placeCharacter((row: 3, column: 2), 'B'), isTrue);

      game.submit();

      expect(
        game.feedbackByCell[(row: 3, column: 2)],
        PlacementVerdict.incorrect,
      );

      expect(game.undo(), isTrue);

      expect(game.board.cellAt((row: 3, column: 2)).isEmpty, isTrue);

      expect(game.feedbackByCell.containsKey((row: 3, column: 2)), isFalse);

      expect(game.feedbackByCell.length, 2);
      expect(game.canSubmit, isFalse);
    });

    test('Correcting the board and resubmitting solves it', () {
      final game = incorrectGame();

      expect(game.submit().solved, isFalse);

      game.eraseCell((row: 3, column: 2));

      expect(game.placeCharacter((row: 3, column: 3), 'B'), isTrue);

      final result = game.submit();

      expect(result.solved, isTrue);
      expect(game.isSolved, isTrue);
      expect(game.feedbackByCell.length, 3);
      expect(
        game.feedbackByCell.values,
        everyElement(PlacementVerdict.correct),
      );
    });

    test('Correct Submit permanently locks the current attempt', () {
      final game = GameSession(
        initialBoard: partialBoard(),
        solution: solution,
      );

      game.placeCharacter((row: 3, column: 3), 'B');

      expect(game.canUndo, isTrue);
      expect(game.canSubmit, isTrue);

      final result = game.submit();
      final solvedBoard = game.board;

      expect(result.solved, isTrue);
      expect(game.isSolved, isTrue);
      expect(game.canSubmit, isFalse);
      expect(game.canUndo, isFalse);

      expect(game.toggleCross((row: 0, column: 0)), isFalse);
      expect(game.toggleNote((row: 0, column: 0), 'A'), isFalse);
      expect(game.placeCharacter((row: 0, column: 0), 'A'), isFalse);
      expect(game.eraseCell((row: 3, column: 3)), isFalse);
      expect(game.undo(), isFalse);
      expect(game.clearAll(), isFalse);
      expect(game.submit, throwsStateError);

      expect(identical(game.board, solvedBoard), isTrue);
      expect(game.feedbackByCell.length, 3);
    });

    test('Clear all resets board, feedback and Undo history', () {
      final game = incorrectGame();
      game.submit();

      game.toggleNote((row: 0, column: 0), 'A');

      expect(game.canUndo, isTrue);
      expect(game.feedbackByCell, isNotEmpty);

      expect(game.clearAll(), isTrue);

      expect(game.board.cellAt((row: 1, column: 1)).isEmpty, isTrue);
      expect(game.board.cellAt((row: 3, column: 2)).isEmpty, isTrue);
      expect(game.board.cellAt((row: 4, column: 5)).isEmpty, isTrue);

      expect(game.feedbackByCell, isEmpty);
      expect(game.canUndo, isFalse);
      expect(game.undoDepth, 0);
      expect(game.isSolved, isFalse);
      expect(game.canSubmit, isFalse);
    });

    test('Invalid edit leaves board and feedback unchanged', () {
      final game = incorrectGame();
      game.submit();

      final beforeBoard = game.board;
      final beforeFeedback = game.feedbackByCell;

      expect(() => game.toggleCross((row: 6, column: 0)), throwsRangeError);

      expect(identical(game.board, beforeBoard), isTrue);
      expect(identical(game.feedbackByCell, beforeFeedback), isTrue);
    });

    test('A new session starts a fresh attempt', () {
      final first = GameSession(
        initialBoard: completeBoard((row: 3, column: 3)),
        solution: solution,
      );

      first.submit();
      expect(first.isSolved, isTrue);

      // Replaying is represented by a new GameSession.
      final replay = GameSession(
        initialBoard: BoardState.empty(6, 6),
        solution: solution,
      );

      expect(replay.isSolved, isFalse);
      expect(replay.feedbackByCell, isEmpty);
      expect(replay.canSubmit, isFalse);
      expect(replay.canUndo, isFalse);
    });

    test('Initial board dimensions must match the solution', () {
      expect(
        () => GameSession(
          initialBoard: BoardState.empty(9, 9),
          solution: solution,
        ),
        throwsArgumentError,
      );
    });

    test('A completed board is not solved until Submit', () {
      final game = GameSession(
        initialBoard: completeBoard((row: 3, column: 3)),
        solution: solution,
      );

      expect(game.canSubmit, isTrue);
      expect(game.isSolved, isFalse);
      expect(game.feedbackByCell, isEmpty);

      game.submit();

      expect(game.isSolved, isTrue);
    });
  });
}
