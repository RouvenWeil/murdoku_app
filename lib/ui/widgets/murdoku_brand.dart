import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../design/murdoku_assets.dart';
import '../design/murdoku_tokens.dart';
import '../design/murdoku_typography.dart';

// Header lockup shared between catalogue and case view. The attribution
// wraps before text or the entire logo lockup is shrunk unreadably.
class MurdokuBrand extends StatelessWidget {
  const MurdokuBrand({super.key, this.logoHeight = 32});

  final double logoHeight;

  // Dimensions are the intrinsic viewBox of our supplied logo artwork.
  static const double _logoAspectRatio = 367.618 / 80.022;

  // Allow the decorative logo to shrink before wrapping the readable credit.
  // Below this fraction, a two-line credit gives the logo more room again.
  static const double _minimumLogoWidthFraction = 0.55;

  @override
  Widget build(BuildContext context) {
    final typography = MurdokuTypography.forViewport(
      MediaQuery.sizeOf(context).width,
    );
    final creditStyle = typography.logoAddon;
    final scaler = MediaQuery.textScalerOf(context);

    double measuredWidth(String value) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: creditStyle),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    return Semantics(
      label: 'Murdoku by Manuel Garand',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final naturalLogoWidth = logoHeight * _logoAspectRatio;
            final gap = MurdokuTokens.space8;
            final minimumLogoWidth =
                naturalLogoWidth * _minimumLogoWidthFraction;
            final shouldStack =
                constraints.maxWidth.isFinite &&
                minimumLogoWidth + gap + measuredWidth('by Manuel Garand') >
                    constraints.maxWidth;
            final credit = shouldStack
                ? 'by Manuel\nGarand'
                : 'by Manuel Garand';
            final creditWidth = measuredWidth(credit);
            // Prioritize a readable attribution, giving the SVG the remaining
            // horizontal space. Its aspect ratio is preserved by BoxFit.contain.
            final logoWidth = constraints.maxWidth.isFinite
                ? math.min(
                    naturalLogoWidth,
                    math.max(0.0, constraints.maxWidth - creditWidth - gap),
                  )
                : naturalLogoWidth;
            final creditWidget = Text(
              credit,
              key: ValueKey(
                shouldStack
                    ? 'murdoku-credit-stacked'
                    : 'murdoku-credit-inline',
              ),
              maxLines: 2,
              softWrap: true,
              style: creditStyle,
            );
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (logoWidth > 0) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: MurdokuTokens.space8),
                    child: SizedBox(
                      width: logoWidth,
                      height: logoHeight,
                      child: SvgPicture.asset(
                        MurdokuAssets.logo,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: MurdokuTokens.space8),
                ],
                if (constraints.maxWidth.isFinite)
                  Flexible(fit: FlexFit.loose, child: creditWidget)
                else
                  creditWidget,
              ],
            );
          },
        ),
      ),
    );
  }
}
