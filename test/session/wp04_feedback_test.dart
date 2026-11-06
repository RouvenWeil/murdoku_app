import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/domain/board_state.dart';
import 'package:murdoku_app/domain/solution_evaluation.dart';
import 'package:murdoku_app/session/game_session.dart';

void main() {
  final truth = CaseSolution(
    rows: 4,
    columns: 4,
    characterPositions: {'A': (row: 0, column: 0), 'V': (row: 2, column: 2)},
  );

  GameSession submitted() {
    final game = GameSession(
      solution: truth,
      initialBoard: BoardState.empty(4, 4)
          .withCell((row: 0, column: 0), CellState(characterId: 'A'))
          .withCell((row: 2, column: 1), CellState(characterId: 'V')),
    );
    expect(game.submit().solved, isFalse);
    return game;
  }

  test('unrelated note edit and its Undo do not invalidate other feedback', () {
    final game = submitted();
    final feedback = game.feedbackByCell;
    expect(game.addNote((row: 3, column: 3), 'A'), isTrue);
    expect(game.feedbackByCell, feedback);
    expect(game.undo(), isTrue);
    expect(game.feedbackByCell, feedback);
  });

  test(
    'changing submitted cell drops only that feedback; Undo cannot restore it',
    () {
      final game = submitted();
      expect(game.feedbackByCell.length, 2);
      expect(game.eraseCell((row: 2, column: 1)), isTrue);
      expect(game.feedbackByCell.length, 1);
      expect(
        game.feedbackByCell[(row: 0, column: 0)],
        PlacementVerdict.correct,
      );
      expect(game.undo(), isTrue);
      expect(game.board.cellAt((row: 2, column: 1)).characterId, 'V');
      expect(game.feedbackByCell.length, 1);
    },
  );

  test('invalid/no-op edits do not change feedback map identity', () {
    final game = submitted();
    final existing = game.feedbackByCell;
    expect(game.addNote((row: 0, column: 0), 'A'), isFalse);
    expect(identical(game.feedbackByCell, existing), isTrue);
  });
}
