import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/data/progress/file_progress_repository.dart';
import 'package:murdoku_app/data/progress/saved_case_progress.dart';
import 'package:murdoku_app/domain/board_state.dart';
import 'package:murdoku_app/domain/solution_evaluation.dart';
import 'package:murdoku_app/domain/case_definition.dart';
import 'package:murdoku_app/domain/object_definition.dart';
import 'package:murdoku_app/session/game_session.dart';
import 'package:murdoku_app/ui/session/game_progress_store.dart';

CaseDefinition fixture(String id) {
  final catalog = jsonDecode(
    File('assets/object-catalog.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final parsed = {
    for (final item in catalog.entries)
      item.key: ObjectDefinition.fromJson(
        Map<String, dynamic>.from(item.value as Map),
      ),
  };
  final json = jsonDecode(
    File('assets/cases/$id.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return CaseDefinition.fromJson(json, objectCatalog: parsed);
}

SavedCaseProgress snapshot(CaseDefinition c, {int seconds = 1}) {
  return SavedCaseProgress.forCase(
    caseData: c,
    board: BoardState.empty(c.rows, c.columns),
    feedbackByCell: const {},
    isSolved: false,
    attemptStarted: true,
    elapsed: Duration(seconds: seconds),
  );
}

void main() {
  late Directory directory;
  setUp(
    () async =>
        directory = await Directory.systemTemp.createTemp('murdoku-wp04-'),
  );
  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('case-isolated saves survive repository re-instantiation', () async {
    final a = fixture('car-repair');
    final b = fixture('river-crossing');
    final file = FileProgressRepository(directory: () async => directory);
    await file.save(snapshot(a, seconds: 8), a);
    await file.save(snapshot(b, seconds: 19), b);
    final restarted = FileProgressRepository(directory: () async => directory);
    expect(
      (await restarted.load(a)).progress!.elapsed,
      const Duration(seconds: 8),
    );
    expect(
      (await restarted.load(b)).progress!.elapsed,
      const Duration(seconds: 19),
    );
    expect((await restarted.load(fixture('golf-course'))).progress, isNull);
  });

  test('corrupt primary falls back to verified last-good backup', () async {
    final c = fixture('car-repair');
    final file = FileProgressRepository(directory: () async => directory);
    await file.save(snapshot(c, seconds: 12), c);
    await file.save(snapshot(c, seconds: 13), c);
    await File('${directory.path}/car-repair.json').writeAsString('{invalid');
    final loaded = await file.load(c);
    expect(loaded.recoveredFromBackup, isTrue);
    expect(loaded.progress!.elapsed, const Duration(seconds: 12));
  });

  test(
    'interrupted first write can recover its flushed temporary file',
    () async {
      final c = fixture('car-repair');
      final interrupted = FileProgressRepository(
        directory: () async => directory,
        beforeReplace: () async => throw const FileSystemException('Power cut'),
      );
      await expectLater(
        interrupted.save(snapshot(c, seconds: 9), c),
        throwsA(isA<FileSystemException>()),
      );
      final restarted = FileProgressRepository(
        directory: () async => directory,
      );
      final loaded = await restarted.load(c);
      expect(loaded.recoveredFromBackup, isTrue);
      expect(loaded.progress!.elapsed, const Duration(seconds: 9));
    },
  );

  test(
    'corrupt primary plus backup produces explicit failure, not a new game',
    () async {
      final c = fixture('car-repair');
      final file = FileProgressRepository(directory: () async => directory);
      await file.save(snapshot(c, seconds: 1), c);
      await file.save(snapshot(c, seconds: 2), c);
      await File('${directory.path}/car-repair.json').writeAsString('bad');
      await File('${directory.path}/car-repair.bak').writeAsString('bad');
      await expectLater(file.load(c), throwsFormatException);
      await file.archiveDamaged(c.id);
      expect((await file.load(c)).progress, isNull);
      expect(
        directory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.contains('.damaged.'))
            .length,
        greaterThanOrEqualTo(2),
      );
    },
  );

  test(
    'interrupted replacement preserves old save and live unsaved state',
    () async {
      final c = fixture('car-repair');
      final good = FileProgressRepository(directory: () async => directory);
      await good.save(snapshot(c, seconds: 10), c);
      final failing = FileProgressRepository(
        directory: () async => directory,
        beforeReplace: () async => throw const FileSystemException('No space'),
      );
      final store = GameProgressStore(repository: failing);
      await store.ensureLoaded(c);
      final game = GameSession.fromCase(c);
      store.save(c.id, game, caseData: c, elapsed: const Duration(seconds: 15));
      await store.waitForWrites(c.id);
      expect(store.read(c.id)!.elapsed, const Duration(seconds: 15));
      expect(store.saveError(c.id), isNotNull);
      expect(
        (await good.load(c)).progress!.elapsed,
        const Duration(seconds: 10),
      );
    },
  );

  test(
    'incorrect Submit feedback and elapsed time survive cold restoration',
    () async {
      final c = fixture('car-repair');
      final used = {for (final person in c.characters) person.solution};
      CellPosition? alternative;
      for (var row = 0; row < c.rows && alternative == null; row++) {
        for (var col = 0; col < c.columns; col++) {
          final p = (row: row, column: col);
          if (c.canOccupy(p) && !used.contains(p)) {
            alternative = p;
            break;
          }
        }
      }
      expect(alternative, isNotNull);
      var board = BoardState.empty(c.rows, c.columns);
      for (var i = 0; i < c.characters.length; i++) {
        final person = c.characters[i];
        board = board.withCell(
          i == 0 ? alternative! : person.solution,
          CellState(characterId: person.id),
        );
      }
      final session = GameSession.fromCase(c, restoredBoard: board);
      expect(session.canSubmit, isTrue);
      final result = session.submit();
      expect(result.solved, isFalse);
      final repo = FileProgressRepository(directory: () async => directory);
      final writer = GameProgressStore(repository: repo);
      await writer.ensureLoaded(c);
      writer.save(
        c.id,
        session,
        caseData: c,
        elapsed: const Duration(minutes: 5),
      );
      await writer.waitForWrites(c.id);
      final reader = GameProgressStore(
        repository: FileProgressRepository(directory: () async => directory),
      );
      await reader.ensureLoaded(c);
      final restored = reader.read(c.id)!;
      expect(restored.elapsed, const Duration(minutes: 5));
      expect(restored.isSolved, isFalse);
      expect(restored.feedbackByCell, result.feedbackByCell);
      expect(
        restored.feedbackByCell.values,
        contains(PlacementVerdict.incorrect),
      );
      final continuing = GameSession.fromCase(
        c,
        restoredBoard: restored.board,
        restoredFeedback: restored.feedbackByCell,
        previouslySolved: restored.isSolved,
      );
      expect(continuing.feedbackByCell, result.feedbackByCell);
      expect(continuing.isSolved, isFalse);
    },
  );

  test('failed write can be retried without losing the live state', () async {
    final c = fixture('car-repair');
    var denyWrite = true;
    final repository = FileProgressRepository(
      directory: () async => directory,
      beforeReplace: () async {
        if (denyWrite) throw const FileSystemException('Storage unavailable');
      },
    );
    final store = GameProgressStore(repository: repository);
    await store.ensureLoaded(c);
    final game = GameSession.fromCase(c);
    expect(
      game.addNote(c.characters.first.solution, c.characters.first.id),
      isTrue,
    );
    store.save(c.id, game, caseData: c, elapsed: const Duration(seconds: 3));
    await store.waitForWrites(c.id);
    expect(store.saveError(c.id), isNotNull);
    expect(
      store.read(c.id)!.board.cellAt(c.characters.first.solution).notes,
      contains(c.characters.first.id),
    );
    denyWrite = false;
    await store.retrySave(c.id);
    expect(store.saveError(c.id), isNull);
    expect(
      (await repository.load(c)).progress!.board
          .cellAt(c.characters.first.solution)
          .notes,
      contains(c.characters.first.id),
    );
  });

  test(
    'a damaged case remains isolated and requires explicit archive',
    () async {
      final damaged = fixture('car-repair');
      final healthy = fixture('river-crossing');
      final repo = FileProgressRepository(directory: () async => directory);
      await repo.save(snapshot(healthy, seconds: 25), healthy);
      await File('${directory.path}/car-repair.json').writeAsString('bad');
      final store = GameProgressStore(repository: repo);
      await Future.wait([
        store.ensureLoaded(damaged),
        store.ensureLoaded(healthy),
      ]);
      expect(store.status(damaged.id), ProgressLoadStatus.failed);
      expect(store.read(damaged.id), isNull);
      expect(store.loadError(damaged.id), isNotNull);
      expect(store.status(healthy.id), ProgressLoadStatus.ready);
      expect(store.read(healthy.id)!.elapsed, const Duration(seconds: 25));
      await store.startFreshAfterFailure(damaged);
      expect(store.status(damaged.id), ProgressLoadStatus.ready);
      expect(store.read(damaged.id), isNull);
      expect((await repo.load(damaged)).progress, isNull);
    },
  );

  test('rapid saves and replay cannot resurrect older progress', () async {
    final c = fixture('car-repair');
    final repo = FileProgressRepository(directory: () async => directory);
    final store = GameProgressStore(repository: repo);
    await store.ensureLoaded(c);
    final game = GameSession.fromCase(c);
    expect(
      game.addNote(c.characters.first.solution, c.characters.first.id),
      isTrue,
    );
    store.save(c.id, game, caseData: c, elapsed: const Duration(seconds: 7));
    expect(
      game.addNote(c.characters.last.solution, c.characters.last.id),
      isTrue,
    );
    store.save(c.id, game, caseData: c, elapsed: const Duration(seconds: 8));
    final replay = GameSession.fromCase(c);
    store.replaceAttempt(
      c,
      replay,
      elapsed: Duration.zero,
      attemptStarted: false,
    );
    await store.waitForWrites(c.id);
    final latest = (await repo.load(c)).progress!;
    expect(latest.attemptStarted, isFalse);
    expect(latest.elapsed, Duration.zero);
    expect(latest.isSolved, isFalse);
    for (var row = 0; row < c.rows; row++) {
      for (var column = 0; column < c.columns; column++) {
        expect(latest.board.cellAt((row: row, column: column)).isEmpty, isTrue);
      }
    }
  });
}
