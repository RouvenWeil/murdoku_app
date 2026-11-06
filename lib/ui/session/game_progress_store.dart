import '../../domain/board_state.dart';
import '../../domain/solution_evaluation.dart';
import '../../session/game_session.dart';

// Same-process progress cache; persistent disk storage is a separate work item
class GameProgress {
  const GameProgress({
    required this.board,
    required this.feedbackByCell,
    required this.isSolved,
  });

  final BoardState board;
  final Map<CellPosition, PlacementVerdict> feedbackByCell;
  final bool isSolved;
}

class GameProgressStore {
  GameProgressStore();

  static final GameProgressStore instance = GameProgressStore();

  final Map<String, GameProgress> _progress = {};

  GameProgress? read(String caseId) => _progress[caseId];

  void save(String caseId, GameSession session) {
    _progress[caseId] = GameProgress(
      board: session.board,
      feedbackByCell: Map.unmodifiable(session.feedbackByCell),
      isSolved: session.isSolved,
    );
  }

  void clear(String caseId) => _progress.remove(caseId);
}
