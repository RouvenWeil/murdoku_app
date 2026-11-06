import '../../domain/case_definition.dart';
import 'saved_case_progress.dart';

/// A load may recover the last validated backup; this is surfaced to the UI.
class ProgressLoad {
  const ProgressLoad(this.progress, {this.recoveredFromBackup = false});

  final SavedCaseProgress? progress;
  final bool recoveredFromBackup;
}

/// Disk boundaries are asynchronous. The in-memory cache remains authoritative
/// for active gameplay and must not wait for a file write to update its state.
abstract class ProgressRepository {
  Future<ProgressLoad> load(CaseDefinition caseData);
  Future<void> save(SavedCaseProgress progress, CaseDefinition caseData);

  /// Explicit user-approved recovery; corrupted files are archived, not erased.
  Future<void> archiveDamaged(String caseId);
}
