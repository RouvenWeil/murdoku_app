import 'package:flutter/material.dart';

import 'murdoku_tokens.dart';

abstract final class MurdokuTheme {
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF75B9BA),
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF302F3D),
      fontFamily: 'Inter',
      visualDensity: VisualDensity.standard,
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(MurdokuTokens.minTouchSize),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(
            MurdokuTokens.minTouchSize,
            MurdokuTokens.minTouchSize,
          ),
        ),
      ),
    );
  }
}
