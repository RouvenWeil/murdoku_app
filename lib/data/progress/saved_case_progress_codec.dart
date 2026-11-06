import 'dart:convert';

import '../../domain/board_state.dart';
import '../../domain/case_definition.dart';
import '../../domain/solution_evaluation.dart';
import 'case_content_fingerprint.dart';
import 'saved_case_progress.dart';

/// Version 1 sparse JSON codec. Decoding never calls GameSession.submit or
/// evaluateSubmission and therefore never manufactures correctness feedback.
abstract final class SavedCaseProgressCodec {
  static String encode(SavedCaseProgress progress) =>
      jsonEncode(toJson(progress));

  static Map<String, Object?> toJson(SavedCaseProgress progress) {
    final cells = <Map<String, Object?>>[];
    for (var row = 0; row < progress.rows; row++) {
      for (var col = 0; col < progress.columns; col++) {
        final cell = progress.board.cellAt((row: row, column: col));
        if (cell.isEmpty) {
          continue;
        }
        cells.add({
          'row': row,
          'column': col,
          'crossed': cell.crossed,
          'notes': cell.notes.toList()..sort(),
          'characterId': cell.characterId,
        });
      }
    }
    final verdicts = progress.feedbackByCell.entries.toList()
      ..sort((a, b) {
        final row = a.key.row.compareTo(b.key.row);
        return row != 0 ? row : a.key.column.compareTo(b.key.column);
      });
    return {
      'schemaVersion': SavedCaseProgress.currentSchemaVersion,
      'caseId': progress.caseId,
      'rows': progress.rows,
      'columns': progress.columns,
      'caseFingerprint': progress.caseFingerprint,
      'attemptStarted': progress.attemptStarted,
      'elapsedMilliseconds': progress.elapsed.inMilliseconds,
      'isSolved': progress.isSolved,
      'cells': cells,
      'feedback': [
        for (final entry in verdicts)
          {
            'row': entry.key.row,
            'column': entry.key.column,
            'verdict': entry.value.name,
          },
      ],
    };
  }

  static SavedCaseProgress decode(String source, CaseDefinition caseData) {
    Object? data;
    try {
      data = jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException('Progress JSON is corrupt: $error');
    }
    return fromJson(data, caseData);
  }

  static SavedCaseProgress fromJson(Object? value, CaseDefinition caseData) {
    final json = _map(value, 'progress');
    _keys(json, const {
      'schemaVersion',
      'caseId',
      'rows',
      'columns',
      'caseFingerprint',
      'attemptStarted',
      'elapsedMilliseconds',
      'isSolved',
      'cells',
      'feedback',
    }, 'progress');
    if (_int(json['schemaVersion'], 'schemaVersion') !=
        SavedCaseProgress.currentSchemaVersion) {
      throw const FormatException('Unsupported progress schema version.');
    }
    if (_string(json['caseId'], 'caseId') != caseData.id ||
        _int(json['rows'], 'rows') != caseData.rows ||
        _int(json['columns'], 'columns') != caseData.columns ||
        _string(json['caseFingerprint'], 'caseFingerprint') !=
            CaseContentFingerprint.forCase(caseData)) {
      throw const FormatException(
        'Progress belongs to a different case/version.',
      );
    }
    final milliseconds = _int(
      json['elapsedMilliseconds'],
      'elapsedMilliseconds',
    );
    if (milliseconds < 0) {
      throw const FormatException('Elapsed time cannot be negative.');
    }
    final started = _bool(json['attemptStarted'], 'attemptStarted');
    final solved = _bool(json['isSolved'], 'isSolved');
    var board = BoardState.empty(caseData.rows, caseData.columns);
    final seenCells = <CellPosition>{};
    for (final raw in _list(json['cells'], 'cells')) {
      final cellData = _map(raw, 'cell');
      _keys(cellData, const {
        'row',
        'column',
        'crossed',
        'notes',
        'characterId',
      }, 'cell');
      final position = _position(cellData, caseData.rows, caseData.columns);
      if (!seenCells.add(position)) {
        throw const FormatException('Duplicate marked cell.');
      }
      final crossed = _bool(cellData['crossed'], 'crossed');
      final noteIds = <String>{};
      for (final note in _list(cellData['notes'], 'notes')) {
        final id = _string(note, 'note ID');
        if (!noteIds.add(id)) {
          throw const FormatException('Duplicate note in a cell.');
        }
      }
      final rawId = cellData['characterId'];
      final character = rawId == null ? null : _string(rawId, 'characterId');
      final cell = CellState(
        crossed: crossed,
        notes: noteIds,
        characterId: character,
      );
      if (cell.isEmpty) {
        throw const FormatException('Sparse save contains an empty cell.');
      }
      board = board.withCell(position, cell);
    }
    final feedback = <CellPosition, PlacementVerdict>{};
    for (final raw in _list(json['feedback'], 'feedback')) {
      final feedbackData = _map(raw, 'feedback entry');
      _keys(feedbackData, const {'row', 'column', 'verdict'}, 'feedback entry');
      final position = _position(feedbackData, caseData.rows, caseData.columns);
      final verdictName = _string(feedbackData['verdict'], 'verdict');
      final verdict = switch (verdictName) {
        'correct' => PlacementVerdict.correct,
        'incorrect' => PlacementVerdict.incorrect,
        _ => throw FormatException('Unknown verdict: $verdictName.'),
      };
      if (feedback.containsKey(position)) {
        throw const FormatException('Duplicate feedback coordinate.');
      }
      feedback[position] = verdict;
    }
    return SavedCaseProgress.forCase(
      caseData: caseData,
      board: board,
      feedbackByCell: feedback,
      isSolved: solved,
      attemptStarted: started,
      elapsed: Duration(milliseconds: milliseconds),
    );
  }

  static CellPosition _position(
    Map<String, dynamic> data,
    int rows,
    int columns,
  ) {
    final row = _int(data['row'], 'row');
    final column = _int(data['column'], 'column');
    if (row < 0 || row >= rows || column < 0 || column >= columns) {
      throw FormatException(
        'Progress coordinate ($row,$column) is outside the grid.',
      );
    }
    return (row: row, column: column);
  }

  static Map<String, dynamic> _map(Object? obj, String name) {
    if (obj is! Map || obj.keys.any((key) => key is! String)) {
      throw FormatException('$name must be a string-keyed map.');
    }
    return Map<String, dynamic>.from(obj);
  }

  static List<dynamic> _list(Object? obj, String name) {
    if (obj is! List) {
      throw FormatException('$name must be an array.');
    }
    return obj;
  }

  static String _string(Object? obj, String name) {
    if (obj is! String || obj.isEmpty) {
      throw FormatException('$name must be a nonempty string.');
    }
    return obj;
  }

  static int _int(Object? obj, String name) {
    if (obj is! int) {
      throw FormatException('$name must be an integer.');
    }
    return obj;
  }

  static bool _bool(Object? obj, String name) {
    if (obj is! bool) {
      throw FormatException('$name must be a boolean.');
    }
    return obj;
  }

  static void _keys(
    Map<String, dynamic> json,
    Set<String> expected,
    String name,
  ) {
    if (json.keys.toSet().difference(expected).isNotEmpty ||
        expected.difference(json.keys.toSet()).isNotEmpty) {
      throw FormatException('$name has missing or unexpected fields.');
    }
  }
}
