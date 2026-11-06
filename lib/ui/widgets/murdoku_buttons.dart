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
    this.subtitle,
    this.iconAsset,
    this.fallbackIcon,
    this.showLabel = true,
    this.selected = false,
  });

  final String label;
  final String? subtitle;
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
            width: MurdokuTokens.toolIconSize,
            height: MurdokuTokens.toolIconSize,
            excludeFromSemantics: true,
          )
        : Icon(
            fallbackIcon ?? Icons.circle_outlined,
            size: MurdokuTokens.toolIconSize,
          );
    final hasIcon = iconAsset != null || fallbackIcon != null;
    final content = showLabel
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasIcon) ...[
                icon,
                const SizedBox(width: MurdokuTokens.space4),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: typography.toolLabel,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 2,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: typography.toolSubtitle,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          )
        : icon;

    final tooltip =
        '${label.replaceAll('\n', ' ')}${subtitle == null ? '' : ' — $subtitle'}';
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: MurdokuTokens.minTouchSize,
        width: showLabel ? double.infinity : MurdokuTokens.minTouchSize,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.square(MurdokuTokens.minTouchSize),
            padding: showLabel
                ? const EdgeInsets.symmetric(
                    horizontal: MurdokuTokens.space4,
                    vertical: MurdokuTokens.space2,
                  )
                : EdgeInsets.zero,
            backgroundColor: selected && onPressed != null
                ? MurdokuTokens.characterCard
                : MurdokuTokens.toolSurface,
            disabledBackgroundColor: MurdokuTokens.toolDisabledSurface,
            side: BorderSide(
              color: selected && onPressed != null
                  ? MurdokuTokens.selected
                  : MurdokuTokens.toolOutline,
              width: MurdokuTokens.borderWidth,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MurdokuTokens.cardRadius),
            ),
          ),
          child: Opacity(
            opacity: onPressed == null ? MurdokuTokens.disabledToolOpacity : 1,
            child: content,
          ),
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
    this.isSolved = false,
  });

  final VoidCallback? onPressed;
  final MurdokuTypography typography;
  final bool isSolved;

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
          disabledBackgroundColor: MurdokuTokens.submitDisabledSurface,
          disabledForegroundColor: MurdokuTokens.submitDisabledText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MurdokuTokens.cardRadius),
            side: const BorderSide(color: MurdokuTokens.toolOutline),
          ),
        ),
        child: Text(
          isSolved ? 'PLAY AGAIN' : 'SUBMIT',
          style: typography.toolLabel.copyWith(
            color: onPressed == null
                ? MurdokuTokens.submitDisabledText
                : Colors.white,
          ),
        ),
      ),
    );
  }
}
