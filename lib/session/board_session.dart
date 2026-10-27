import '../domain/board_actions.dart' as actions;
import '../domain/board_state.dart';

// Mutable coordinator around immutable board snapshots
class BoardSession {
  BoardSession({required BoardState initialBoard, this.historyLimit = 20})
    : _board = initialBoard {
    if (historyLimit <= 0) {
      throw ArgumentError.value(historyLimit, 'historyLimit');
    }
  }

  BoardState _board;
  final int historyLimit;
  // Bounded Undo history stored as complete board snapshots
  final List<BoardState> _undoHistory = [];

  BoardState get board => _board;

  bool get canUndo => _undoHistory.isNotEmpty;

  int get undoDepth => _undoHistory.length;

  bool _apply(BoardState Function(BoardState) action) {
    final before = _board;
    final after = action(before);

    // Reference identity detects rejected or ineffective domain actions
    if (identical(after, before)) {
      return false;
    }

    // Oldest snapshot discarded once the configured limit is reached
    if (_undoHistory.length == historyLimit) {
      _undoHistory.removeAt(0);
    }

    // One history entry per accepted player action
    _undoHistory.add(before);
    _board = after;
    return true;
  }

  bool toggleCross(CellPosition position) {
    return _apply((board) => actions.toggleCross(board, position));
  }

  bool toggleNote(CellPosition position, String characterId) {
    return _apply((board) => actions.toggleNote(board, position, characterId));
  }

  bool placeCharacter(CellPosition position, String characterId) {
    return _apply(
      (board) => actions.placeCharacter(board, position, characterId),
    );
  }

  bool eraseCell(CellPosition position) {
    return _apply((board) => actions.eraseCell(board, position));
  }

  bool undo() {
    if (_undoHistory.isEmpty) {
      return false;
    }

    _board = _undoHistory.removeLast();
    return true;
  }

  // Reset discards both player markings and Undo history
  void clearAll() {
    _board = BoardState.empty(_board.rows, _board.columns);
    _undoHistory.clear();
  }
}
