import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/case_definition.dart';
import '../../domain/character_definition.dart';
import '../design/murdoku_assets.dart';
import '../design/murdoku_tokens.dart';
import '../design/murdoku_typography.dart';
import 'clue_cards.dart';
import 'murdoku_brand.dart';

class CluePanelStub extends StatelessWidget {
  const CluePanelStub({
    super.key,
    required this.caseData,
    required this.selectedCharacterId,
    required this.onCharacterSelected,
    required this.pinnedClueId,
    required this.onPinClue,
    required this.onBack,
    this.placedCharacterIds = const {},
    this.elapsed = Duration.zero,
  });

  final CaseDefinition caseData;
  final String? selectedCharacterId;
  final ValueChanged<String> onCharacterSelected;
  final String? pinnedClueId;
  final ValueChanged<String> onPinClue;
  final VoidCallback onBack;
  final Set<String> placedCharacterIds;
  final Duration elapsed;

  static String formatElapsed(Duration duration) {
    final total = duration.inSeconds;
    final hours = total ~/ 3600;
    final minutes = (total ~/ 60) % 60;
    final seconds = total % 60;
    final clock =
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
    return hours == 0 ? clock : '$hours:$clock';
  }

  static String generalId(int index) => 'general:$index';
  static String characterId(String id) => 'character:$id';

  String? _portraitFor(CharacterDefinition character) {
    // JSON wins if a case supplies its own portrait. Otherwise use only the
    // two portrait sets I actually have, and keep the fallback for the rest.
    return character.imageAsset ??
        MurdokuAssets.portrait(caseData.id, character.id);
  }

  Widget _generalCard(int index, MurdokuTypography typography) {
    final id = generalId(index);
    return GeneralClueCard(
      key: ValueKey('clue-$id'),
      clue: caseData.generalClues[index],
      typography: typography,
      isPinned: pinnedClueId == id,
      onPin: () => onPinClue(id),
    );
  }

  Widget _characterCard(
    CharacterDefinition character,
    MurdokuTypography typography,
  ) {
    final id = characterId(character.id);
    final card = CharacterClueCard(
      key: ValueKey('clue-$id'),
      character: character,
      typography: typography,
      portraitAsset: _portraitFor(character),
      isPinned: pinnedClueId == id,
      isSelected: selectedCharacterId == character.id,
      onSelect: () => onCharacterSelected(character.id),
      onPin: () => onPinClue(id),
    );
    return placedCharacterIds.contains(character.id)
        ? Opacity(opacity: MurdokuTokens.placedClueOpacity, child: card)
        : card;
  }

