import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/l10n/app_localizations.dart';

/// «على أي مزاج اليوم؟» — six moods, each a door into the stylist.
///
/// A category asks her to know which aisle she wants. A mood asks how she
/// feels about today, which she always knows, and the stylist turns it into
/// a whole look: tapping «سهرة» opens it already asked «أريد إطلالة سهرة
/// أنيقة». Each tile is its own small jewel — a gradient, an icon, one word —
/// and tilts under her thumb.
class HomeMoodDial extends StatelessWidget {
  const HomeMoodDial({super.key});

  static const double _tileWidth = DsSizes.thumbLg + DsSpacing.md;
  static const double _tileHeight = DsSizes.railCardWidth - DsSpacing.lg;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final moods = _Mood.all(l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.homeMoodTitle,
                style: context.dsText.sectionTitle.displayFamily.bold,
              ),
              DsGaps.vXxs,
              Text(
                l10n.homeMoodSubtitle,
                style: context.dsText.bodySmall.tint(colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        DsGaps.vMd,
        SizedBox(
          height: _tileHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
            clipBehavior: Clip.none,
            itemCount: moods.length,
            separatorBuilder: (_, _) => DsGaps.hSm,
            itemBuilder: (context, i) => SizedBox(
              width: _tileWidth,
              child: _MoodTile(
                mood: moods[i],
                onTap: () =>
                    context.push(RoutePaths.stylistAsking(moods[i].prompt)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Mood {
  const _Mood(this.label, this.prompt, this.icon, this.colors);

  final String label;
  final String prompt;
  final IconData icon;
  final List<Color> colors;

  static List<_Mood> all(AppLocalizations l10n) => [
    _Mood(
      l10n.homeMoodEvening,
      l10n.homeMoodPromptEvening,
      Icons.nightlife_rounded,
      const [DsColors.mauve800, DsColors.primary600],
    ),
    _Mood(
      l10n.homeMoodWedding,
      l10n.homeMoodPromptWedding,
      Icons.diamond_outlined,
      const [DsColors.gold500, DsColors.primary400],
    ),
    _Mood(
      l10n.homeMoodWork,
      l10n.homeMoodPromptWork,
      Icons.work_outline_rounded,
      const [DsColors.mauve600, DsColors.lavender500],
    ),
    _Mood(
      l10n.homeMoodCasual,
      l10n.homeMoodPromptCasual,
      Icons.wb_sunny_outlined,
      const [DsColors.coral500, DsColors.gold400],
    ),
    _Mood(
      l10n.homeMoodGift,
      l10n.homeMoodPromptGift,
      Icons.card_giftcard_rounded,
      const [DsColors.primary700, DsColors.coral400],
    ),
    _Mood(
      l10n.homeMoodTravel,
      l10n.homeMoodPromptTravel,
      Icons.flight_takeoff_rounded,
      const [DsColors.accent600, DsColors.lavender400],
    ),
  ];
}

class _MoodTile extends StatefulWidget {
  const _MoodTile({required this.mood, required this.onTap});

  final _Mood mood;
  final VoidCallback onTap;

  @override
  State<_MoodTile> createState() => _MoodTileState();
}

class _MoodTileState extends State<_MoodTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final mood = widget.mood;
    return Semantics(
      button: true,
      label: mood.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DsMotion.fast,
          curve: DsMotion.emphasized,
          transformAlignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateX(_pressed ? 0.08 : 0)
            ..scaleByDouble(_pressed ? 0.95 : 1, _pressed ? 0.95 : 1, 1, 1),
          decoration: BoxDecoration(
            borderRadius: DsRadius.borderXxl,
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: mood.colors,
            ),
            boxShadow: [
              BoxShadow(
                color: mood.colors.last.withValues(alpha: 0.32),
                blurRadius: DsBlur.heavy,
                offset: const Offset(0, DsSpacing.xs),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: DsRadius.borderXxl,
            child: Stack(
              children: [
                // A big ghost of the icon, cropped by the corner — the tile's
                // texture, so six gradients do not read as six swatches.
                PositionedDirectional(
                  end: -DsSpacing.lg,
                  top: -DsSpacing.md,
                  child: Icon(
                    mood.icon,
                    size: DsSizes.iconHero + DsSpacing.lg,
                    color: DsColors.onMediaFaint,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(DsSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: DsSizes.controlSm,
                        height: DsSizes.controlSm,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: DsColors.mediaPlate,
                          border: Border.all(color: DsColors.onMediaFaint),
                        ),
                        child: Icon(
                          mood.icon,
                          size: DsSizes.iconSm,
                          color: DsColors.onMedia,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        mood.label,
                        style: context.dsText.cardTitle.displayFamily.bold.tint(
                          DsColors.onMedia,
                        ),
                      ),
                      DsGaps.vXxxs,
                      const DsSparkle(
                        size: DsSizes.iconXxs,
                        color: DsColors.onMediaMuted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
