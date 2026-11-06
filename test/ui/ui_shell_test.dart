import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/domain/case_definition.dart';
import 'package:murdoku_app/domain/character_definition.dart';
import 'package:murdoku_app/domain/object_definition.dart';
import 'package:murdoku_app/ui/murdoku_app.dart';
import 'package:murdoku_app/ui/screens/case_screen.dart';
import 'package:murdoku_app/ui/widgets/board_viewport_stub.dart';
import 'package:murdoku_app/ui/widgets/clue_panel_stub.dart';
import 'package:murdoku_app/ui/widgets/tool_panel_stub.dart';

// Synchronous screen fixture keeps layout tests independent of asset loading
CaseDefinition _caseFixture() => CaseDefinition(
  id: 'ui-fixture',
  title: 'Car Repair',
  difficulty: 'very-easy',
  rows: 6,
  columns: 6,
  roomGrid: List.generate(6, (_) => List<int?>.filled(6, 0)),
  roomNames: const {0: 'Workshop'},
  objectGrid: List.generate(6, (_) => List<String?>.filled(6, null)),
  objects: const <String, ObjectDefinition>{},
  generalClues: const ['A general clue'],
  characters: const [
    CharacterDefinition(
      id: 'A',
      name: 'Anthony',
      clue: 'A sample character clue',
      solution: (row: 0, column: 0),
    ),
    CharacterDefinition(
      id: 'V',
      name: 'Victim',
      clue: 'A sample victim clue',
      solution: (row: 1, column: 1),
    ),
  ],
  murderId: 'A',
);

void main() {
  testWidgets('case selection displays the configured case assets', (
    tester,
  ) async {
    await tester.pumpWidget(const MurdokuApp());
    await tester.pumpAndSettle();

    expect(find.text('Car Repair'), findsOneWidget);
    expect(find.text('A Horse With No Name'), findsOneWidget);
  });

  testWidgets('landscape case view exposes independent design slots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(home: CaseScreen(caseData: _caseFixture())),
    );

    expect(find.byType(CluePanelStub), findsOneWidget);
    expect(find.byType(BoardViewportStub), findsOneWidget);
    expect(find.byType(ToolPanelStub), findsOneWidget);
    expect(find.byKey(const ValueKey('visible-board-region')), findsOneWidget);
    expect(find.text('Tools'), findsOneWidget);
    expect(find.text('Anthony'), findsOneWidget);
  });

  testWidgets('portrait case view offers a rotation fallback', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(home: CaseScreen(caseData: _caseFixture())),
    );

    expect(find.text('Rotate to landscape'), findsOneWidget);
    expect(find.text('Back to cases'), findsOneWidget);
    expect(find.byType(BoardViewportStub), findsNothing);
  });
}
