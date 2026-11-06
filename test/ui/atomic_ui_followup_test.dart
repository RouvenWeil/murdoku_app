import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/domain/character_definition.dart';
import 'package:murdoku_app/ui/design/murdoku_tokens.dart';
import 'package:murdoku_app/ui/design/murdoku_typography.dart';
import 'package:murdoku_app/ui/screens/case_screen.dart';
import 'package:murdoku_app/ui/widgets/character_profile.dart';
import 'package:murdoku_app/ui/widgets/clue_cards.dart';
import 'package:murdoku_app/ui/widgets/clue_pin_button.dart';

const _character = CharacterDefinition(
  id: 'A',
  name: 'Anthony',
  clue: 'He was in a car.',
  solution: (row: 0, column: 0),
);

Future<void> _showCard(
  WidgetTester tester, {
  required VoidCallback onSelect,
  required VoidCallback onPin,
  bool selected = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: CharacterClueCard(
              character: _character,
              typography: const MurdokuTypography(12),
              isSelected: selected,
              isPinned: false,
              onSelect: onSelect,
              onPin: onPin,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('portrait and clue text both select the same character', (
    tester,
  ) async {
    var selections = 0;
    await _showCard(tester, onSelect: () => selections++, onPin: () {});

    await tester.tap(find.byKey(const ValueKey('select-character-profile-A')));
    await tester.pump();
    expect(selections, 1);

    await tester.tap(find.byKey(const ValueKey('select-character-A')));
    await tester.pump();
    expect(selections, 2);
  });

  testWidgets('pin remains independent of both selection targets', (
    tester,
  ) async {
    var selections = 0;
    var pins = 0;
    await _showCard(tester, onSelect: () => selections++, onPin: () => pins++);

    await tester.tap(find.byType(CluePinButton));
    await tester.pump();
    expect(pins, 1);
    expect(selections, 0);
  });

  testWidgets('body and profile both show the selected shadow', (tester) async {
    await _showCard(tester, selected: true, onSelect: () {}, onPin: () {});

    final body = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('character-clue-body-A')),
    );
    final bodyDecoration = body.decoration as BoxDecoration;
    expect(bodyDecoration.boxShadow, contains(MurdokuTokens.selectionShadow));
    final sharedBorder = find.descendant(
      of: find.byKey(const ValueKey('character-clue-body-A')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.position == DecorationPosition.foreground &&
            (widget.decoration as BoxDecoration).border != null,
      ),
    );
    expect(sharedBorder, findsOneWidget);

    final portrait = tester.widget<Container>(
      find.byKey(const ValueKey('character-profile-surface-A')),
    );
    final profileDecoration = portrait.decoration as BoxDecoration;
    expect(
      profileDecoration.boxShadow,
      contains(MurdokuTokens.selectionShadow),
    );

    // The clue and pin are inside one decorated card body.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('character-clue-body-A')),
        matching: find.byType(CluePinButton),
      ),
      findsOneWidget,
    );
  });

  testWidgets('short clue body hugs its 48dp pin instead of portrait height', (
    tester,
  ) async {
    await _showCard(tester, onSelect: () {}, onPin: () {});

    final bodySize = tester.getSize(
      find.byKey(const ValueKey('character-clue-body-A')),
    );
    final portraitSize = tester.getSize(find.byType(CharacterProfile));
    expect(bodySize.height, closeTo(48, 0.01));
    expect(portraitSize.height, 66);
  });

  test('minimap fills spare tool-panel space beyond the preferred 128dp', () {
    final layout = CaseScreenLayout.calculate(
      availableSize: const Size(1400, 600),
      rows: 16,
      columns: 16,
    )!;
    expect(layout.isPartial, isTrue);
    expect(layout.minimapSize, greaterThan(128));
    expect(layout.minimapWidth, lessThanOrEqualTo(layout.toolWidth - 16));
    expect(
      layout.boardViewportWidth,
      greaterThanOrEqualTo(layout.boardRegionWidth + 16 - 0.000001),
    );
    expect(
      layout.clueWidth + layout.boardViewportWidth + layout.toolWidth + 2,
      closeTo(1400, 0.000001),
    );
  });

  test('full board still hides the minimap', () {
    final layout = CaseScreenLayout.calculate(
      availableSize: const Size(844, 390),
      rows: 6,
      columns: 6,
    )!;
    expect(layout.isPartial, isFalse);
    expect(layout.minimapSize, 0);
  });
}
