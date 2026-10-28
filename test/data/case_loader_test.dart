import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/data/case_loader.dart';
import 'package:murdoku_app/session/game_session.dart';

// Case IDs match the JSON asset filenames
const caseIds = [
  'car-repair',
  'horse-with-no-name',
  'river-crossing',
  'the-art-museum-heist',
  'golf-course',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Five case assets and shared object catalog', () {
    test('Car Repair retains the confirmed scene and solution', () async {
      final data = await CaseLoader.load('car-repair');

      expect(data.id, 'car-repair');
      expect(data.title, 'Car Repair');
      expect(data.difficulty, 'very-easy');
      expect(data.rows, 6);
      expect(data.columns, 6);
      expect(data.characters.length, 6);
      expect(data.roomNames.length, 4);
      expect(data.generalClues, isEmpty);
      expect(data.objectTint, isNull);
      expect(data.murderId, 'C');
      expect(data.solution.characterPositions['V'], (row: 1, column: 0));
    });

    test('Car Repair object references use the current catalog IDs', () async {
      final data = await CaseLoader.load('car-repair');

      expect(data.roomGrid[0][3], 1);
      expect(data.roomNames[1], 'Waiting Area');
      expect(data.objectGrid[0][3], 'tv');
      expect(data.canOccupy((row: 0, column: 3)), isFalse);
      expect(data.objectGrid[1][2], 'table-left-up');
      expect(data.objects['table-left-up']!.name, 'Table');
      expect(data.canOccupy((row: 1, column: 2)), isFalse);
      expect(data.objectGrid[5][4], 'car-left-left');
      expect(data.canOccupy((row: 5, column: 4)), isTrue);
    });

    test(
      'the selected cases load with correct dimensions and metadata',
      () async {
        final expected = <String, (int, int, int, String?)>{
          'car-repair': (6, 6, 6, null),
          'horse-with-no-name': (6, 6, 6, null),
          'river-crossing': (10, 9, 9, 'red'),
          'the-art-museum-heist': (9, 9, 9, 'purple'),
          'golf-course': (16, 16, 16, 'teal'),
        };
        for (final entry in expected.entries) {
          final data = await CaseLoader.load(entry.key);
          final (rows, columns, characterCount, tint) = entry.value;
          expect(data.id, entry.key);
          expect(data.rows, rows);
          expect(data.columns, columns);
          expect(data.characters.length, characterCount);
          expect(data.objectTint, tint);
        }
      },
    );

    test('the horse case keeps absent room cells', () async {
      final data = await CaseLoader.load('horse-with-no-name');

      expect(data.roomGrid[0][0], isNull);
      expect(data.roomGrid[0][5], isNull);
      expect(data.roomGrid[5][5], isNull);
      expect(data.canOccupy((row: 0, column: 0)), isFalse);
    });

    test('River Crossing is rectangular and can have an empty row', () async {
      final data = await CaseLoader.load('river-crossing');
      final rows = {
        for (final character in data.characters) character.solution.row,
      };

      expect(data.rows, 10);
      expect(data.columns, 9);
      expect(rows.length, 9);
      expect(data.generalClues, hasLength(3));
    });

    test(
      'all case objects are known and every solution is occupiable',
      () async {
        for (final caseId in caseIds) {
          final data = await CaseLoader.load(caseId);
          for (final row in data.objectGrid) {
            for (final objectId in row) {
              if (objectId != null) {
                expect(
                  data.objects.containsKey(objectId),
                  isTrue,
                  reason: '$caseId references $objectId',
                );
              }
            }
          }
          for (final character in data.characters) {
            expect(
              data.canOccupy(character.solution),
              isTrue,
              reason: '$caseId: ${character.id} on a blocked cell',
            );
          }
        }
      },
    );

    test(
      'all character solutions use distinct positions rows and columns',
      () async {
        for (final caseId in caseIds) {
          final data = await CaseLoader.load(caseId);
          final positions = data.solution.characterPositions.values;
          expect(positions.toSet().length, data.characters.length);
          expect(
            positions.map((p) => p.row).toSet().length,
            data.characters.length,
          );
          expect(
            positions.map((p) => p.column).toSet().length,
            data.characters.length,
          );
        }
      },
    );

    test('all five solutions can complete a GameSession', () async {
      for (final caseId in caseIds) {
        final data = await CaseLoader.load(caseId);
        final game = GameSession.fromCase(data);
        for (final character in data.characters) {
          expect(
            game.placeCharacter(character.solution, character.id),
            isTrue,
            reason: '$caseId: cannot place ${character.id}',
          );
        }
        expect(game.canSubmit, isTrue, reason: caseId);
        expect(game.isSolved, isFalse, reason: caseId);
        expect(game.submit().solved, isTrue, reason: caseId);
        expect(game.isSolved, isTrue, reason: caseId);
        expect(game.canUndo, isFalse, reason: caseId);
      }
    });
  });
}
