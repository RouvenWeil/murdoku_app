import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/data/progress/case_content_fingerprint.dart';
import 'package:murdoku_app/data/progress/saved_case_progress.dart';
import 'package:murdoku_app/data/progress/saved_case_progress_codec.dart';
import 'package:murdoku_app/domain/board_state.dart';
import 'package:murdoku_app/domain/case_definition.dart';
import 'package:murdoku_app/domain/object_definition.dart';
import 'package:murdoku_app/domain/solution_evaluation.dart';

CaseDefinition _loadCase(String id) {
  final catalogJson = jsonDecode(
    File('assets/object-catalog.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final catalog = {
    for (final entry in catalogJson.entries)
      entry.key: ObjectDefinition.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      ),
  };
  final json = jsonDecode(
    File('assets/cases/$id.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return CaseDefinition.fromJson(json, objectCatalog: catalog);
}

CellPosition _freeCell(CaseDefinition c, Set<CellPosition> excluded) {
  for (var r = 0; r < c.rows; r++) {
    for (var col = 0; col < c.columns; col++) {
      final position = (row: r, column: col);
      if (c.canOccupy(position) && !excluded.contains(position)) {
        return position;
      }
    }
  }
  throw StateError('Fixture has no free cell.');
}

SavedCaseProgress _sample(CaseDefinition c) {
  final first = c.characters.first;
  final second = _freeCell(c, {first.solution});
  final third = _freeCell(c, {first.solution, second});
  final board = BoardState.empty(c.rows, c.columns)
      .withCell(first.solution, CellState(characterId: first.id))
      .withCell(second, CellState(notes: {first.id, c.characters.last.id}))
      .withCell(third, CellState(crossed: true));
  return SavedCaseProgress.forCase(
    caseData: c,
    board: board,
    feedbackByCell: {first.solution: PlacementVerdict.incorrect},
    isSolved: false,
    attemptStarted: true,
    elapsed: const Duration(minutes: 13, milliseconds: 412),
  );
}

Map<String, dynamic> _jsonCopy(SavedCaseProgress progress) =>
    jsonDecode(SavedCaseProgressCodec.encode(progress)) as Map<String, dynamic>;

void main() {
  test('WP-04.1: all selected fixture sizes round-trip with deterministic sparse marks', () {
    for (final id in ['car-repair', 'river-crossing', 'golf-course']) {
      final c = _loadCase(id);
      final before = _sample(c);
      final text = SavedCaseProgressCodec.encode(before);
      final after = SavedCaseProgressCodec.decode(text, c);
      expect((after.rows, after.columns), (c.rows, c.columns));
      expect(after.caseId, c.id);
      expect(after.caseFingerprint, before.caseFingerprint);
      expect(after.attemptStarted, isTrue);
      expect(after.elapsed, before.elapsed);
      expect(after.isSolved, isFalse);
      expect(after.feedbackByCell, before.feedbackByCell);
      expect(SavedCaseProgressCodec.encode(after), text);
      for (var r = 0; r < c.rows; r++) {
        for (var col = 0; col < c.columns; col++) {
          final p = (row: r, column: col);
          final old = before.board.cellAt(p);
          final updated = after.board.cellAt(p);
          expect(updated.characterId, old.characterId);
          expect(updated.crossed, old.crossed);
          expect(updated.notes, old.notes);
        }
      }
    }
  });

  test('empty but started attempt preserves reset/status interpretation', () {
    final c = _loadCase('car-repair');
    final reset = SavedCaseProgress.forCase(
      caseData: c,
      board: BoardState.empty(c.rows, c.columns),
      feedbackByCell: const {},
      isSolved: false,
      attemptStarted: true,
      elapsed: Duration.zero,
    );
    final restored = SavedCaseProgressCodec.decode(
      SavedCaseProgressCodec.encode(reset),
      c,
    );
    expect(restored.attemptStarted, isTrue);
    expect(restored.board.cellAt(c.characters.first.solution).isEmpty, isTrue);
  });

  test('solved snapshot round-trips without running the evaluator', () {
    final c = _loadCase('car-repair');
    var board = BoardState.empty(c.rows, c.columns);
    final feedback = <CellPosition, PlacementVerdict>{};
    for (final person in c.characters) {
      board = board.withCell(
        person.solution,
        CellState(characterId: person.id),
      );
      feedback[person.solution] = PlacementVerdict.correct;
    }
    final saved = SavedCaseProgress.forCase(
      caseData: c,
      board: board,
      feedbackByCell: feedback,
      isSolved: true,
      attemptStarted: true,
      elapsed: const Duration(minutes: 4),
    );
    expect(
      SavedCaseProgressCodec.decode(
        SavedCaseProgressCodec.encode(saved),
        c,
      ).isSolved,
      isTrue,
    );
  });

  test('progress rejects corrupt JSON, versions, identities, dimensions and compatibility', () {
    final c = _loadCase('car-repair');
    final valid = _sample(c);
    expect(() => SavedCaseProgressCodec.decode('{', c), throwsFormatException);
    final mutations = <void Function(Map<String, dynamic>)>[
      (j) => j['schemaVersion'] = 0,
      (j) => j['caseId'] = 'other-case',
      (j) => j['rows'] = 999,
      (j) => j['columns'] = -1,
      (j) => j['caseFingerprint'] = 'stale-content',
      (j) => j['elapsedMilliseconds'] = -1,
      (j) => j['elapsedMilliseconds'] = '100',
      (j) => j['attemptStarted'] = 'yes',
      (j) => j['unknownProperty'] = true,
    ];
    for (final mutate in mutations) {
      final data = _jsonCopy(valid);
      mutate(data);
      expect(
        () => SavedCaseProgressCodec.fromJson(data, c),
        throwsFormatException,
      );
    }
    final other = _loadCase('river-crossing');
    expect(
      () => SavedCaseProgressCodec.decode(
        SavedCaseProgressCodec.encode(valid),
        other,
      ),
      throwsFormatException,
    );
  });

  test(
    'rejects invalid coordinates, duplicate cells and contradictory markings',
    () {
      final c = _loadCase('car-repair');
      final valid = _sample(c);
      final mutations = <void Function(Map<String, dynamic>)>[
        (j) => (j['cells'] as List).first['row'] = -1,
        (j) => (j['cells'] as List).first['column'] = c.columns,
        (j) => (j['cells'] as List).add((j['cells'] as List).first),
        (j) => (j['cells'] as List).first['crossed'] = true,
        (j) => (j['cells'] as List).first['notes'] = ['unknown'],
        (j) => (j['cells'] as List).first['notes'] = ['A', 'A'],
        (j) => (j['cells'] as List).first['characterId'] = '???',
        // An empty sparse entry must be rejected. Locate a note-only cell
        // explicitly: setting its already-null characterId to null is a no-op.
        (j) {
          final noteOnlyCell = (j['cells'] as List)
              .cast<Map<String, dynamic>>()
              .firstWhere(
                (cell) =>
                    (cell['notes'] as List).isNotEmpty &&
                    cell['characterId'] == null &&
                    cell['crossed'] == false,
              );
          noteOnlyCell['notes'] = <String>[];
        },
      ];
      for (final mutate in mutations) {
        final data = _jsonCopy(valid);
        mutate(data);
        expect(
          () => SavedCaseProgressCodec.fromJson(data, c),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'rejects blocked marks, duplicate character placements and stray verdicts',
    () {
      final c = _loadCase('car-repair');
      final valid = _sample(c);
      final first = c.characters.first;
      final blocked = (row: 0, column: 0);
      expect(c.canOccupy(blocked), isFalse);
      final blockedData = _jsonCopy(valid);
      (blockedData['cells'] as List).add({
        'row': blocked.row,
        'column': blocked.column,
        'crossed': true,
        'notes': <String>[],
        'characterId': null,
      });
      expect(
        () => SavedCaseProgressCodec.fromJson(blockedData, c),
        throwsFormatException,
      );

      final duplicate = _jsonCopy(valid);
      final second = _freeCell(c, {first.solution});
      final third = _freeCell(c, {first.solution, second});
      final free = _freeCell(c, {first.solution, second, third});
      (duplicate['cells'] as List).add({
        'row': free.row,
        'column': free.column,
        'crossed': false,
        'notes': <String>[],
        'characterId': first.id,
      });
      expect(
        () => SavedCaseProgressCodec.fromJson(duplicate, c),
        throwsFormatException,
      );

      final stray = _jsonCopy(valid);
      (stray['feedback'] as List).add({
        'row': blocked.row,
        'column': blocked.column,
        'verdict': 'incorrect',
      });
      expect(
        () => SavedCaseProgressCodec.fromJson(stray, c),
        throwsFormatException,
      );
    },
  );

  test('a started false snapshot cannot carry edited board or timer', () {
    final c = _loadCase('car-repair');
    final data = _jsonCopy(_sample(c));
    data['attemptStarted'] = false;
    expect(
      () => SavedCaseProgressCodec.fromJson(data, c),
      throwsFormatException,
    );
  });

  test('fingerprint is stable and insensitive to irrelevant art metadata', () {
    final c = _loadCase('car-repair');
    final one = CaseContentFingerprint.forCase(c);
    expect(one, hasLength(16));
    expect(CaseContentFingerprint.forCase(c), one);
    final replacedArt = {
      for (final entry in c.objects.entries)
        entry.key: ObjectDefinition(
          name: entry.value.name,
          isOccupiable: entry.value.isOccupiable,
          imageAsset: 'assets/objects/replacement.svg',
        ),
    };
    final visualOnly = CaseDefinition(
      id: c.id,
      title: c.title,
      difficulty: c.difficulty,
      rows: c.rows,
      columns: c.columns,
      roomGrid: c.roomGrid,
      roomNames: c.roomNames,
      objectGrid: c.objectGrid,
      objects: replacedArt,
      generalClues: c.generalClues,
      objectTint: c.objectTint,
      characters: c.characters,
      murderId: c.murderId,
    );
    expect(CaseContentFingerprint.forCase(visualOnly), one);
  });
}