  Widget? _pinnedCard(MurdokuTypography typography) {
    final pin = pinnedClueId;
    if (pin == null) return null;
    if (pin.startsWith('general:')) {
      final index = int.tryParse(pin.substring('general:'.length));
      if (index != null && index >= 0 && index < caseData.generalClues.length) {
        return _generalCard(index, typography);
      }
    }
    if (pin.startsWith('character:')) {
      final id = pin.substring('character:'.length);
      for (final character in caseData.characters) {
        if (character.id == id) return _characterCard(character, typography);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final typography = MurdokuTypography.forViewport(
      MediaQuery.sizeOf(context).width,
    );
    // At 200% text on a short landscape screen the fixed header can take
    // almost the entire clue column. Let the whole column scroll instead of
    // squeezing the clues down to an empty viewport.
    final veryShortWithLargeText =
        MediaQuery.sizeOf(context).height < 300 &&
        MediaQuery.textScalerOf(context).scale(14) > 20;
    if (veryShortWithLargeText) {
      final pinned = _pinnedCard(typography);
      return SingleChildScrollView(
        key: const ValueKey('clue-compact-scroll'),
        padding: const EdgeInsets.all(MurdokuTokens.space8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back to cases',
                  onPressed: onBack,
                  icon: SvgPicture.asset(
                    MurdokuAssets.back,
                    width: MurdokuTokens.minTouchSize,
                    excludeFromSemantics: true,
                  ),
                ),
                const Expanded(child: MurdokuBrand()),
              ],
            ),
            Column(
              key: const ValueKey('case-heading-stacked'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(caseData.title, style: typography.heading),
                Text('Timer ${formatElapsed(elapsed)}', style: typography.body),
              ],
            ),
            const SizedBox(height: MurdokuTokens.space8),
            if (pinned != null) ...[pinned, const Divider()],
            // Eager children here are intentional: a short viewport still
            // needs a reachable clue list, even before the first scroll.
            Column(
              key: const ValueKey('unpinned-clue-list'),
              children: [
                for (var i = 0; i < caseData.generalClues.length; i++)
                  if (pinnedClueId != generalId(i)) _generalCard(i, typography),
                for (final character in caseData.characters)
                  if (!placedCharacterIds.contains(character.id) &&
                      pinnedClueId != characterId(character.id))
                    _characterCard(character, typography),
                for (final character in caseData.characters)
                  if (placedCharacterIds.contains(character.id) &&
                      pinnedClueId != characterId(character.id))
                    _characterCard(character, typography),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MurdokuTokens.space8,
            MurdokuTokens.space8,
            MurdokuTokens.space8,
            MurdokuTokens.space4,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                tooltip: 'Back to cases',
                iconSize: MurdokuTokens.minTouchSize,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: MurdokuTokens.minTouchSize,
                  height: MurdokuTokens.minTouchSize,
                ),
                icon: SvgPicture.asset(
                  MurdokuAssets.back,
                  width: MurdokuTokens.minTouchSize,
                  height: MurdokuTokens.minTouchSize,
                  excludeFromSemantics: true,
                ),
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MurdokuTokens.space8,
                    vertical: MurdokuTokens.space4,
                  ),
                  child: MurdokuBrand(),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MurdokuTokens.space8,
            MurdokuTokens.space4,
            MurdokuTokens.space8,
            MurdokuTokens.space12,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // When Android enlarges text, the elapsed-time label and the
              // case title need their own lines. The compact arrangement
              // prevents horizontal overflow without shrinking the text,
              // regardless of how wide the board layout makes this panel.
              final scaledBodySize = MediaQuery.textScalerOf(context)
                  .scale(typography.body.fontSize!);
              final useStackedHeader =
                  scaledBodySize > typography.body.fontSize! * 1.3;
              final title = Text(
                caseData.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: typography.heading,
              );
              final timer = Text(
                'Timer ${formatElapsed(elapsed)}',
                style: typography.body,
              );

              if (useStackedHeader) {
                return Column(
                  key: const ValueKey('case-heading-stacked'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: MurdokuTokens.space4),
                    timer,
                  ],
                );
              }
              return Row(
                key: const ValueKey('case-heading-inline'),
                children: [
                  Expanded(child: title),
                  const SizedBox(width: MurdokuTokens.space8),
                  timer,
                ],
              );
            },
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final pinned = _pinnedCard(typography);
              return Column(
                children: [
                  if (pinned != null)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * 0.55,
                      ),
                      child: SingleChildScrollView(
                        key: const ValueKey('pinned-clue-region'),
                        padding: const EdgeInsets.fromLTRB(
                          MurdokuTokens.panelInset,
                          MurdokuTokens.space4,
                          MurdokuTokens.panelInset,
                          0,
                        ),
                        child: pinned,
                      ),
                    ),
                  if (pinned != null)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: MurdokuTokens.space8,
                      ),
                      child: Divider(height: 1),
                    ),
                  Expanded(
                    child: ListView(
                      key: const ValueKey('unpinned-clue-list'),
                      padding: const EdgeInsets.fromLTRB(
                        MurdokuTokens.space8,
                        MurdokuTokens.space4,
                        MurdokuTokens.space8,
                        MurdokuTokens.space8,
                      ),
                      children: [
                        if (caseData.generalClues.isNotEmpty) ...[
                          for (var i = 0; i < caseData.generalClues.length; i++)
                            if (pinnedClueId != generalId(i))
                              _generalCard(i, typography),
                          const SizedBox(height: MurdokuTokens.space8),
                        ],
                        for (final character in caseData.characters)
                          if (!placedCharacterIds.contains(character.id) &&
                              pinnedClueId != characterId(character.id))
                            _characterCard(character, typography),
                        for (final character in caseData.characters)
                          if (placedCharacterIds.contains(character.id) &&
                              pinnedClueId != characterId(character.id))
                            _characterCard(character, typography),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
