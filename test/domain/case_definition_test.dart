import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/domain/case_definition.dart';
import 'package:murdoku_app/domain/character_definition.dart';
import 'package:murdoku_app/domain/object_definition.dart';

// Small fixture independent of the authored case data
Map<String, dynamic> caseJson() => {
      'id': 'test-case',
      'title': 'Test Case',
      'difficulty': 'test',
      'rows': 2,
      'columns': 2,
      'roomGrid': <List<int?>>[
        [0, 0],
        [1, 1],
      ],
      'roomNames': {'0': 'Room A', '1': 'Room B'},
      'objectGrid': <List<String?>>[
        [null, 'chair'],
        [null, null],
      ],
      'object-tint': null,
      'general-clues': <String>['General clue'],
      'characters': [
        {
          'id': 'A',
          'name': 'Alex',
          'clue': 'A simple clue.',
          'imageAsset': null,
          'solution': [0, 1],
        },
        {
          'id': 'V',
          'name': 'Victim',
          'clue': 'The victim.',
          'imageAsset': null,
          'solution': [1, 0],
        },
      ],
      'murder-id': 'A',
    };

Map<String, ObjectDefinition> testCatalog() => {
      'chair': const ObjectDefinition(
        name: 'Chair',
        isOccupiable: true,
      ),
    };

CaseDefinition readCase(Map<String, dynamic> json) => CaseDefinition.fromJson(
      json,
      objectCatalog: testCatalog(),
    );

void main() {
  group('WP-02A - Case data models', () {
    test('character decodes row-first coordinates and clue text', () {
      final character = CharacterDefinition.fromJson({
        'id': 'A',
        'name': 'Alex',
        'clue': 'A simple clue.',
        'imageAsset': null,
        'solution': [1, 0],
      });

      expect(character.id, 'A');
      expect(character.clue, 'A simple clue.');
      expect(character.solution, (row: 1, column: 0));
    });

    test('V stays a regular character ID; images are optional', () {
      final character = CharacterDefinition.fromJson({
        'id': 'V',
        'name': 'Victim',
        'clue': '',
        'imageAsset': null,
        'solution': [0, 0],
      });

      expect(character.id, 'V');
      expect(character.imageAsset, isNull);
    });

    test('malformed character coordinates are rejected', () {
      expect(
        () => CharacterDefinition.fromJson({
          'id': 'A',
          'name': 'Alex',
          'clue': '',
          'solution': [1],
          'imageAsset': null,
        }),
        throwsFormatException,
      );
    });

    test('object occupancy is a single boolean', () {
      final object = ObjectDefinition.fromJson({
        'name': 'Shelf',
        'isOccupiable': false,
        'imageAsset': null,
      });

      expect(object.isOccupiable, isFalse);
    });

    test('case builds immutable grids and a derived solution', () {
      final decoded = jsonDecode(jsonEncode(caseJson())) as Map<String, dynamic>;
      final data = readCase(decoded);

      expect(data.roomGrid[1][0], 1);
      expect(data.roomNames[1], 'Room B');
      expect(data.generalClues, ['General clue']);
      expect(data.objectTint, isNull);
      expect(data.murderId, 'A');
      expect(data.solution.characterPositions['A'], (row: 0, column: 1));
      expect(data.solution.characterPositions['V'], (row: 1, column: 0));
      expect(() => data.roomGrid[0][0] = 2, throwsUnsupportedError);
      expect(() => data.characters.clear(), throwsUnsupportedError);
      expect(() => data.objects.clear(), throwsUnsupportedError);
    });

    test('case tint is loaded without changing shared object properties', () {
      final json = caseJson();
      json['object-tint'] = 'purple';
      final data = readCase(json);

      expect(data.objectTint, 'purple');
      expect(data.objects['chair']!.isOccupiable, isTrue);
    });

    test('empty and occupiable object cells allow placement', () {
      final data = readCase(caseJson());

      expect(data.canOccupy((row: 0, column: 0)), isTrue);
      expect(data.canOccupy((row: 0, column: 1)), isTrue);
    });

    test('a blocking object prevents occupancy', () {
      final catalog = {
        'chair': const ObjectDefinition(name: 'Chair', isOccupiable: false),
      };
      final data = CaseDefinition.fromJson(
        caseJson(),
        objectCatalog: catalog,
      );

      expect(data.canOccupy((row: 0, column: 1)), isFalse);
    });

    test('an absent room cell is not occupiable', () {
      final json = caseJson();
      (json['roomGrid'] as List)[0][0] = null;
      final data = readCase(json);

      expect(data.canOccupy((row: 0, column: 0)), isFalse);
    });

    test('unknown catalog object IDs are rejected', () {
      final json = caseJson();
      (json['objectGrid'] as List)[0][0] = 'unknown';

      expect(() => readCase(json), throwsFormatException);
    });

    test('mismatched grid dimensions are rejected', () {
      final json = caseJson();
      json['columns'] = 3;

      expect(() => readCase(json), throwsFormatException);
    });

    test('duplicate solution cells are rejected by CaseSolution', () {
      final json = caseJson();
      ((json['characters'] as List)[1] as Map)['solution'] = [0, 1];

      expect(() => readCase(json), throwsArgumentError);
    });

    test('general clues must be a list, even when empty', () {
      final json = caseJson();
      json['general-clues'] = <String>[];

      expect(readCase(json).generalClues, isEmpty);
      json['general-clues'] = null;
      expect(() => readCase(json), throwsA(isA<TypeError>()));
    });

    test('murderer must be one of the suspects', () {
      final json = caseJson();
      json['murder-id'] = 'V';

      expect(() => readCase(json), throwsFormatException);
    });

    test('the victim ID is required', () {
      final json = caseJson();
      (json['characters'] as List).removeLast();

      expect(() => readCase(json), throwsFormatException);
    });
  });
}
