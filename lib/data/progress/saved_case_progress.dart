import '../../domain/board_state.dart';
import '../../domain/case_definition.dart';
import '../../domain/solution_evaluation.dart';
import 'case_content_fingerprint.dart';

/// One immutable, validated *attempt* suitable for a versioned local save.
///
/// This is a data contract only. WP-04.2 provides I/O, ordering and recovery.
/// Transient selection, pins, viewport origin and Undo are intentionally absent.
class SavedCaseProgress {
  SavedCaseProgress._({
    required this.caseId,
    required this.rows,
    required this.columns,
    required this.caseFingerprint,
    required this.board,
    required Map<CellPosition, PlacementVerdict> feedbackByCell,
    required this.isSolved,
    required this.attemptStarted,
    required this.elapsed,
  }) : feedbackByCell = Map.unmodifiable(feedbackByCell);

  static const int currentSchemaVersion = 1;

  final String caseId;
  final int rows;
  final int columns;
  final String caseFingerprint;
  final BoardState board;
  final Map<CellPosition, PlacementVerdict> feedbackByCell;
  final bool isSolved;

  /// Distinguishes a brand-new attempt from an emptied/reset one, even at 0ms.
  final bool attemptStarted;
  final Duration elapsed;

  static SavedCaseProgress forCase({
    required CaseDefinition caseData,
    required BoardState board,
    required Map<CellPosition, PlacementVerdict> feedbackByCell,
    required bool isSolved,
    required bool attemptStarted,
    required Duration elapsed,
  }) {
    final progress = SavedCaseProgress._(
      caseId: caseData.id,
      rows: caseData.rows,
      columns: caseData.columns,
      caseFingerprint: CaseContentFingerprint.forCase(caseData),
      board: board,
      feedbackByCell: feedbackByCell,
      isSolved: isSolved,
      attemptStarted: attemptStarted,
      elapsed: elapsed,
    );
    progress.validateAgainst(caseData);
    return progress;
  }

  /// Structural checks, **not** solution evaluation. A submitted incorrect
  /// board and its historical verdicts must round-trip unaltered.
  void validateAgainst(CaseDefinition caseData) {
    if (caseId != caseData.id ||
        rows != caseData.rows ||
        columns != caseData.columns ||
        board.rows != rows ||
        board.columns != columns ||
        caseFingerprint != CaseContentFingerprint.forCase(caseData)) {
      throw const FormatException('Progress does not match this case version.');
    }
    if (elapsed.isNegative) {
      throw const FormatException('Elapsed time cannot be negative.');
    }

    final known = caseData.solution.characterPositions.keys.toSet();
    final placed = <String>{};
    var marked = false;
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final position = (row: row, column: column);
        final cell = board.cellAt(position);
        if (cell.isEmpty) {
          continue;
        }
        marked = true;
        if (!caseData.canOccupy(position)) {
          throw FormatException('Mark on non-occupiable cell ($row,$column).');
        }
        if (cell.crossed &&
            (cell.notes.isNotEmpty || cell.characterId != null)) {
          throw FormatException(
            'Cross conflicts with other marks at ($row,$column).',
          );
        }
        if (cell.characterId != null && cell.notes.isNotEmpty) {
          throw FormatException(
            'Character conflicts with notes at ($row,$column).',
          );
        }
        for (final note in cell.notes) {
          if (!known.contains(note)) {
            throw FormatException('Unknown note character: $note.');
          }
        }
        final character = cell.characterId;
        if (character != null) {
          if (!known.contains(character) || !placed.add(character)) {
            throw FormatException(
              'Unknown or duplicate placed character: $character.',
            );
          }
        }
      }
    }

    for (final entry in feedbackByCell.entries) {
      if (entry.key.row < 0 ||
          entry.key.row >= rows ||
          entry.key.column < 0 ||
          entry.key.column >= columns) {
        throw const FormatException('Feedback coordinate is outside the grid.');
      }
      final cell = board.cellAt(entry.key);
      if (cell.characterId == null || !caseData.canOccupy(entry.key)) {
        throw const FormatException('Verdict has no corresponding placement.');
      }
    }
    if (isSolved) {
      // A solved snapshot must be internally complete, but is never re-graded.
      if (placed.length != known.length ||
          feedbackByCell.length != known.length ||
          feedbackByCell.values.any((v) => v != PlacementVerdict.correct)) {
        throw const FormatException(
          'Solved snapshot is structurally incomplete.',
        );
      }
    }
    if (!attemptStarted &&
        (marked ||
            feedbackByCell.isNotEmpty ||
            isSolved ||
            elapsed > Duration.zero)) {
      throw const FormatException(
        'New attempt cannot already contain progress.',
      );
    }
  }
}
