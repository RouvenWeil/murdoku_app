// ignore_for_file: prefer_initializing_formals
// The public repository argument is intentionally stored in a private field.

import 'package:flutter/foundation.dart';

import '../../data/progress/progress_repository.dart';
import '../../data/progress/saved_case_progress.dart';
import '../../domain/board_state.dart';
import '../../domain/case_definition.dart';
import '../../domain/solution_evaluation.dart';
import '../../session/game_session.dart';

/// Live progress is authoritative even while a disk write is pending/failed.
class GameProgress {
  const GameProgress({
    required this.board,
    required this.feedbackByCell,
    required this.isSolved,
    this.attemptStarted = true,
    this.elapsed = Duration.zero,
  });

  final BoardState board;
  final Map<CellPosition, PlacementVerdict> feedbackByCell;
  final bool isSolved;
  final bool attemptStarted;
  final Duration elapsed;

  static GameProgress fromSaved(SavedCaseProgress data) => GameProgress(
    board: data.board,
    feedbackByCell: data.feedbackByCell,
    isSolved: data.isSolved,
    attemptStarted: data.attemptStarted,
    elapsed: data.elapsed,
  );
}

enum ProgressLoadStatus { notLoaded, loading, ready, recovered, failed }

class GameProgressStore extends ChangeNotifier {
  GameProgressStore({ProgressRepository? repository})
    : _repository = repository;

  static final GameProgressStore instance = GameProgressStore();

  ProgressRepository? _repository;
  final Map<String, GameProgress> _progress = {};
  final Map<String, ProgressLoadStatus> _statuses = {};
  final Map<String, Object> _loadErrors = {};
  final Map<String, Object> _saveErrors = {};
  final Map<String, Future<void>> _loads = {};
  final Map<String, _QueuedWrite> _pending = {};
  final Map<String, Future<void>> _writers = {};
  final Map<String, int> _revisions = {};

  bool get hasPersistence => _repository != null;

  /// Called once by main(), not by widget tests using the default in-memory store.
  void enablePersistence(ProgressRepository repository) {
    if (_repository != null) {
      throw StateError('Persistence already configured.');
    }
    _repository = repository;
  }

  GameProgress? read(String caseId) => _progress[caseId];

  ProgressLoadStatus status(String caseId) => !hasPersistence
      ? ProgressLoadStatus.ready
      : (_statuses[caseId] ?? ProgressLoadStatus.notLoaded);

  Object? loadError(String caseId) => _loadErrors[caseId];
  Object? saveError(String caseId) => _saveErrors[caseId];
  bool hasUnsavedChanges(String caseId) =>
      _pending.containsKey(caseId) ||
      _saveErrors.containsKey(caseId) ||
      _writers.containsKey(caseId);

  Future<void> ensureLoaded(CaseDefinition caseData) {
    if (!hasPersistence ||
        status(caseData.id) == ProgressLoadStatus.ready ||
        status(caseData.id) == ProgressLoadStatus.recovered) {
      return Future<void>.value();
    }
    return _loads.putIfAbsent(caseData.id, () => _hydrate(caseData));
  }

  Future<void> _hydrate(CaseDefinition caseData) async {
    final id = caseData.id;
    _statuses[id] = ProgressLoadStatus.loading;
    notifyListeners();
    try {
      final result = await _repository!.load(caseData);
      // Never overwrite player edits made since loading began.
      if (!_progress.containsKey(id) && result.progress != null) {
        _progress[id] = GameProgress.fromSaved(result.progress!);
      }
      _loadErrors.remove(id);
      _statuses[id] = result.recoveredFromBackup
          ? ProgressLoadStatus.recovered
          : ProgressLoadStatus.ready;
    } catch (error) {
      _loadErrors[id] = error;
      _statuses[id] = ProgressLoadStatus.failed;
    } finally {
      _loads.remove(id);
      notifyListeners();
    }
  }

  Future<void> retryLoad(CaseDefinition caseData) {
    _statuses[caseData.id] = ProgressLoadStatus.notLoaded;
    return ensureLoaded(caseData);
  }

