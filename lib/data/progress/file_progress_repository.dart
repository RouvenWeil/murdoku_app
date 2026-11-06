// ignore_for_file: prefer_initializing_formals
// The public directory argument is intentionally stored in a private field.

import 'dart:io';

import '../../domain/case_definition.dart';
import 'progress_repository.dart';
import 'saved_case_progress.dart';
import 'saved_case_progress_codec.dart';

/// App-private, case-scoped local files. Tests inject a temporary Directory.
/// Each save validates a flushed temporary file before replacing the primary.
/// A separately verified last-good backup is retained for crash recovery.
class FileProgressRepository implements ProgressRepository {
  FileProgressRepository({
    required Future<Directory> Function() directory,
    this.beforeReplace,
  }) : _directory = directory;

  final Future<Directory> Function() _directory;

  /// Test hook to simulate a failure after flushing the temporary save.
  final Future<void> Function()? beforeReplace;
  Future<Directory>? _cachedDirectory;

  Future<Directory> _root() async {
    try {
      final dir = await (_cachedDirectory ??= _directory());
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    } catch (_) {
      // A transient platform/filesystem failure must be retryable.
      _cachedDirectory = null;
      rethrow;
    }
  }

  String _safeName(String id) {
    // A case ID is never used directly as an arbitrary filesystem path.
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      throw const FormatException('Unsafe progress case ID.');
    }
    return id;
  }

  Future<File> _file(String id, String suffix) async {
    final root = await _root();
    return File('${root.path}${Platform.pathSeparator}${_safeName(id)}$suffix');
  }

  Future<SavedCaseProgress?> _tryValidated(
    File file,
    CaseDefinition caseData,
  ) async {
    if (!await file.exists()) return null;
    return SavedCaseProgressCodec.decode(await file.readAsString(), caseData);
  }

  @override
  Future<ProgressLoad> load(CaseDefinition caseData) async {
    final primary = await _file(caseData.id, '.json');
    final backup = await _file(caseData.id, '.bak');
    final temporary = await _file(caseData.id, '.tmp');
    final errors = <Object>[];
    if (await primary.exists()) {
      try {
        return ProgressLoad(await _tryValidated(primary, caseData));
      } catch (error) {
        errors.add(error);
      }
    }
    // A previously committed backup wins over an uncommitted temporary file.
    for (final candidate in [backup, temporary]) {
      if (!await candidate.exists()) continue;
      try {
        return ProgressLoad(
          await _tryValidated(candidate, caseData),
          recoveredFromBackup: true,
        );
      } catch (error) {
        errors.add(error);
      }
    }
    if (errors.isNotEmpty) {
      throw FormatException(
        'Progress has no valid recoverable copy: '
        '${errors.join('; ')}',
      );
    }
    return const ProgressLoad(null);
  }

  Future<void> _replace(File source, File target) async {
    try {
      await source.rename(target.path);
    } on FileSystemException {
      // Windows rename refuses an existing target. This fallback only runs
      // after a validated last-good backup has been created, where applicable.
      if (await target.exists()) await target.delete();
      await source.rename(target.path);
    }
  }

  @override
  Future<void> save(SavedCaseProgress progress, CaseDefinition caseData) async {
    progress.validateAgainst(caseData);
    final primary = await _file(progress.caseId, '.json');
    final temporary = await _file(progress.caseId, '.tmp');
    final backup = await _file(progress.caseId, '.bak');
    final backupTemp = await _file(progress.caseId, '.bak.tmp');
    await temporary.writeAsString(
      SavedCaseProgressCodec.encode(progress),
      flush: true,
    );
    await _tryValidated(temporary, caseData);
    if (beforeReplace != null) await beforeReplace!();

    // A damaged primary must never overwrite a known-good backup.
    if (await primary.exists()) {
      try {
        await _tryValidated(primary, caseData);
        await primary.copy(backupTemp.path);
        await _tryValidated(backupTemp, caseData);
        await _replace(backupTemp, backup);
      } on FormatException {
        // Preserve last-good backup and let the validated new save replace
        // a corrupt primary only after an explicit recovery path is chosen.
        if (await backupTemp.exists()) await backupTemp.delete();
      }
    }
    await _replace(temporary, primary);
  }

  @override
  Future<void> archiveDamaged(String caseId) async {
    // Archive files rather than silently deleting potentially recoverable data.
    final stamp = DateTime.now().microsecondsSinceEpoch;
    for (final suffix in ['.json', '.bak', '.tmp', '.bak.tmp']) {
      final file = await _file(caseId, suffix);
      if (await file.exists()) {
        await file.rename('${file.path}.damaged.$stamp');
      }
    }
  }
}
