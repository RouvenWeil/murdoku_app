import 'package:flutter/material.dart';

import '../design/murdoku_tokens.dart';
import '../design/murdoku_typography.dart';

class CharacterProfile extends StatelessWidget {
  const CharacterProfile({
    super.key,
    required this.name,
    required this.initial,
    required this.typography,
    this.assetPath,
    this.isSelected = false,
  });

  final String name;
  final String initial;
  final String? assetPath;
  final bool isSelected;
  final MurdokuTypography typography;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('character-profile-surface-$initial'),
      width: MurdokuTokens.profileFrameWidth,
      height: MurdokuTokens.profileFrameHeight,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(MurdokuTokens.profileCornerRadius),
        boxShadow: [
          MurdokuTokens.cardShadow,
          if (isSelected) MurdokuTokens.selectionShadow,
        ],
      ),
      child: Column(
        children: [
          Container(
            key: ValueKey('character-portrait-frame-$initial'),
            width: MurdokuTokens.profileFrameWidth,
            height: MurdokuTokens.portraitHeight + MurdokuTokens.borderWidth,
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Colors.white,
                  width: MurdokuTokens.borderWidth,
                ),
                top: BorderSide(
                  color: Colors.white,
                  width: MurdokuTokens.borderWidth,
                ),
                right: BorderSide(
                  color: Colors.white,
                  width: MurdokuTokens.borderWidth,
                ),
              ),
            ),
            child: SizedBox.square(
              key: ValueKey('character-portrait-image-$initial'),
              dimension: MurdokuTokens.portraitWidth,
              child: assetPath == null
                  ? const DecoratedBox(
                      decoration: BoxDecoration(color: MurdokuTokens.selected),
                      child: Center(child: Icon(Icons.person)),
                    )
                  : Image.asset(
                      assetPath!,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (context, error, stack) =>
                          Center(child: Text(initial)),
                    ),
            ),
          ),
          SizedBox(
            height: MurdokuTokens.profileNameHeight,
            width: MurdokuTokens.profileFrameWidth,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(name, maxLines: 1, style: typography.suspectName),
            ),
          ),
        ],
      ),
    );
  }
}
