// Shared UI artwork paths; case-specific objects and portraits stay in case data
abstract final class MurdokuAssets {
  static const String logo = 'assets/ui/Murdoku-Logo.svg';
  static const String back = 'assets/ui/IconButton-Back.svg';
  static const String pinned = 'assets/ui/Pinned.svg';
  static const String unpinned = 'assets/ui/UnPinned.svg';
  static const String boardCross = 'assets/ui/Vector-Cross.svg';
  static const String crossTool = 'assets/ui/Vector-CrossOut.svg';
  static const String eraseTool = 'assets/ui/Vector-Eraser.svg';
  static const String undoTool = 'assets/ui/Vector-Undo.svg';
  // These are complete, grid-aligned boards: walls, objects, room names and
  // terrain are baked into the PNG. Only the player's actions go on top.
  // Using the same file for the board, minimap and preview avoids mismatches.
  static const Map<String, String> boardBackgrounds = {
    'car-repair': 'assets/boards/car-repair.png',
    'horse-with-no-name': 'assets/boards/horse-with-no-name.png',
    'river-crossing': 'assets/boards/river-crossing.png',
    'art-museum-heist': 'assets/boards/art-museum-heist.png',
    'golf-course': 'assets/boards/golf-course.png',
  };

  static String? boardBackground(String caseId) => boardBackgrounds[caseId];

  // The other three cases still need portraits. Don't pretend the generic
  // silhouette is final art; only these two have approved PNGs so far.
  static String? portrait(String caseId, String characterId) {
    if (caseId != 'car-repair' && caseId != 'horse-with-no-name') {
      return null;
    }
    if (!const {'A', 'B', 'C', 'D', 'E', 'V'}.contains(characterId)) {
      return null;
    }
    return 'assets/characters/$caseId/${characterId.toLowerCase()}.png';
  }
}
