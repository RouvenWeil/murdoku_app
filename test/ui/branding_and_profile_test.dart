import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/ui/design/murdoku_tokens.dart';
import 'package:murdoku_app/ui/design/murdoku_typography.dart';
import 'package:murdoku_app/ui/widgets/character_profile.dart';
import 'package:murdoku_app/ui/widgets/murdoku_brand.dart';

void main() {
  testWidgets('portrait artwork is square with a three-sided white border', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CharacterProfile(
            name: 'Anthony',
            initial: 'A',
            typography: MurdokuTypography(12),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(CharacterProfile)), const Size(48, 66));
    final frame = tester.widget<Container>(
      find.byKey(const ValueKey('character-portrait-frame-A')),
    );
    final border = (frame.decoration as BoxDecoration).border! as Border;
    expect(border.left.width, MurdokuTokens.borderWidth);
    expect(border.right.width, MurdokuTokens.borderWidth);
    expect(border.top.width, MurdokuTokens.borderWidth);
    expect(border.bottom.width, 0);
    expect(
      tester.getSize(find.byKey(const ValueKey('character-portrait-image-A'))),
      const Size(44, 44),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('logo and Caveat credit fit a narrow clue header', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 150, height: 48, child: MurdokuBrand()),
        ),
      ),
    );

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('by Manuel\nGarand'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('murdoku-credit-stacked')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('credit stays single-line when the logo has enough space', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 340, height: 64, child: MurdokuBrand()),
        ),
      ),
    );
    expect(find.text('by Manuel Garand'), findsOneWidget);
    expect(find.byKey(const ValueKey('murdoku-credit-inline')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enlarged text retains a legible two-line credit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: const Scaffold(
            body: SizedBox(width: 185, height: 72, child: MurdokuBrand()),
          ),
        ),
      ),
    );
    expect(find.text('by Manuel\nGarand'), findsOneWidget);
    final text = tester.widget<Text>(find.text('by Manuel\nGarand'));
    expect(text.style!.fontSize, greaterThanOrEqualTo(13));
    expect(tester.takeException(), isNull);
  });
}