  /// Explicitly archive damaged records, then start a fresh attempt.
  Future<void> startFreshAfterFailure(CaseDefinition caseData) async {
    if (status(caseData.id) != ProgressLoadStatus.failed) {
      throw StateError('No damaged progress requires recovery.');
    }
    await _repository!.archiveDamaged(caseData.id);
    _loadErrors.remove(caseData.id);
    _statuses[caseData.id] = ProgressLoadStatus.ready;
    _progress.remove(caseData.id);
    notifyListeners();
  }

  /// Existing synchronous API remains for in-memory widget fixtures.
  void save(
    String caseId,
    GameSession session, {
    CaseDefinition? caseData,
    Duration? elapsed,
    bool attemptStarted = true,
  }) {
    final previous = _progress[caseId];
    final value = GameProgress(
      board: session.board,
      feedbackByCell: Map.unmodifiable(session.feedbackByCell),
      isSolved: session.isSolved,
      attemptStarted: attemptStarted,
      elapsed: elapsed ?? previous?.elapsed ?? Duration.zero,
    );
    _progress[caseId] = value;
    if (caseData != null) _queue(caseData, value);
    notifyListeners();
  }

  /// Replay and unfinished reset replace the attempt rather than deleting a
  /// durable save, preventing queued older writes resurrecting prior progress.
  void replaceAttempt(
    CaseDefinition caseData,
    GameSession session, {
    required Duration elapsed,
    required bool attemptStarted,
  }) => save(
    caseData.id,
    session,
    caseData: caseData,
    elapsed: elapsed,
    attemptStarted: attemptStarted,
  );

  void clear(String caseId) {
    if (hasPersistence) {
      throw StateError('Use replaceAttempt for a durable reset.');
    }
    _progress.remove(caseId);
    notifyListeners();
  }

  void _queue(CaseDefinition caseData, GameProgress value) {
    if (_repository == null) return;
    final snapshot = SavedCaseProgress.forCase(
      caseData: caseData,
      board: value.board,
      feedbackByCell: value.feedbackByCell,
      isSolved: value.isSolved,
      attemptStarted: value.attemptStarted,
      elapsed: value.elapsed,
    );
    final id = caseData.id;
    final revision = (_revisions[id] ?? 0) + 1;
    _revisions[id] = revision;
    _pending[id] = _QueuedWrite(caseData, snapshot, revision);
    _saveErrors.remove(id);
    _writers.putIfAbsent(id, () => _drain(id));
  }

  Future<void> _drain(String caseId) async {
    try {
      while (true) {
        final next = _pending.remove(caseId);
        if (next == null) break;
        try {
          await _repository!.save(next.snapshot, next.caseData);
          // An older completion must never clear a newer failure or status.
          if (_revisions[caseId] == next.revision) {
            _saveErrors.remove(caseId);
            if (_statuses[caseId] == ProgressLoadStatus.recovered) {
              _statuses[caseId] = ProgressLoadStatus.ready;
            }
          }
        } catch (error) {
          _saveErrors[caseId] = error;
          // Retain the latest live state (not an outdated failed snapshot).
          _pending[caseId] ??= _QueuedWrite(
            next.caseData,
            SavedCaseProgress.forCase(
              caseData: next.caseData,
              board: _progress[caseId]!.board,
              feedbackByCell: _progress[caseId]!.feedbackByCell,
              isSolved: _progress[caseId]!.isSolved,
              attemptStarted: _progress[caseId]!.attemptStarted,
              elapsed: _progress[caseId]!.elapsed,
            ),
            _revisions[caseId]!,
          );
          break; // retry is explicit, not an infinite disk-error loop
        }
      }
    } finally {
      _writers.remove(caseId);
      notifyListeners();
    }
  }

  Future<void> retrySave(String caseId) async {
    if (_pending.containsKey(caseId)) {
      _saveErrors.remove(caseId);
      _writers.putIfAbsent(caseId, () => _drain(caseId));
      await _writers[caseId]!;
    }
  }

  /// Deterministic drain barrier for tests/navigation; never drops live edits.
  Future<void> waitForWrites(String caseId) async {
    while (_writers.containsKey(caseId)) {
      await _writers[caseId]!;
    }
  }
}

class _QueuedWrite {
  const _QueuedWrite(this.caseData, this.snapshot, this.revision);
  final CaseDefinition caseData;
  final SavedCaseProgress snapshot;
  final int revision;
}
