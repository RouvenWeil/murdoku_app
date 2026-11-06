// Per-case, in-memory UI state; never persisted across app launches
class CluePinStore {
  CluePinStore();

  static final CluePinStore instance = CluePinStore();

  final Map<String, String> _pinnedByCase = {};

  String? pinnedFor(String caseId) => _pinnedByCase[caseId];

  String? toggle(String caseId, String clueId) {
    if (_pinnedByCase[caseId] == clueId) {
      _pinnedByCase.remove(caseId);
    } else {
      _pinnedByCase[caseId] = clueId;
    }
    return _pinnedByCase[caseId];
  }
}
