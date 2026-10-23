// Coordinates gameplay actions and bounded Undo history.
import '../domain/board_actions.dart' as actions;
import '../domain/board_state.dart';

class BoardSession {
  // Creates a session with an initial board and history limit.
  BoardSession({required BoardState initialBoard, this.historyLimit = 20})
    : _board = initialBoard {
    if (historyLimit <= 0) {
      throw ArgumentError.value(historyLimit, 'historyLimit');
    }
  }

  BoardState _board;
  final int historyLimit;
  final List<BoardState> _undoHistory = [];

  // Exposes the current immutable board.
  BoardState get board => _board;

  // Indicates whether an action can be undone.
  bool get canUndo => _undoHistory.isNotEmpty;

  // Exposes the number of available Undo steps.
  int get undoDepth => _undoHistory.length;

  // Applies an action and records its previous board if it changed.
  bool _apply(BoardState Function(BoardState) action) {
    final before = _board;
    final after = action(before);

    // Rejected or ineffective actions create no history entry.
    if (identical(after, before)) {
      return false;
    }

    // Remove the oldest snapshot when history is full.
    if (_undoHistory.length == historyLimit) {
      _undoHistory.removeAt(0);
    }

    // Record one snapshot for the entire action.
    _undoHistory.add(before);
    _board = after;
    return true;
  }

  // Toggles a cross through the existing domain action.
  bool toggleCross(CellPosition position) {
    return _apply((board) => actions.toggleCross(board, position));
  }

  // Toggles a note through the existing domain action.
  bool toggleNote(CellPosition position, String characterId) {
    return _apply((board) => actions.toggleNote(board, position, characterId));
  }

  // Places a character and its generated crosses as one action.
  bool placeCharacter(CellPosition position, String characterId) {
    return _apply(
      (board) => actions.placeCharacter(board, position, characterId),
    );
  }

  // Erases all markings in a single cell.
  bool eraseCell(CellPosition position) {
    return _apply((board) => actions.eraseCell(board, position));
  }

  // Restores the board before the most recent successful action.
  bool undo() {
    if (_undoHistory.isEmpty) {
      return false;
    }

    _board = _undoHistory.removeLast();
    return true;
  }

  // Clears the entire board and discards all Undo history.
  void clearAll() {
    _board = BoardState.empty(_board.rows, _board.columns);
    _undoHistory.clear();
  }
}
