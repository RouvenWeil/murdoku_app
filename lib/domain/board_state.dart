// A cell is identified by its row and column.
typedef CellPosition = ({int row, int column});

// Stores everything the player can place in one cell.
class CellState {
  final bool crossed; // Whether the cell has an X.
  final Set<String> notes; // Characters noted as possibilities.
  final String? characterId; // Placed character, or null if none.

  // Creates a cell with optional initial values.
  CellState({
    this.crossed = false,
    Set<String> notes = const {},
    this.characterId,
  }) : notes = Set.unmodifiable(notes); // Prevents changing notes later.

  // Checks whether the cell contains any player markings.
  bool get isEmpty => !crossed && notes.isEmpty && characterId == null;
}

// Represents the complete state of the puzzle board.
class BoardState {
  final int rows; // Number of rows in the board.
  final int columns; // Number of columns in the board.

  // Stores only cells that contain player markings.
  final Map<CellPosition, CellState> _cells;

  // Private constructor: board creation is controlled internally.
  BoardState._(this.rows, this.columns, this._cells);

  // Creates an empty board of the requested dimensions.
  factory BoardState.empty(int rows, int columns) {
    // Rejects invalid board dimensions.
    if (rows <= 0 || columns <= 0) {
      throw ArgumentError('Board dimensions must be positive.');
    }

    // Returns a new board with an empty, unmodifiable map.
    return BoardState._(
      rows,
      columns,
      Map.unmodifiable(<CellPosition, CellState>{}),
    );
  }

  // Returns the state of a cell at a specific position.
  CellState cellAt(CellPosition position) {
    // Ensures the requested position exists on the board.
    _validate(position);

    // Returns the stored cell, or an empty cell if none exists.
    return _cells[position] ?? CellState();
  }

  // Creates a new board with one cell changed.
  BoardState withCell(CellPosition position, CellState value) {
    // Prevents writing outside the board.
    _validate(position);

    // Copies the original map so it stays unchanged.
    final next = Map<CellPosition, CellState>.of(_cells);

    // Removes cells that no longer contain any markings.
    if (value.isEmpty) {
      next.remove(position);
    } else {
      // Adds or replaces the changed cell.
      next[position] = value;
    }

    // Returns a new board containing the updated map.
    return BoardState._(rows, columns, Map.unmodifiable(next));
  }

  // Checks whether a coordinate is inside the board.
  void _validate(CellPosition position) {
    // Rejects negative coordinates or coordinates beyond the edges.
    if (position.row < 0 ||
        position.row >= rows ||
        position.column < 0 ||
        position.column >= columns) {
      throw RangeError('Cell position is outside the board.');
    }
  }
}
