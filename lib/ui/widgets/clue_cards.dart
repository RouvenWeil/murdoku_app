import 'package:flutter/material.dart';

import '../../domain/character_definition.dart';
import '../design/murdoku_tokens.dart';
import '../design/murdoku_typography.dart';
import 'character_profile.dart';
import 'clue_pin_button.dart';
import 'clue_text.dart';

class GeneralClueCard extends StatelessWidget {
  const GeneralClueCard({
    super.key,
    required this.clue,
    required this.typography,
    required this.isPinned,
    required this.onPin,
    this.emphasizedPhrases = const [],
  });

  final String clue;
  final MurdokuTypography typography;
  final bool isPinned;
  final VoidCallback onPin;
  final List<String> emphasizedPhrases;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MurdokuTokens.cardGap, right: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: MurdokuTokens.generalAccent,
          borderRadius: BorderRadius.circular(MurdokuTokens.cardRadius),
          boxShadow: const [MurdokuTokens.cardShadow],
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: MurdokuTokens.generalCard,
              borderRadius: BorderRadius.circular(MurdokuTokens.cardRadius),
            ),
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(MurdokuTokens.cardRadius),
                border: Border.all(color: MurdokuTokens.cardOutline, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(MurdokuTokens.cardRadius),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: MurdokuTokens.minTouchSize,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: ClueText(
                            text: clue,
                            style: typography.body,
                            emphasizedPhrases: emphasizedPhrases,
                          ),
                        ),
                      ),
                      CluePinButton(
                        isPinned: isPinned,
                        onPressed: onPin,
                        clueLabel: 'general clue',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CharacterClueCard extends StatelessWidget {
  const CharacterClueCard({
    super.key,
    required this.character,
    required this.typography,
    required this.isSelected,
    required this.isPinned,
    required this.onSelect,
    required this.onPin,
    this.portraitAsset,
    this.emphasizedPhrases = const [],
  });

  final CharacterDefinition character;
  final MurdokuTypography typography;
  final bool isSelected;
  final bool isPinned;
  final VoidCallback onSelect;
  final VoidCallback onPin;
  final String? portraitAsset;
  final List<String> emphasizedPhrases;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: MurdokuTokens.cardGap,
        right: MurdokuTokens.selectionSpread,
        left: MurdokuTokens.selectionSpread,
        top: MurdokuTokens.selectionSpread,
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Reserve portrait height without stretching the text body
              const SizedBox(
                width: 42,
                height: MurdokuTokens.profileFrameHeight,
              ),
              Expanded(
                child: DecoratedBox(
                  key: ValueKey('character-clue-body-${character.id}'),
                  decoration: BoxDecoration(
                    color: MurdokuTokens.characterCard,
                    borderRadius: BorderRadius.circular(
                      MurdokuTokens.cardRadius,
                    ),
                    boxShadow: [
                      MurdokuTokens.cardShadow,
                      if (isSelected) MurdokuTokens.selectionShadow,
                    ],
                  ),
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        MurdokuTokens.cardRadius,
                      ),
                      border: Border.all(
                        color: MurdokuTokens.cardOutline,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        MurdokuTokens.cardRadius,
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                key: ValueKey(
                                  'select-character-${character.id}',
                                ),
                                onTap: onSelect,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    4,
                                    4,
                                    4,
                                  ),
                                  child: ClueText(
                                    text: character.clue,
                                    style: typography.body,
                                    emphasizedPhrases: emphasizedPhrases,
                                  ),
                                ),
                              ),
                            ),
                            // Pin and text sit inside one outlined surface
                            CluePinButton(
                              isPinned: isPinned,
                              onPressed: onPin,
                              clueLabel: '${character.name} clue',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: MurdokuTokens.minTouchSize,
                height: MurdokuTokens.profileFrameHeight,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    key: ValueKey('select-character-profile-${character.id}'),
                    onTap: onSelect,
                    borderRadius: BorderRadius.circular(2),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: CharacterProfile(
                        name: character.name,
                        initial: character.id,
                        assetPath: portraitAsset,
                        typography: typography,
                        isSelected: isSelected,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
