import 'package:flutter/material.dart';

import 'murdoku_tokens.dart';
import 'murdoku_typography.dart';

abstract final class MurdokuTheme {
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: MurdokuTokens.themeSeed,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: MurdokuTokens.scaffoldSurface,
      fontFamily: MurdokuTypography.uiFontFamily,
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
