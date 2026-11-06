import 'package:flutter/material.dart';

import 'murdoku_tokens.dart';

/// Semantic typography for the Android UI, in logical pixels before the
/// user's system font scaling. Do not interpolate text down to mockup sizes.
/// Layout (wrapping, scrolling and compact icon tools) adapts to the text.
class MurdokuTypography {
  const MurdokuTypography(this.baseSize);

  /// Primary clue-body size. Product code uses [forViewport]; the explicit
  /// constructor remains available for isolated component previews/tests.
  final double baseSize;

  static const String uiFontFamily = 'Inter';
  static const String handwritingFontFamily = 'Caveat';

  // Experiment values: Material-inspired roles, not platform-enforced minima.
  static const double compactBodySize = 14;
  static const double roomyBodySize = 16;
  static const double roomyViewportWidth = 896;
  static const double compactBodyLineHeight = 20;
  static const double roomyBodyLineHeight = 24;
  static const double compactHeadingSize = 16;
  static const double roomyHeadingSize = 18;
  static const double compactHeadingLineHeight = 24;
  static const double roomyHeadingLineHeight = 26;
  static const double toolLabelSize = 14;
  static const double toolLabelLineHeight = 20;
  static const double supportingSize = 12;
  static const double supportingLineHeight = 16;
  static const double compactNameSize = 13;
  static const double roomyNameSize = 14;
  static const double compactNameLineHeight = 16;
  static const double roomyNameLineHeight = 18;

  /// A simple presentation switch rather than a continuously shrinking font.
  /// This is a provisional breakpoint for the current layout, to be tested.
  factory MurdokuTypography.forViewport(double width) => MurdokuTypography(
    width >= roomyViewportWidth ? roomyBodySize : compactBodySize,
  );

  bool get _roomy => baseSize >= roomyBodySize;

  TextStyle get body => TextStyle(
    fontFamily: uiFontFamily,
    fontSize: baseSize,
    height: (_roomy ? roomyBodyLineHeight : compactBodyLineHeight) / baseSize,
    color: MurdokuTokens.clueText,
  );

  TextStyle get heading => TextStyle(
    fontFamily: uiFontFamily,
    fontSize: _roomy ? roomyHeadingSize : compactHeadingSize,
    height:
        (_roomy ? roomyHeadingLineHeight : compactHeadingLineHeight) /
        (_roomy ? roomyHeadingSize : compactHeadingSize),
    fontWeight: FontWeight.w700,
    color: MurdokuTokens.clueText,
  );

  TextStyle get suspectName => TextStyle(
    fontFamily: handwritingFontFamily,
    fontSize: _roomy ? roomyNameSize : compactNameSize,
    height:
        (_roomy ? roomyNameLineHeight : compactNameLineHeight) /
        (_roomy ? roomyNameSize : compactNameSize),
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  TextStyle get toolLabel => const TextStyle(
    fontFamily: uiFontFamily,
    fontSize: toolLabelSize,
    height: toolLabelLineHeight / toolLabelSize,
    fontWeight: FontWeight.w700,
    color: MurdokuTokens.clueText,
  );

  TextStyle get toolSubtitle => const TextStyle(
    fontFamily: uiFontFamily,
    fontSize: supportingSize,
    height: supportingLineHeight / supportingSize,
    color: MurdokuTokens.clueText,
  );

  TextStyle get supporting => toolSubtitle;

  TextStyle get toolHeading => heading;

  TextStyle get catalogTitle => heading;

  TextStyle get logoAddon => TextStyle(
    fontFamily: handwritingFontFamily,
    fontSize: _roomy ? roomyNameSize : compactNameSize,
    height: 1,
    color: MurdokuTokens.clueText,
  );
}
