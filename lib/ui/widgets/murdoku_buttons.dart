import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../design/murdoku_tokens.dart';
import '../design/murdoku_typography.dart';

class MurdokuToolButton extends StatelessWidget {
  const MurdokuToolButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.typography,
    this.iconAsset,
    this.fallbackIcon,
    this.showLabel = true,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final MurdokuTypography typography;
  final String? iconAsset;
  final IconData? fallbackIcon;
  final bool showLabel;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final icon = iconAsset != null
        ? SvgPicture.asset(
            iconAsset!,
            width: 24,
            height: 24,
            excludeFromSemantics: true,
          )
        : Icon(fallbackIcon ?? Icons.circle_outlined, size: 24);
    final content = showLabel
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconAsset != null || fallbackIcon != null) ...[
                icon,
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.body,
                ),
              ),
            ],
          )
        : icon;

    return Tooltip(
      message: label,
      child: SizedBox(
        height: MurdokuTokens.minTouchSize,
        width: showLabel ? double.infinity : MurdokuTokens.minTouchSize,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.square(MurdokuTokens.minTouchSize),
            padding: showLabel
                ? const EdgeInsets.symmetric(horizontal: 4)
                : EdgeInsets.zero,
            backgroundColor: MurdokuTokens.toolSurface,
            disabledBackgroundColor: MurdokuTokens.toolSurface,
            side: const BorderSide(color: MurdokuTokens.toolOutline, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MurdokuTokens.cardRadius),
            ),
          ),
          child: Opacity(opacity: onPressed == null ? 0.4 : 1, child: content),
        ),
      ),
    );
  }
}

class MurdokuSubmitButton extends StatelessWidget {
  const MurdokuSubmitButton({
    super.key,
    required this.onPressed,
    required this.typography,
  });

  final VoidCallback? onPressed;
  final MurdokuTypography typography;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MurdokuTokens.minTouchSize,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.square(MurdokuTokens.minTouchSize),
          backgroundColor: MurdokuTokens.toolSurface,
          disabledBackgroundColor: MurdokuTokens.toolSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MurdokuTokens.cardRadius),
            side: const BorderSide(color: MurdokuTokens.toolOutline),
          ),
        ),
        child: Text('Submit', style: typography.body),
      ),
    );
  }
}
