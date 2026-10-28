import 'board_state.dart';
import 'character_definition.dart';
import 'object_definition.dart';
import 'solution_evaluation.dart';

class CaseDefinition {
  // Defensive copies keep case data unchanged after construction
  CaseDefinition({
    required this.id,
    required this.title,
    required this.difficulty,
    required this.rows,
    required this.columns,
    required List<List<int?>> roomGrid,
    required Map<int, String> roomNames,
    required List<List<String?>> objectGrid,
    required Map<String, ObjectDefinition> objects,
    required List<String> generalClues,
    this.objectTint,
    required List<CharacterDefinition> characters,
    required this.murderId,
  }) : roomGrid = List.unmodifiable(
         roomGrid.map((row) => List<int?>.unmodifiable(row)),
       ),
       roomNames = Map<int, String>.unmodifiable(roomNames),
       objectGrid = List.unmodifiable(
         objectGrid.map((row) => List<String?>.unmodifiable(row)),
       ),
       objects = Map<String, ObjectDefinition>.unmodifiable(objects),
       generalClues = List<String>.unmodifiable(generalClues),
       characters = List<CharacterDefinition>.unmodifiable(characters) {
    // Structural checks limited to data needed by the board and renderer
    if (rows <= 0 || columns <= 0) {
      throw const FormatException('Board dimensions must be positive.');
    }
    if (this.roomGrid.length != rows ||
        this.objectGrid.length != rows ||
        this.roomGrid.any((row) => row.length != columns) ||
        this.objectGrid.any((row) => row.length != columns)) {
      throw const FormatException('Case grids must match board dimensions.');
    }

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final roomId = this.roomGrid[row][column];
        final objectId = this.objectGrid[row][column];

        if (roomId != null && !this.roomNames.containsKey(roomId)) {
          throw FormatException('Unknown room ID $roomId at ($row,$column).');
        }
        if (objectId != null && !this.objects.containsKey(objectId)) {
          throw FormatException(
            'Unknown object ID $objectId at ($row,$column).',
          );
        }
        if (roomId == null && objectId != null) {
          throw FormatException('Object on absent cell ($row,$column).');
        }
      }
    }

    if (!this.characters.any((character) => character.id == 'V')) {
      throw const FormatException('Character V (victim) is required.');
    }
    if (murderId == 'V' ||
        !this.characters.any((character) => character.id == murderId)) {
      throw const FormatException('Murderer must be a known suspect.');
    }

    // One source of truth for character solutions
    // CaseSolution derived from the character records
    final positions = {
      for (final character in this.characters) character.id: character.solution,
    };
    if (positions.length != this.characters.length) {
      throw const FormatException('Duplicate character ID.');
    }
    solution = CaseSolution(
      rows: rows,
      columns: columns,
      characterPositions: positions,
    );
    // Invalid reference placements fail while reading the authored case
    for (final character in this.characters) {
      if (!canOccupy(character.solution)) {
        final position = character.solution;
        throw FormatException(
          'Character ${character.id} has a non-occupiable solution cell '
          '(${position.row},${position.column}).',
        );
      }
    }
  }

  final String id;
  final String title;
  final String difficulty;
  final int rows;
  final int columns;

  final List<List<int?>> roomGrid;
  final Map<int, String> roomNames;
  final List<List<String?>> objectGrid;
  final Map<String, ObjectDefinition> objects;
  final List<String> generalClues;
  final String? objectTint;
  final List<CharacterDefinition> characters;
  final String murderId;

  late final CaseSolution solution;

  bool canOccupy(CellPosition position) {
    if (position.row < 0 ||
        position.row >= rows ||
        position.column < 0 ||
        position.column >= columns) {
      throw RangeError('Cell is outside the case grid.');
    }

    // Static scene occupancy independent of player crosses and notes
    if (roomGrid[position.row][position.column] == null) return false;
    final objectId = objectGrid[position.row][position.column];
    return objectId == null || objects[objectId]!.isOccupiable;
  }

  factory CaseDefinition.fromJson(
    Map<String, dynamic> json, {
    required Map<String, ObjectDefinition> objectCatalog,
  }) {
    final rawRooms = json['roomGrid'] as List;
    final rawObjects = json['objectGrid'] as List;
    final rawRoomNames = Map<String, dynamic>.from(json['roomNames'] as Map);

    return CaseDefinition(
      id: json['id'] as String,
      title: json['title'] as String,
      difficulty: json['difficulty'] as String,
      rows: json['rows'] as int,
      columns: json['columns'] as int,
      roomGrid: [
        for (final row in rawRooms)
          [for (final room in (row as List)) room as int?],
      ],
      roomNames: {
        for (final entry in rawRoomNames.entries)
          int.parse(entry.key): entry.value as String,
      },
      // Case grid contains object IDs rather than duplicate definitions
      objectGrid: [
        for (final row in rawObjects)
          [for (final object in (row as List)) object as String?],
      ],
      // Shared definitions keep object occupancy consistent across cases
      objects: objectCatalog,
      objectTint: json['object-tint'] as String?,
      generalClues: [
        for (final clue in (json['general-clues'] as List)) clue as String,
      ],
      characters: [
        for (final character in (json['characters'] as List))
          CharacterDefinition.fromJson(
            Map<String, dynamic>.from(character as Map),
          ),
      ],
      murderId: json['murder-id'] as String,
    );
  }
}
