import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/media_variants.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/features/discovery/domain/entities/product_collection.dart';
import 'package:ohara/features/home/presentation/providers/home_provider.dart';
import 'package:ohara/features/product_social/presentation/providers/product_social_providers.dart';

/// «ذوقكِ، قطعة قطعة» — the recommendations as a deck she plays with.
///
/// A shelf of ten recommendations is scrolled past; a deck of ten is
/// decided, one at a time, with her thumb. Right means she loves it — the
/// piece is liked for real, so it lands in her likes and teaches the
/// recommender — and left lets it go. The top card leans as she drags and a
/// stamp says which way it will fall; let go short of the edge and it
/// springs back. The last card counts what she kept and offers the full
/// shelf, or the deck again.
class HomeStyleDeck extends ConsumerStatefulWidget {
  const HomeStyleDeck({super.key});

  @override
  ConsumerState<HomeStyleDeck> createState() => _HomeStyleDeckState();
}

class _HomeStyleDeckState extends ConsumerState<HomeStyleDeck>
    with SingleTickerProviderStateMixin {
  static const int _deckSize = 10;

  /// How far a card must travel, as a share of its width, to be decided.
  static const double _decideAt = 0.32;

  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: DsMotion.moderate,
  );

  int _top = 0;
  int _liked = 0;
  Offset _drag = Offset.zero;
  Animation<Offset>? _flight;

  /// Which way the card in flight is leaving: 1 right, -1 left, 0 home.
  int _leaving = 0;

  @override
  void initState() {
    super.initState();
    _settle.addListener(() {
      final flight = _flight;
      if (flight != null) setState(() => _drag = flight.value);
    });
    _settle.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      if (_leaving != 0) {
        setState(() {
          _top++;
          _drag = Offset.zero;
          _leaving = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  List<Product> _deck(WidgetRef ref) {
    final state = ref.watch(homeNotifierProvider);
    for (final collection in const [
      ProductCollection.recommended,
      ProductCollection.trending,
      ProductCollection.newArrivals,
    ]) {
      final products = state.sectionOf(collection).products;
      if (products.isNotEmpty) return products.take(_deckSize).toList();
    }
    return const [];
  }

  void _fly(Offset to, {required int leaving}) {
    _leaving = leaving;
    _flight = Tween(
      begin: _drag,
      end: to,
    ).animate(CurvedAnimation(parent: _settle, curve: DsMotion.emphasized));
    _settle.forward(from: 0);
  }

  void _decide(Product product, {required bool love, required double width}) {
    if (_leaving != 0) return;
    unawaited(HapticFeedback.lightImpact());
    if (love) {
      _liked++;
      unawaited(
        ref.read(productEngagementProvider.notifier).setLiked(product.id, true),
      );
    }
    final dx = (love ? 1 : -1) * width * 1.5;
    _fly(Offset(dx, _drag.dy + DsSpacing.xl), leaving: love ? 1 : -1);
  }

  void _restart() => setState(() {
    _top = 0;
    _liked = 0;
    _drag = Offset.zero;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final deck = _deck(ref);
    if (deck.isEmpty) return const SizedBox.shrink();

    final done = _top >= deck.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.homeDeckEyebrow,
            style: context.dsText.overline.tint(colors.primary),
          ),
          DsGaps.vXxs,
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.homeDeckTitle,
                  style: context.dsText.sectionTitle.displayFamily.bold,
                ),
              ),
              if (!done)
                Text(
                  l10n.homeDeckProgress(_top + 1, deck.length),
                  style: context.dsText.captionStrong.tabular.tint(
                    colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          DsGaps.vMd,
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = width / DsSizes.aspectPortrait * 0.92;
              return SizedBox(
                height: height + DsSpacing.lg,
                child: done
                    ? _DoneCard(
                        liked: _liked,
                        onSeeAll: () => context.push(
                          RoutePaths.collectionOf(
                            ProductCollection.recommended.key,
                          ),
                        ),
                        onRestart: _restart,
                      )
                    : _stack(deck, width, height),
              );
            },
          ),
          if (!done) ...[
            DsGaps.vMd,
            _Controls(
              onPass: () => _decide(
                deck[_top],
                love: false,
                width: MediaQuery.sizeOf(context).width,
              ),
              onOpen: () =>
                  context.push(RoutePaths.productDetailsOf(deck[_top].id)),
              onLove: () => _decide(
                deck[_top],
                love: true,
                width: MediaQuery.sizeOf(context).width,
              ),
            ),
            DsGaps.vSm,
            Center(
              child: Text(
                l10n.homeDeckHint,
                style: context.dsText.caption.tint(colors.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stack(List<Product> deck, double width, double height) {
    final visible = [
      for (var i = math.min(_top + 2, deck.length - 1); i >= _top; i--) i,
    ];
    // How far the top card has gone, 0..1 — the cards behind rise with it.
    final progress = (_drag.dx.abs() / (width * _decideAt)).clamp(0.0, 1.0);

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        for (final i in visible)
          if (i == _top)
            _topCard(deck[i], width, height)
          else
            _restingCard(deck[i], height, depth: i - _top, progress: progress),
      ],
    );
  }

  Widget _restingCard(
    Product product,
    double height, {
    required int depth,
    required double progress,
  }) {
    final level = depth - progress;
    return Transform.translate(
      offset: Offset(0, DsSpacing.sm * level),
      child: Transform.scale(
        scale: 1 - 0.05 * level,
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: height,
          child: _ProductFace(product: product, dim: 0.18 * level),
        ),
      ),
    );
  }

  Widget _topCard(Product product, double width, double height) {
    final lean = (_drag.dx / width).clamp(-1.0, 1.0);
    return GestureDetector(
      onTap: () => context.push(RoutePaths.productDetailsOf(product.id)),
      onPanStart: (_) => _settle.stop(),
      onPanUpdate: (details) {
        if (_leaving != 0) return;
        setState(() => _drag += details.delta);
      },
      onPanEnd: (details) {
        if (_leaving != 0) return;
        final velocity = details.velocity.pixelsPerSecond.dx;
        final far = _drag.dx.abs() > width * _decideAt;
        final fast = velocity.abs() > 900;
        if (far || fast) {
          final love = (fast ? velocity : _drag.dx) > 0;
          _decide(product, love: love, width: width);
        } else {
          _fly(Offset.zero, leaving: 0);
        }
      },
      child: Transform.translate(
        offset: _drag,
        child: Transform.rotate(
          angle: lean * 0.22,
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _ProductFace(product: product, raised: true),
                _Stamp(
                  label: context.l10n.homeDeckLike,
                  color: context.dsColors.success,
                  opacity: lean.clamp(0.0, 0.6) / 0.6,
                  alignment: Alignment.topLeft,
                  tilt: -0.22,
                ),
                _Stamp(
                  label: context.l10n.homeDeckPass,
                  color: context.dsColors.discount,
                  opacity: (-lean).clamp(0.0, 0.6) / 0.6,
                  alignment: Alignment.topRight,
                  tilt: 0.22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One piece, full-bleed: the photograph, then the shop, name and price on a
/// soft shade at the foot of the card.
class _ProductFace extends StatelessWidget {
  const _ProductFace({
    required this.product,
    this.dim = 0,
    this.raised = false,
  });

  final Product product;
  final double dim;
  final bool raised;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final url = product.coverUrl ?? '';
    final price = product.price;
    final seller = product.displaySeller?.name;

    return Container(
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderXxxl,
        boxShadow: raised ? context.shadowLuxury : context.shadowXs,
      ),
      child: ClipRRect(
        borderRadius: DsRadius.borderXxxl,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url.isEmpty)
              const DsMediaFallback()
            else
              CachedNetworkImage(
                imageUrl: MediaVariants.at(url, MediaVariants.medium),
                fit: BoxFit.cover,
                fadeInDuration: DsMotion.normal,
                placeholder: (_, _) => ColoredBox(color: colors.shimmerBase),
                errorWidget: (_, _, _) => const DsMediaFallback(),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.45, 1],
                  colors: [DsColors.transparent, DsColors.mediaGround],
                ),
              ),
            ),
            if (product.hasDiscount)
              PositionedDirectional(
                top: DsSpacing.md,
                end: DsSpacing.md,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DsSpacing.xs,
                    vertical: DsSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.discount,
                    borderRadius: DsRadius.borderFull,
                  ),
                  child: Text(
                    '-${product.discountPercent}%',
                    // A signed number keeps its own direction, or Arabic
                    // turns «-21%» into «21%-».
                    textDirection: TextDirection.ltr,
                    style: context.dsText.captionStrong.tint(DsColors.onMedia),
                  ),
                ),
              ),
            PositionedDirectional(
              start: DsSpacing.lg,
              end: DsSpacing.lg,
              bottom: DsSpacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (seller != null)
                    Text(
                      seller,
                      style: context.dsText.captionStrong.tint(
                        DsColors.onMediaMuted,
                      ),
                    ),
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.screenTitle.displayFamily.bold.tint(
                      DsColors.onMedia,
                    ),
                  ),
                  if (price != null) ...[
                    DsGaps.vXxs,
                    Text(
                      price.format(),
                      style: context.dsText.price.tint(DsColors.gold200),
                    ),
                  ],
                ],
              ),
            ),
            if (dim > 0)
              ColoredBox(color: colors.background.withValues(alpha: dim)),
          ],
        ),
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.label,
    required this.color,
    required this.opacity,
    required this.alignment,
    required this.tilt,
  });

  final String label;
  final Color color;
  final double opacity;
  final Alignment alignment;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(DsSpacing.xl),
        child: Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: tilt,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DsSpacing.sm,
                vertical: DsSpacing.xxs,
              ),
              decoration: BoxDecoration(
                borderRadius: DsRadius.borderMd,
                border: Border.all(color: color, width: DsSpacing.xxs - 1),
                color: DsColors.mediaPlate,
              ),
              child: Text(
                label,
                style: context.dsText.screenTitle.bold.tint(color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.onPass,
    required this.onOpen,
    required this.onLove,
  });

  final VoidCallback onPass;
  final VoidCallback onOpen;
  final VoidCallback onLove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    // Laid out by the hand, not by the reading direction: skip sits where a
    // card leaves to be skipped (left), love where it leaves to be loved
    // (right), in Arabic as in English.
    return Row(
      textDirection: TextDirection.ltr,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundButton(
          icon: Icons.close_rounded,
          label: l10n.homeDeckPass,
          size: DsSizes.controlXl,
          color: colors.surface,
          ink: colors.onSurfaceVariant,
          onTap: onPass,
        ),
        DsGaps.hLg,
        _RoundButton(
          icon: Icons.north_east_rounded,
          label: l10n.homeDeckOpen,
          size: DsSizes.controlMd,
          color: colors.surface,
          ink: colors.onSurface,
          onTap: onOpen,
        ),
        DsGaps.hLg,
        _RoundButton(
          icon: Icons.favorite_rounded,
          label: l10n.homeDeckLike,
          size: DsSizes.controlXl,
          gradient: CustomerExperience.signatureGradient,
          ink: DsColors.onMedia,
          onTap: onLove,
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.size,
    required this.ink,
    required this.onTap,
    this.color,
    this.gradient,
  });

  final IconData icon;
  final String label;
  final double size;
  final Color ink;
  final VoidCallback onTap;
  final Color? color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            gradient: gradient,
            border: gradient == null
                ? Border.all(color: context.dsColors.border)
                : null,
            boxShadow: context.shadowSoft,
          ),
          child: Icon(icon, color: ink, size: size * 0.42),
        ),
      ),
    );
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard({
    required this.liked,
    required this.onSeeAll,
    required this.onRestart,
  });

  final int liked;
  final VoidCallback onSeeAll;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderXxxl,
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [DsColors.mauve800, DsColors.primary700, DsColors.coral400],
        ),
        boxShadow: context.shadowLuxury,
      ),
      padding: const EdgeInsets.all(DsSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const DsSparkle(size: DsSizes.iconXl, color: DsColors.gold200),
          DsGaps.vLg,
          Text(
            l10n.homeDeckDoneTitle,
            textAlign: TextAlign.center,
            style: context.dsText.pageTitle.displayFamily.bold.tint(
              DsColors.onMedia,
            ),
          ),
          DsGaps.vSm,
          Text(
            l10n.homeDeckDoneBody(liked),
            textAlign: TextAlign.center,
            style: context.dsText.body.tint(DsColors.onMediaMuted),
          ),
          DsGaps.vXl,
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: DsColors.onMedia,
              foregroundColor: DsColors.primary700,
            ),
            onPressed: onSeeAll,
            child: Text(l10n.homeDeckSeeAll),
          ),
          DsGaps.vXs,
          TextButton(
            style: TextButton.styleFrom(foregroundColor: DsColors.onMedia),
            onPressed: onRestart,
            child: Text(l10n.homeDeckRestart),
          ),
        ],
      ),
    );
  }
}
