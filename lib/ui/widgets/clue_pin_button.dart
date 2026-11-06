import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../design/murdoku_tokens.dart';

class CluePinButton extends StatelessWidget {
  const CluePinButton({
    super.key,
    required this.isPinned,
    required this.onPressed,
    required this.clueLabel,
  });

  final bool isPinned;
  final VoidCallback onPressed;
  final String clueLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: isPinned,
      label: '${isPinned ? 'Unpin' : 'Pin'} $clueLabel',
      child: Tooltip(
        message: '${isPinned ? 'Unpin' : 'Pin'} $clueLabel',
        child: SizedBox.square(
          dimension: MurdokuTokens.minTouchSize,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: const ValueKey('clue-pin-tap'),
              excludeFromSemantics: true,
              onTap: onPressed,
              child: SvgPicture.asset(
                isPinned ? 'assets/ui/Pinned.svg' : 'assets/ui/UnPinned.svg',
                width: 48,
                height: 48,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
