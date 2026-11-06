import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murdoku_app/ui/design/murdoku_assets.dart';
import 'package:murdoku_app/ui/design/murdoku_theme.dart';
import 'package:murdoku_app/ui/design/murdoku_tokens.dart';
import 'package:murdoku_app/ui/design/murdoku_typography.dart';
import 'package:murdoku_app/ui/screens/case_screen.dart';

void main() {
  test('shared board and control values preserve the approved geometry', () {
    expect(MurdokuTokens.minTouchSize, 48);
    expect(CaseScreenLayout.minimumCellSize, MurdokuTokens.minTouchSize);
    expect(CaseScreenLayout.boardMargin, MurdokuTokens.panelInset);
    expect(CaseScreenLayout.panelPadding, MurdokuTokens.panelInset);
    expect(MurdokuTokens.boardMarkInset, 8);
    expect(MurdokuTokens.boardMarkDoubleInset, 16);
    expect(MurdokuTokens.paintStrokeWidth, 4);
    expect(MurdokuTokens.borderWidth, 2);
    expect(
      MurdokuTokens.placementHoldDuration,
      const Duration(milliseconds: 650),
    );
    expect(
      MurdokuTokens.placementHoldStartDelay,
      const Duration(milliseconds: 200),
    );
    expect(MurdokuTokens.resetHoldDuration, const Duration(milliseconds: 950));
    expect(MurdokuTokens.boardSnapDuration, const Duration(milliseconds: 180));
  });

  test('typography exposes role-based compact and roomy reading scales', () {
    final compact = MurdokuTypography.forViewport(620);
    final wide = MurdokuTypography.forViewport(896);
    expect(compact.body.fontSize, 14);
    expect(wide.body.fontSize, 16);
    expect(compact.body.height! * compact.body.fontSize!, 20);
    expect(wide.body.height! * wide.body.fontSize!, 24);
    expect(compact.heading.fontSize, 16);
    expect(wide.heading.fontSize, 18);
    expect(compact.suspectName.fontSize, 13);
    expect(wide.suspectName.fontSize, 14);
    expect(compact.toolLabel.fontSize, 14);
    expect(wide.toolLabel.fontSize, 14);
    expect(compact.toolSubtitle.fontSize, 12);
    expect(wide.toolSubtitle.fontSize, 12);
    expect(compact.body.fontFamily, MurdokuTypography.uiFontFamily);
    expect(
      wide.suspectName.fontFamily,
      MurdokuTypography.handwritingFontFamily,
    );
    expect(wide.toolLabel.fontWeight, FontWeight.w700);
    expect(MurdokuTypography.forViewport(200).body.fontSize, 14);
    expect(MurdokuTypography.forViewport(1800).body.fontSize, 16);
  });

  test('theme and board colors come from the shared design palette', () {
    final theme = MurdokuTheme.dark();
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, MurdokuTokens.scaffoldSurface);
    expect(theme.colorScheme.brightness, Brightness.dark);
    expect(MurdokuTokens.roomColors.length, 5);
    expect(MurdokuTokens.boardMarkFill, const Color(0xFFF7EFDA));
  });

  test('artwork locations retain their existing asset names', () {
    expect(MurdokuAssets.boardCross, 'assets/ui/Vector-Cross.svg');
    expect(MurdokuAssets.crossTool, 'assets/ui/Vector-CrossOut.svg');
    expect(MurdokuAssets.back, 'assets/ui/IconButton-Back.svg');
  });
}
