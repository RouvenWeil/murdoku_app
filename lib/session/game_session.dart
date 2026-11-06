import '../domain/board_state.dart';
import '../domain/case_definition.dart';
import '../domain/solution_evaluation.dart' as evaluation;
import 'board_session.dart';

// Session coordinator separating board history, feedback and completion
class GameSession {
  GameSession({
    required BoardState initialBoard,
    required evaluation.CaseSolution solution,
    int historyLimit = 20,
  }) : this._(
         initialBoard: initialBoard,
         solution: solution,
         historyLimit: historyLimit,
         canOccupy: null,
       );

  // Case-based sessions use the scene grid as the placement boundary
  GameSession.fromCase(
    CaseDefinition caseDefinition, {
    int historyLimit = 20,
    BoardState? restoredBoard,
    Map<CellPosition, evaluation.PlacementVerdict> restoredFeedback = const {},
    bool previouslySolved = false,
  }) : this._(
         initialBoard:
             restoredBoard ??
             BoardState.empty(caseDefinition.rows, caseDefinition.columns),
         solution: caseDefinition.solution,
         historyLimit: historyLimit,
         canOccupy: caseDefinition.canOccupy,
         initialFeedback: restoredFeedback,
         initiallySolved: previouslySolved,
       );

  GameSession._({
    required BoardState initialBoard,
    required evaluation.CaseSolution solution,
    required int historyLimit,
    required this._canOccupy,
    Map<CellPosition, evaluation.PlacementVerdict> initialFeedback = const {},
    bool initiallySolved = false,
  }) : _solution = solution,
       _feedbackByCell = Map.unmodifiable(initialFeedback),
       _isSolved = initiallySolved,
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
  final bool Function(CellPosition)? _canOccupy;

  // Terminal completion flag locks the existing attempt
  bool _isSolved;

  // Feedback lifetime independent of BoardSession Undo history
  Map<CellPosition, evaluation.PlacementVerdict> _feedbackByCell;

  BoardState get board => _boardSession.board;

  bool get isSolved => _isSolved;

  bool get canUndo => !_isSolved && _boardSession.canUndo;

  int get undoDepth => _boardSession.undoDepth;

  bool get canSubmit => !_isSolved && evaluation.canSubmit(board, _solution);

  Map<CellPosition, evaluation.PlacementVerdict> get feedbackByCell =>
      _feedbackByCell;

  // Feedback survives only when every mark in the submitted cell is unchanged
  bool _applyEdit(bool Function() action) {
    if (_isSolved) return false;

    final before = board;
    final changed = action();

    if (!changed) return false;

    _invalidateChangedPlacements(before, board);
    return true;
  }

  void _invalidateChangedPlacements(BoardState before, BoardState after) {
    if (_feedbackByCell.isEmpty) return;

    final retained = <CellPosition, evaluation.PlacementVerdict>{};

    for (final entry in _feedbackByCell.entries) {
      final position = entry.key;

      final previous = before.cellAt(position);
      final current = after.cellAt(position);
      if (previous.characterId == current.characterId &&
          previous.crossed == current.crossed &&
          previous.notes.length == current.notes.length &&
          previous.notes.containsAll(current.notes)) {
        retained[position] = entry.value;
      }
    }

    _feedbackByCell =
        Map<CellPosition, evaluation.PlacementVerdict>.unmodifiableOf(retained);
  }

  bool toggleNote(CellPosition position, String characterId) {
    final canOccupy = _canOccupy;
    if (canOccupy != null && !canOccupy(position)) return false;
    if (canOccupy != null &&
        !_solution.characterPositions.containsKey(characterId)) {
      return false;
    }
    return _applyEdit(() => _boardSession.toggleNote(position, characterId));
  }

  // Commit one visited cell immediately; never toggle existing notes off.
  bool addNote(CellPosition position, String characterId) {
    final canOccupy = _canOccupy;
    if (_isSolved ||
        (canOccupy != null &&
            (!canOccupy(position) ||
                !_solution.characterPositions.containsKey(characterId)))) {
      return false;
    }
    return _applyEdit(() => _boardSession.addNote(position, characterId));
  }

  bool toggleCross(CellPosition position) {
    final canOccupy = _canOccupy;
    if (canOccupy != null && !canOccupy(position)) return false;
    return _applyEdit(() => _boardSession.toggleCross(position));
  }

  bool placeCharacter(CellPosition position, String characterId) {
    if (_isSolved) return false;

    // Unknown IDs and non-occupiable case cells do not create board history
    final canOccupy = _canOccupy;
    if (canOccupy != null) {
      if (!_solution.characterPositions.containsKey(characterId)) return false;
      if (!canOccupy(position)) return false;
    }

    return _applyEdit(
      () => _boardSession.placeCharacter(
        position,
        characterId,
        canMark: canOccupy,
      ),
    );
  }

  bool eraseCell(CellPosition position) {
    final canOccupy = _canOccupy;
    if (canOccupy != null && !canOccupy(position)) return false;
    return _applyEdit(() => _boardSession.eraseCell(position));
  }

  // Undo restores board state without restoring previously discarded feedback
  bool undo() {
    return _applyEdit(_boardSession.undo);
  }

  bool clearAll() {
    if (_isSolved) return false;

    _boardSession.clearAll();
    _feedbackByCell = const {};

    return true;
  }

  // Explicit submission replaces feedback and sets terminal solved state
  evaluation.SubmissionResult submit() {
    if (_isSolved) {
      throw StateError('This case is already solved.');
    }

    if (!canSubmit) {
      throw StateError('Not all required characters are placed.');
    }

    final result = evaluation.evaluateSubmission(board, _solution);

    _feedbackByCell = result.feedbackByCell;

    if (result.solved) {
      _isSolved = true;
    }

    return result;
  }
}
