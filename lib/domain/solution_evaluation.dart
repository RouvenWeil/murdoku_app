import 'package:collection/collection.dart';

import 'board_state.dart';

// Immutable reference positions independent of player state
class CaseSolution {
  final int rows;
  final int columns;
  final Map<String, CellPosition> characterPositions;

  CaseSolution({
    required this.rows,
    required this.columns,
    required Map<String, CellPosition> characterPositions,
  }) : characterPositions = Map<String, CellPosition>.unmodifiableOf(
         characterPositions,
       ) {
    if (rows <= 0 || columns <= 0) {
      throw ArgumentError('Board dimensions must be positive.');
    }

    if (this.characterPositions.isEmpty) {
      throw ArgumentError('A case needs at least one character.');
    }

    // Duplicate reference cells rejected during case construction
    final occupied = <CellPosition>{};

    for (final entry in this.characterPositions.entries) {
      if (entry.key.trim().isEmpty) {
        throw ArgumentError('Character IDs cannot be empty.');
      }

      final position = entry.value;

      if (position.row < 0 ||
          position.row >= rows ||
          position.column < 0 ||
          position.column >= columns) {
        throw RangeError('Solution position is outside the board.');
      }

      if (!occupied.add(position)) {
        throw ArgumentError('Two characters share a solution cell.');
      }
    }
  }
}

// Submission feedback defined per committed character cell
enum PlacementVerdict { correct, incorrect }

class SubmissionResult {
  final bool solved;
  final Map<CellPosition, PlacementVerdict> feedbackByCell;

  SubmissionResult._({
    required this.solved,
    required Map<CellPosition, PlacementVerdict> feedbackByCell,
  }) : feedbackByCell = Map<CellPosition, PlacementVerdict>.unmodifiableOf(
         feedbackByCell,
       );
}

// Eligibility checks committed character identities only player notes and crosses excluded from solution evaluation
Map<String, CellPosition>? _eligiblePlacements(
  BoardState board,
  CaseSolution solution,
) {
  if (board.rows != solution.rows || board.columns != solution.columns) {
    return null;
  }

  final placements = <String, CellPosition>{};

  for (var row = 0; row < board.rows; row++) {
    for (var column = 0; column < board.columns; column++) {
      final position = (row: row, column: column);
      final characterId = board.cellAt(position).characterId;

      if (characterId == null) continue;

      if (placements.containsKey(characterId)) {
        return null;
      }

      placements[characterId] = position;
    }
  }

  // Only the exact expected set of characters is eligible for Submit
  if (placements.length != solution.characterPositions.length) {
    return null;
  }

  for (final characterId in solution.characterPositions.keys) {
    if (!placements.containsKey(characterId)) {
      return null;
    }
  }

  return placements;
}

bool canSubmit(BoardState board, CaseSolution solution) {
  return _eligiblePlacements(board, solution) != null;
}

SubmissionResult evaluateSubmission(BoardState board, CaseSolution solution) {
  final placements = _eligiblePlacements(board, solution);

  if (placements == null) {
    throw StateError('The board is not ready for submission.');
  }

  // Value-based map comparison independent of insertion order
  const equality = MapEquality<String, CellPosition>();

  final solved = equality.equals(placements, solution.characterPositions);

  // Feedback keyed by submitted positions for cell-specific display
  final feedback = <CellPosition, PlacementVerdict>{};

  for (final entry in placements.entries) {
    final expected = solution.characterPositions[entry.key];

    feedback[entry.value] = expected == entry.value
        ? PlacementVerdict.correct
        : PlacementVerdict.incorrect;
  }

  return SubmissionResult._(solved: solved, feedbackByCell: feedback);
}
