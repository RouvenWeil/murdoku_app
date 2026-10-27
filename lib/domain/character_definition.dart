import 'board_state.dart';

class CharacterDefinition {
  const CharacterDefinition({
    required this.id,
    required this.name,
    required this.clue,
    required this.solution,
    this.imageAsset,
  });

  final String id;
  final String name;
  final String clue;
  final String? imageAsset;
  final CellPosition solution;

  factory CharacterDefinition.fromJson(Map<String, dynamic> json) {
    final position = json['solution'];

    // JSON coordinates follow row first array indexing
    if (position is! List ||
        position.length != 2 ||
        position[0] is! int ||
        position[1] is! int) {
      throw const FormatException('Character solution must be [row, column].');
    }

    return CharacterDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      clue: json['clue'] as String,
      imageAsset: json['imageAsset'] as String?,
      solution: (row: position[0] as int, column: position[1] as int),
    );
  }
}
