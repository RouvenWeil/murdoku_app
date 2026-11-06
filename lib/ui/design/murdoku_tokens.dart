import 'package:flutter/material.dart';

// Shared visual decisions. All dimensions are Flutter logical pixels (dp).
abstract final class MurdokuTokens {
  // Spacing scale, distinct from layout-specific solver constraints
  static const double space2 = 2;
  static const double space4 = 4;
  static const double space6 = 6;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;

  // Controls, cards and character portraits
  static const double minTouchSize = 48;
  static const double toolIconSize = 24;
  static const double caseStatusIconSize = 18;
  static const double portraitWidth = 44;
  static const double portraitHeight = 44;
  static const double profileFrameWidth = 48;
  static const double profileFrameHeight = 66;
  static const double borderWidth = 2;
  static const double profileCornerRadius = 2;
  static const double profileNameHeight = 20;
  static const double cardRadius = 8;
  static const double cardGap = space8;
  static const double panelInset = space8;
  static const double selectionSpread = 4;
  static const double placedClueOpacity = 0.65;
  static const double disabledToolOpacity = 0.4;
  // Previews now have enough room for the case name and progress label.
  static const double caseCardHeight = 192;
  static const double casePreviewWidth = 132;
  // Protects full-size Submit labels at large Android font settings.
  static const double enlargedTextCompactToolContentWidth = 128;

  // Board marks and non-scaled painter strokes
  // A deliberate 4dp choice; scaled wall/grid widths remain proportional
  static const double paintStrokeWidth = 4;
  static const double boardMarkInset = 8;
  static const double boardMarkDoubleInset = boardMarkInset * 2;

  // Interaction timings are provisional and may need device validation
  static const Duration boardSnapDuration = Duration(milliseconds: 180);
  // Wait briefly after the finger settles on a cell, then animate the ring.
  static const Duration placementHoldStartDelay = Duration(milliseconds: 200);
  static const Duration placementHoldDuration = Duration(milliseconds: 650);
  static const Duration resetHoldDuration = Duration(milliseconds: 950);

  // Application surfaces and text
  static const Color themeSeed = Color(0xFF75B9BA);
  static const Color scaffoldSurface = Color(0xFF302F3D);
  static const Color characterCard = Color(0xFF3B5966);
  static const Color generalCard = Color(0xFF47424D);
  static const Color generalAccent = Color(0xFFCFAF78);
  static const Color cardOutline = Color(0xFF222222);
  static const Color clueText = Color(0xFFEEEEEE);
  static const Color toolSurface = Color(0xFF383648);
  static const Color toolOutline = Color(0xFF474558);
  static const Color toolDisabledSurface = Color(0xFF585762);
  static const Color submitDisabledSurface = Color(0xFF68686B);
  static const Color submitDisabledText = Color(0xFFB5B5B5);
  static const Color selected = Color(0xFF8ECEEB);
  static const Color gridOutline = Color(0xFFFF7171);

  // Board palette shared by the full board and minimap painter
  static const List<Color> roomColors = [
    Color(0xFF777F9E),
    Color(0xFF839A91),
    Color(0xFF9F8699),
    Color(0xFFA39283),
    Color(0xFF7B91A3),
  ];
  static const Color absentCell = Color(0xFF292837);
  static const Color boardCellOutline = Color(0x99322F40);
  static const Color boardRoomWall = Color(0xFF181824);
  static const Color boardObjectMarker = Color(0xFF263242);
  static const Color boardCorrect = Color(0xFF52DF8C);
  static const Color boardIncorrect = Color(0xFFFF6D6D);
  static const Color boardHoldIndicator = Color(0xFFF8EBCC);
  static const Color minimapViewportOutline = Color(0xFFFFF7DD);
  static const Color boardMarkFill = Color(0xFFF7EFDA);
  static const Color boardMarkOutline = Colors.black;

  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x66000000),
    offset: Offset(4, 4),
    blurRadius: 0,
  );

  static const BoxShadow selectionShadow = BoxShadow(
    color: selected,
    offset: Offset.zero,
    blurRadius: 0,
    spreadRadius: selectionSpread,
  );
}
