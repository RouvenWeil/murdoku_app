import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/domain/case_definition.dart';
import 'package:murdoku_app/domain/character_definition.dart';
import 'package:murdoku_app/domain/object_definition.dart';
import 'package:murdoku_app/ui/design/murdoku_tokens.dart';
import 'package:murdoku_app/ui/design/murdoku_typography.dart';
import 'package:murdoku_app/ui/screens/case_screen.dart';
import 'package:murdoku_app/ui/session/clue_pin_store.dart';
import 'package:murdoku_app/ui/widgets/character_profile.dart';
import 'package:murdoku_app/ui/widgets/clue_cards.dart';
import 'package:murdoku_app/ui/widgets/clue_pin_button.dart';
import 'package:murdoku_app/ui/widgets/clue_text.dart';

CaseDefinition _fixture() => CaseDefinition(
  id: 'clue-test',
  title: 'Clue Test',
  difficulty: 'easy',
  rows: 6,
  columns: 6,
  roomGrid: List.generate(6, (_) => List<int?>.filled(6, 0)),
  roomNames: const {0: 'Room'},
  objectGrid: List.generate(6, (_) => List<String?>.filled(6, null)),
  objects: const <String, ObjectDefinition>{},
  generalClues: const ['First general rule.', 'Second general rule.'],
  characters: const [
    CharacterDefinition(
      id: 'A',
      name: 'Anthony',
      clue: 'He was in a car.',
      solution: (row: 0, column: 0),
    ),
    CharacterDefinition(
      id: 'V',
      name: 'Vaughn',
      clue: 'The victim.',
      solution: (row: 1, column: 1),
    ),
  ],
  murderId: 'A',
);

void _landscape(WidgetTester tester) {
  tester.view.physicalSize = const Size(844, 390);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Finder _pinIn(String clueKey) => find.descendant(
  of: find.byKey(ValueKey(clueKey)),
  matching: find.byType(CluePinButton),
);

void main() {
  test('exclusive pin store toggles, replaces and scopes by case', () {
    final store = CluePinStore();
    expect(store.toggle('one', 'general:0'), 'general:0');
    expect(store.toggle('one', 'character:A'), 'character:A');
    expect(store.pinnedFor('two'), isNull);
    expect(store.toggle('one', 'character:A'), isNull);
  });

  test('responsive reading sizes remain legible at compact widths', () {
    expect(MurdokuTypography.forViewport(400).baseSize, 14);
    expect(MurdokuTypography.forViewport(896).baseSize, 16);
    expect(MurdokuTypography.forViewport(1200).baseSize, 16);
    expect(
      MurdokuTypography.forViewport(896).body.height,
      closeTo(24 / 16, 0.0001),
    );
  });

  testWidgets('pinning a general clue removes it from the scrolling list', (
    tester,
  ) async {
    _landscape(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: CaseScreen(caseData: _fixture(), pinStore: CluePinStore()),
      ),
    );
    await tester.tap(_pinIn('clue-general:1'));
    await tester.pump();
    final pinned = find.byKey(const ValueKey('pinned-clue-region'));
    expect(
      find.descendant(
        of: pinned,
        matching: find.byKey(const ValueKey('clue-general:1')),
      ),
      findsOneWidget,
    );
    final list = find.byKey(const ValueKey('unpinned-clue-list'));
    expect(
      find.descendant(
        of: list,
        matching: find.byKey(const ValueKey('clue-general:1')),
      ),
      findsNothing,
    );
    expect(find.byType(GeneralClueCard), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pinning another clue replaces the first pin without duplicates',
    (tester) async {
      _landscape(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: CaseScreen(caseData: _fixture(), pinStore: CluePinStore()),
        ),
      );
      await tester.tap(_pinIn('clue-general:0'));
      await tester.pump();
      await tester.tap(_pinIn('clue-character:A'));
      await tester.pump();
      final pinned = find.byKey(const ValueKey('pinned-clue-region'));
      expect(
        find.descendant(
          of: pinned,
          matching: find.byKey(const ValueKey('clue-character:A')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pinned, matching: find.byType(GeneralClueCard)),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('clue-character:A')), findsOneWidget);
      expect(find.byType(GeneralClueCard), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pin button does not select its character', (tester) async {
    _landscape(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: CaseScreen(caseData: _fixture(), pinStore: CluePinStore()),
      ),
    );
    await tester.tap(_pinIn('clue-character:A'));
    await tester.pump();
    var anthony = tester.widget<CharacterClueCard>(
      find.byKey(const ValueKey('clue-character:A')),
    );
    expect(anthony.isSelected, isFalse);
    expect(anthony.isPinned, isTrue);
    await tester.tap(find.byKey(const ValueKey('select-character-A')));
    await tester.pump();
    anthony = tester.widget<CharacterClueCard>(
      find.byKey(const ValueKey('clue-character:A')),
    );
    expect(anthony.isSelected, isTrue);
    expect(anthony.isPinned, isTrue);
  });

  testWidgets('unpin returns the clue to ordinary list order', (tester) async {
    _landscape(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: CaseScreen(caseData: _fixture(), pinStore: CluePinStore()),
      ),
    );
    await tester.tap(_pinIn('clue-general:0'));
    await tester.pump();
    await tester.tap(_pinIn('clue-general:0'));
    await tester.pump();
    expect(find.byKey(const ValueKey('pinned-clue-region')), findsNothing);
    final list = find.byKey(const ValueKey('unpinned-clue-list'));
    expect(
      find.descendant(
        of: list,
        matching: find.byKey(const ValueKey('clue-general:0')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: list,
        matching: find.byKey(const ValueKey('clue-general:1')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('pin survives case route reconstruction in one live process', (
    tester,
  ) async {
    _landscape(tester);
    final store = CluePinStore();
    await tester.pumpWidget(
      MaterialApp(
        home: CaseScreen(caseData: _fixture(), pinStore: store),
      ),
    );
    await tester.tap(_pinIn('clue-general:0'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpWidget(
      MaterialApp(
        home: CaseScreen(caseData: _fixture(), pinStore: store),
      ),
    );
    expect(store.pinnedFor('clue-test'), 'general:0');
    expect(find.byKey(const ValueKey('pinned-clue-region')), findsOneWidget);
  });

  testWidgets('portrait frame and pin target preserve design dimensions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              CharacterProfile(
                name: 'Anthony',
                initial: 'A',
                typography: const MurdokuTypography(12),
              ),
              CluePinButton(
                isPinned: false,
                onPressed: () {},
                clueLabel: 'Anthony',
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(CharacterProfile)), const Size(48, 66));
    expect(tester.getSize(find.byType(CluePinButton)), const Size(48, 48));
  });

  testWidgets('explicit bold emphasis is supported without auto-highlighting', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ClueText(
            text: 'He was beside a trash can.',
            style: TextStyle(fontSize: 12),
            emphasizedPhrases: ['beside a trash can'],
          ),
        ),
      ),
    );
    final rich = tester.widget<Text>(find.byType(Text).first);
    final outer = rich.textSpan! as TextSpan;
    final spans = outer.children!.cast<TextSpan>();
    expect(
      spans.any(
        (span) =>
            span.text == 'beside a trash can' &&
            span.style?.fontWeight == FontWeight.bold,
      ),
      isTrue,
    );
  });

  testWidgets('selected style uses 4dp spread with zero blur and offset', (
    tester,
  ) async {
    expect(MurdokuTokens.selectionShadow.spreadRadius, 4);
    expect(MurdokuTokens.selectionShadow.blurRadius, 0);
    expect(MurdokuTokens.selectionShadow.offset, Offset.zero);
  });
}
