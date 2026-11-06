import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/domain/case_definition.dart';
import 'package:murdoku_app/domain/character_definition.dart';
import 'package:murdoku_app/domain/object_definition.dart';
import 'package:murdoku_app/ui/design/murdoku_typography.dart';
import 'package:murdoku_app/ui/design/murdoku_tokens.dart';
import 'package:murdoku_app/ui/screens/case_screen.dart';
import 'package:murdoku_app/ui/widgets/clue_text.dart';
import 'package:murdoku_app/ui/widgets/murdoku_buttons.dart';
import 'package:murdoku_app/ui/widgets/tool_panel_stub.dart';

CaseDefinition _fixture(int n) => CaseDefinition(
  id: 'readability-$n',
  title: 'A Case With a Longer Name',
  difficulty: 'easy',
  rows: n,
  columns: n,
  roomGrid: List.generate(n, (_) => List<int?>.filled(n, 0)),
  roomNames: const {0: 'Room'},
  objectGrid: List.generate(n, (_) => List<String?>.filled(n, null)),
  objects: const <String, ObjectDefinition>{},
  generalClues: const [
    'The person who entered the garden first did not sit near the window '
        'and was not alone with the victim.',
    'The room had exactly two other people in it.',
  ],
  characters: const [
    CharacterDefinition(
      id: 'A',
      name: 'Anthony',
      clue:
          'He was in a car with exactly two other people. '
          'Neither person had a hat.',
      solution: (row: 0, column: 0),
    ),
    CharacterDefinition(
      id: 'V',
      name: 'Vaughn',
      clue: 'The victim was alone in the room until another person entered.',
      solution: (row: 1, column: 1),
    ),
  ],
  murderId: 'A',
);

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _show(
  WidgetTester tester, {
  required Size size,
  required int rows,
  double scale = 1,
}) async {
  _setViewport(tester, size);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: CaseScreen(caseData: _fixture(rows)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test('tool label size is independent of viewport width', () {
    for (final width in [320.0, 620.0, 844.0, 896.0, 1200.0]) {
      final typography = MurdokuTypography.forViewport(width);
      expect(typography.body.fontSize, greaterThanOrEqualTo(14));
      expect(typography.toolLabel.fontSize, 14);
      expect(typography.toolSubtitle.fontSize, 12);
    }
  });

  testWidgets(
    'compact landscape: long clues wrap and the toolbar remains usable',
    (tester) async {
      await _show(tester, size: const Size(620, 320), rows: 6);
      final clue = tester.widgetList<ClueText>(find.byType(ClueText)).first;
      expect(clue.style.fontSize, 14);
      expect(find.byType(ToolPanelStub), findsOneWidget);
      expect(find.byKey(const ValueKey('case-heading-inline')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '130 percent text scaling does not cause compact toolbar overflow',
    (tester) async {
      await _show(tester, size: const Size(720, 272), rows: 16, scale: 1.3);
      expect(find.byKey(const ValueKey('case-minimap')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('compact-tool-controls')),
        findsOneWidget,
      );
      final element = tester.element(find.byType(ToolPanelStub));
      expect(MediaQuery.textScalerOf(element).scale(14), closeTo(18.2, 0.01));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '200 percent text scaling keeps clue list and compact actions accessible',
    (tester) async {
      await _show(tester, size: const Size(720, 272), rows: 16, scale: 2);
      final firstClue = tester
          .widgetList<ClueText>(find.byType(ClueText))
          .first;
      expect(firstClue.style.fontSize, 14); // Flutter scales at render time
      final element = tester.element(find.byType(ClueText).first);
      expect(MediaQuery.textScalerOf(element).scale(14), 28);
      expect(
        find.byKey(const ValueKey('compact-tool-controls')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('case-heading-stacked')),
        findsOneWidget,
      );
      expect(find.byType(MurdokuSubmitButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '200 percent text scaling: full-board labelled toolbar can scroll',
    (tester) async {
      await _show(tester, size: const Size(896, 414), rows: 6, scale: 2);
      final toolButton = tester.widget<MurdokuToolButton>(
        find.byKey(const ValueKey('tool-cross')),
      );
      expect(toolButton.showLabel, isTrue);
      expect(
        find.byKey(const ValueKey('case-heading-stacked')),
        findsOneWidget,
      );
      expect(toolButton.typography.toolLabel.fontSize, 14);
      // The long toolbar uses a lazy ListView; offscreen controls are not built
      // until we scroll. Finding them immediately is a test assumption error.
      await tester.scrollUntilVisible(
        find.byType(MurdokuSubmitButton),
        100,
        scrollable: find.descendant(
          of: find.byType(ToolPanelStub),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.byType(MurdokuSubmitButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('enlarged text prefers icons in stacked compact toolbar', (
    tester,
  ) async {
    await _show(tester, size: const Size(560, 300), rows: 16, scale: 2);
    final tools = tester.widget<ToolPanelStub>(find.byType(ToolPanelStub));
    expect(tools.arrangement, ToolPanelArrangement.stacked);
    expect(
      tester.getSize(find.byType(ToolPanelStub)).width,
      greaterThanOrEqualTo(
        MurdokuTokens.enlargedTextCompactToolContentWidth +
            2 * MurdokuTokens.panelInset,
      ),
    );
    final undo = tester.widget<MurdokuToolButton>(
      find.byKey(const ValueKey('tool-undo')),
    );
    expect(undo.showLabel, isFalse);
    expect(find.byKey(const ValueKey('case-heading-stacked')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two-line tool labels do not use a scale-down FittedBox', (
    tester,
  ) async {
    _setViewport(tester, const Size(320, 320));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SizedBox(
              width: 140,
              child: MurdokuToolButton(
                label: 'Place\nCross',
                onPressed: () {},
                typography: MurdokuTypography.forViewport(620),
                iconAsset: null,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(FittedBox), findsNothing);
    final control = tester.getSize(find.byType(OutlinedButton));
    expect(control.height, greaterThan(48));
    expect(tester.takeException(), isNull);
  });
}
