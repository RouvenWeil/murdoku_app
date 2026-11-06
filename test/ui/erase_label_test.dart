import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/domain/case_definition.dart';
import 'package:murdoku_app/domain/character_definition.dart';
import 'package:murdoku_app/domain/object_definition.dart';
import 'package:murdoku_app/ui/widgets/murdoku_buttons.dart';
import 'package:murdoku_app/ui/widgets/tool_panel_stub.dart';

void main() {
  testWidgets('Erase label has no hold caption; clear gesture stays wired', (
    tester,
  ) async {
    final caseData = CaseDefinition(
      id: 'tool-label-test',
      title: 'Label fixture',
      difficulty: 'easy',
      rows: 2,
      columns: 2,
      roomGrid: [
        [0, 0],
        [0, 0],
      ],
      roomNames: const {0: 'Room'},
      objectGrid: [
        [null, null],
        [null, null],
      ],
      objects: const <String, ObjectDefinition>{},
      generalClues: const [],
      characters: const [
        CharacterDefinition(
          id: 'A',
          name: 'A',
          clue: 'A',
          solution: (row: 0, column: 0),
        ),
        CharacterDefinition(
          id: 'V',
          name: 'V',
          clue: 'Victim',
          solution: (row: 1, column: 1),
        ),
      ],
      murderId: 'A',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 210,
            height: 500,
            child: ToolPanelStub(
              caseData: caseData,
              showMinimap: false,
              arrangement: ToolPanelArrangement.expanded,
              minimapWidth: 0,
              minimapHeight: 0,
              onClearAll: () {},
            ),
          ),
        ),
      ),
    );
    final erase = tester.widget<MurdokuToolButton>(
      find.byKey(const ValueKey('tool-erase')),
    );
    expect(erase.label, 'Erase Cell');
    expect(erase.subtitle, isNull);
    expect(find.textContaining('hold to reset'), findsNothing);
    expect(find.byKey(const ValueKey('hold-clear-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
