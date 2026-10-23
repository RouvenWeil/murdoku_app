import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/domain/board_state.dart';
import 'package:murdoku_app/domain/solution_evaluation.dart';

void main() {
  final solution = CaseSolution(
    rows: 6,
    columns: 6,
    characterPositions: {
      'A': (row: 1, column: 1),
      'B': (row: 3, column: 3),
      'V': (row: 4, column: 5),
    },
  );

  // Builds a fully committed board without relying on UI actions.
  BoardState makeBoard({
    required CellPosition a,
    required CellPosition b,
    required CellPosition v,
  }) {
    return BoardState.empty(6, 6)
        .withCell(a, CellState(characterId: 'A'))
        .withCell(b, CellState(characterId: 'B'))
        .withCell(v, CellState(characterId: 'V'));
  }

  group('WP-01C - Solution evaluation', () {
    test('Empty board is not eligible for Submit', () {
      final board = BoardState.empty(6, 6);

      expect(canSubmit(board, solution), isFalse);
      expect(() => evaluateSubmission(board, solution), throwsStateError);
    });

    test('Missing victim prevents submission', () {
      final board = BoardState.empty(6, 6)
          .withCell((row: 1, column: 1), CellState(characterId: 'A'))
          .withCell((row: 3, column: 3), CellState(characterId: 'B'));

      expect(canSubmit(board, solution), isFalse);
    });

    test('Complete correct placement solves the case', () {
      final board = makeBoard(
        a: (row: 1, column: 1),
        b: (row: 3, column: 3),
        v: (row: 4, column: 5),
      );

      expect(canSubmit(board, solution), isTrue);

      final result = evaluateSubmission(board, solution);

      expect(result.solved, isTrue);
      expect(result.feedbackByCell.length, 3);
      expect(
        result.feedbackByCell.values,
        everyElement(PlacementVerdict.correct),
      );
    });

    test('Incorrect positions produce cell-specific feedback', () {
      final board = makeBoard(
        a: (row: 3, column: 3),
        b: (row: 1, column: 1),
        v: (row: 4, column: 5),
      );

      final result = evaluateSubmission(board, solution);

      expect(result.solved, isFalse);
      expect(
        result.feedbackByCell[(row: 3, column: 3)],
        PlacementVerdict.incorrect,
      );
      expect(
        result.feedbackByCell[(row: 1, column: 1)],
        PlacementVerdict.incorrect,
      );
      expect(
        result.feedbackByCell[(row: 4, column: 5)],
        PlacementVerdict.correct,
      );
    });

    test('Notes and crosses do not affect correctness', () {
      final board =
          makeBoard(
            a: (row: 1, column: 1),
            b: (row: 3, column: 3),
            v: (row: 4, column: 5),
          ).withCell((row: 0, column: 0), CellState(crossed: true)).withCell((
            row: 2,
            column: 2,
          ), CellState(notes: {'A', 'B'}));

      expect(evaluateSubmission(board, solution).solved, isTrue);
    });

    test('Duplicate or unknown characters are not eligible', () {
      final duplicate = makeBoard(
        a: (row: 1, column: 1),
        b: (row: 3, column: 3),
        v: (row: 4, column: 5),
      ).withCell((row: 0, column: 0), CellState(characterId: 'A'));

      final unknown = BoardState.empty(6, 6)
          .withCell((row: 1, column: 1), CellState(characterId: 'A'))
          .withCell((row: 3, column: 3), CellState(characterId: 'B'))
          .withCell((row: 4, column: 5), CellState(characterId: 'X'));

      expect(canSubmit(duplicate, solution), isFalse);
      expect(canSubmit(unknown, solution), isFalse);
    });

    test('Different board dimensions prevent submission', () {
      final board = BoardState.empty(9, 9);

      expect(canSubmit(board, solution), isFalse);
    });

    test('Solution is an independent unmodifiable copy', () {
      final source = <String, CellPosition>{'A': (row: 0, column: 0)};

      final immutable = CaseSolution(
        rows: 6,
        columns: 6,
        characterPositions: source,
      );

      source['A'] = (row: 2, column: 2);

      expect(immutable.characterPositions['A'], (row: 0, column: 0));

      expect(
        () => immutable.characterPositions['B'] = (row: 3, column: 3),
        throwsUnsupportedError,
      );
    });

    test('Invalid reference solutions are rejected', () {
      expect(
        () => CaseSolution(
          rows: 6,
          columns: 6,
          characterPositions: {'A': (row: 6, column: 0)},
        ),
        throwsRangeError,
      );

      expect(
        () => CaseSolution(
          rows: 6,
          columns: 6,
          characterPositions: {
            'A': (row: 1, column: 1),
            'B': (row: 1, column: 1),
          },
        ),
        throwsArgumentError,
      );
    });

    test('Reference map insertion order does not matter', () {
      final reordered = CaseSolution(
        rows: 6,
        columns: 6,
        characterPositions: {
          'V': (row: 4, column: 5),
          'B': (row: 3, column: 3),
          'A': (row: 1, column: 1),
        },
      );

      final board = makeBoard(
        a: (row: 1, column: 1),
        b: (row: 3, column: 3),
        v: (row: 4, column: 5),
      );

      expect(evaluateSubmission(board, reordered).solved, isTrue);
    });

    test('Evaluation never changes the player board', () {
      final board = makeBoard(
        a: (row: 1, column: 1),
        b: (row: 3, column: 3),
        v: (row: 4, column: 5),
      );

      final before = board.cellAt((row: 1, column: 1));

      evaluateSubmission(board, solution);

      expect(identical(board.cellAt((row: 1, column: 1)), before), isTrue);
      expect(board.cellAt((row: 1, column: 1)).characterId, 'A');
    });
  });
}
