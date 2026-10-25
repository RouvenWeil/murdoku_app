
import '../domain/board_state.dart';
import '../domain/solution_evaluation.dart' as evaluation;
import 'board_session.dart';

/// Coordinates one attempt at solving a Murdoku case.
///
/// Board history, submission feedback, and completion state are
/// deliberately separate responsibilities.
class GameSession {
  GameSession({
    required BoardState initialBoard,
    required evaluation.CaseSolution solution,
    int historyLimit = 20,
  })  : _solution = solution,
        _boardSession = BoardSession(
          initialBoard: initialBoard,
          historyLimit: historyLimit,
        ) {
    if (initialBoard.rows != solution.rows ||
        initialBoard.columns != solution.columns) {
      throw ArgumentError(
        'Initial board dimensions must match the case solution.',
      );
    }
  }

  final BoardSession _boardSession;
  final evaluation.CaseSolution _solution;

  bool _isSolved = false;

  // Feedback is not part of the board's Undo snapshots.
  Map<CellPosition, evaluation.PlacementVerdict> _feedbackByCell =
  const {};

  // Public read-only state.
  BoardState get board => _boardSession.board;

  bool get isSolved => _isSolved;

  bool get canUndo => !_isSolved && _boardSession.canUndo;

  int get undoDepth => _boardSession.undoDepth;

  bool get canSubmit =>
      !_isSolved && evaluation.canSubmit(board, _solution);

  Map<CellPosition, evaluation.PlacementVerdict> get feedbackByCell =>
      _feedbackByCell;

  /// Applies an edit while maintaining feedback consistency.
  ///
  /// Returns false if the case is solved or the action is a no-op.
  bool _applyEdit(bool Function() action) {
    if (_isSolved) return false;

    final before = board;
    final changed = action();

    if (!changed) return false;

    _invalidateChangedPlacements(before, board);
    return true;
  }

  /// Keeps feedback only where the committed character is unchanged.
  ///
  /// This checks placement identity, not notes or crosses.
  void _invalidateChangedPlacements(
      BoardState before,
      BoardState after,
      ) {
    if (_feedbackByCell.isEmpty) return;

    final retained = <CellPosition, evaluation.PlacementVerdict>{};

    for (final entry in _feedbackByCell.entries) {
      final position = entry.key;

      final previousCharacter =
          before.cellAt(position).characterId;
      final currentCharacter =
          after.cellAt(position).characterId;

      if (previousCharacter == currentCharacter) {
        retained[position] = entry.value;
      }
    }

    _feedbackByCell =
    Map<CellPosition, evaluation.PlacementVerdict>.unmodifiableOf(
      retained,
    );
  }

  // Player actions delegate to BoardSession.

  bool toggleNote(CellPosition position, String characterId) {
    return _applyEdit(
          () => _boardSession.toggleNote(position, characterId),
    );
  }

  bool toggleCross(CellPosition position) {
    return _applyEdit(
          () => _boardSession.toggleCross(position),
    );
  }

  bool placeCharacter(CellPosition position, String characterId) {
    return _applyEdit(
          () => _boardSession.placeCharacter(position, characterId),
    );
  }

  bool eraseCell(CellPosition position) {
    return _applyEdit(
          () => _boardSession.eraseCell(position),
    );
  }

  /// Restores the previous board, but never restores old feedback.
  bool undo() {
    return _applyEdit(_boardSession.undo);
  }

  /// Clears markings, feedback, and Undo history.
  ///
  /// Returns false if the solved board is locked.
  /// Otherwise returns true when the reset command is accepted.
  bool clearAll() {
    if (_isSolved) return false;

    _boardSession.clearAll();
    _feedbackByCell = const {};

    return true;
  }

  /// Evaluates an eligible board following an explicit Submit.
  ///
  /// Incorrect attempts remain editable.
  /// Correct attempts transition permanently to Solved.
  evaluation.SubmissionResult submit() {
    if (_isSolved) {
      throw StateError('This case is already solved.');
    }

    if (!canSubmit) {
      throw StateError('Not all required characters are placed.');
    }

    final result =
    evaluation.evaluateSubmission(board, _solution);

    // SubmissionResult already exposes an unmodifiable map.
    _feedbackByCell = result.feedbackByCell;

    if (result.solved) {
      _isSolved = true;
    }

    return result;
  }
}
