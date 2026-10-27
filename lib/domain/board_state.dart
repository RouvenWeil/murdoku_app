// Named row and column coordinates shared across board and case data
typedef CellPosition = ({int row, int column});

// Player-owned markings independent of fixed scene objects
class CellState {
  final bool crossed;
  final Set<String> notes;
  final String? characterId;

  // Immutable note sets prevent changes to previous board snapshots
  CellState({
    this.crossed = false,
    Set<String> notes = const {},
    this.characterId,
  }) : notes = Set.unmodifiable(notes);

  bool get isEmpty => !crossed && notes.isEmpty && characterId == null;
}

class BoardState {
  final int rows;
  final int columns;

  // Sparse storage of nonempty cells only
  final Map<CellPosition, CellState> _cells;

  BoardState._(this.rows, this.columns, this._cells);

  factory BoardState.empty(int rows, int columns) {
    if (rows <= 0 || columns <= 0) {
      throw ArgumentError('Board dimensions must be positive.');
    }

    return BoardState._(
      rows,
      columns,
      Map.unmodifiable(<CellPosition, CellState>{}),
    );
  }

  CellState cellAt(CellPosition position) {
    _validate(position);

    return _cells[position] ?? CellState();
  }

  // Copy-on-write cell updates preserve previous board instances
  BoardState withCell(CellPosition position, CellState value) {
    _validate(position);

    final next = Map<CellPosition, CellState>.of(_cells);

    // Empty markings have no entry in sparse board storage
    if (value.isEmpty) {
      next.remove(position);
    } else {
      next[position] = value;
    }

    return BoardState._(rows, columns, Map.unmodifiable(next));
  }

  void _validate(CellPosition position) {
    if (position.row < 0 ||
        position.row >= rows ||
        position.column < 0 ||
        position.column >= columns) {
      throw RangeError('Cell position is outside the board.');
    }
  }
}
