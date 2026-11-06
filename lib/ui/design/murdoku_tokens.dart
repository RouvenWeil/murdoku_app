import 'package:flutter/material.dart';

// Shared Murdoku UI measurements and mockup colors
abstract final class MurdokuTokens {
  static const double minTouchSize = 48;
  static const double portraitWidth = 44;
  static const double portraitHeight = 44;
  static const double profileFrameWidth = 48;
  static const double profileFrameHeight = 66;
  static const double borderWidth = 2;
  static const double profileNameHeight = 20;
  static const double cardRadius = 8;
  static const double cardGap = 8;
  static const double panelInset = 8;
  static const double selectionSpread = 4;

  static const Color characterCard = Color(0xFF3B5966);
  static const Color generalCard = Color(0xFF47424D);
  static const Color generalAccent = Color(0xFFCFAF78);
  static const Color cardOutline = Color(0xFF222222);
  static const Color clueText = Color(0xFFEEEEEE);
  static const Color toolSurface = Color(0xFF383648);
  static const Color toolOutline = Color(0xFF474558);
  static const Color selected = Color(0xFF8ECEEB);
  static const Color gridOutline = Color(0xFFFF7171);

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
