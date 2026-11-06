import 'package:flutter/material.dart';

// Viewport-dependent mockup type scale, in Flutter logical pixels
class MurdokuTypography {
  const MurdokuTypography(this.baseSize);

  final double baseSize;

  // 620dp and 896dp are the small and large mockup reference widths
  factory MurdokuTypography.forViewport(double width) {
    final fraction = ((width - 620) / (896 - 620)).clamp(0.0, 1.0);
    return MurdokuTypography(8 + 4 * fraction);
  }

  TextStyle get body => TextStyle(
    fontFamily: 'Inter',
    fontSize: baseSize,
    height: (baseSize + 2) / baseSize,
    color: Colors.grey[200],
  );

  TextStyle get heading => TextStyle(
    fontFamily: 'Inter',
    fontSize: baseSize + 2,
    height: (baseSize + 4) / (baseSize + 2),
    color: Colors.grey[200],
  );

  TextStyle get suspectName => TextStyle(
    fontFamily: 'Caveat',
    fontSize: baseSize - 2,
    height: 1,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  TextStyle get logoAddon => TextStyle(
    fontFamily: 'Caveat',
    fontSize: baseSize + 2,
    height: 1,
    color: Colors.grey[200],
  );
}
