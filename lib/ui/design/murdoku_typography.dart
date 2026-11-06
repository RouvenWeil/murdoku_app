import 'package:flutter/material.dart';

import 'murdoku_tokens.dart';

// Viewport-dependent mockup type scale, in Flutter logical pixels
class MurdokuTypography {
  const MurdokuTypography(this.baseSize);

  final double baseSize;

  static const String uiFontFamily = 'Inter';
  static const String handwritingFontFamily = 'Caveat';
  static const double compactReferenceWidth = 620;
  static const double wideReferenceWidth = 896;
  static const double compactBaseSize = 8;
  static const double wideBaseSize = 12;
  static const double lineLeading = 2;

  // 620dp and 896dp are the small and large mockup reference widths
  factory MurdokuTypography.forViewport(double width) {
    final fraction =
        ((width - compactReferenceWidth) /
                (wideReferenceWidth - compactReferenceWidth))
            .clamp(0.0, 1.0);
    return MurdokuTypography(
      compactBaseSize + (wideBaseSize - compactBaseSize) * fraction,
    );
  }

  TextStyle get body => TextStyle(
    fontFamily: uiFontFamily,
    fontSize: baseSize,
    height: (baseSize + lineLeading) / baseSize,
    color: MurdokuTokens.clueText,
  );

  TextStyle get heading => TextStyle(
    fontFamily: uiFontFamily,
    fontSize: baseSize + lineLeading,
    height: (baseSize + 2 * lineLeading) / (baseSize + lineLeading),
    color: MurdokuTokens.clueText,
  );

  TextStyle get suspectName => TextStyle(
    fontFamily: handwritingFontFamily,
    fontSize: baseSize - lineLeading,
    height: 1,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  TextStyle get toolLabel => body.copyWith(fontWeight: FontWeight.w700);

  TextStyle get toolSubtitle => body.copyWith(
    fontSize: (baseSize - lineLeading).clamp(6.0, 20.0).toDouble(),
  );

  TextStyle get toolHeading => heading.copyWith(fontWeight: FontWeight.w600);

  TextStyle get logoAddon => TextStyle(
    fontFamily: handwritingFontFamily,
    fontSize: baseSize + lineLeading,
    height: 1,
    color: MurdokuTokens.clueText,
  );
}
