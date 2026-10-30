import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/media/media_decode.dart';
import 'package:ohara/core/media/media_variants.dart';

/// The profile register: **a portrait in an arch**.
///
/// A page on Ohara is a woman, or a boutique, framed the way the sign-in
/// journey frames the brand — in the pointed window of an old Damascus house,
/// standing in slow light. The pieces here are the vocabulary every profile is
/// built from:
///
/// * [ProfileHero] — the living ground, the floating chrome and the portrait.
/// * [ProfilePortrait] — the photograph cut to the arch, with a turning thread
///   that quickens and brightens while there is a story to watch.
/// * [ProfileNameplate] — name in the display serif, handle and role seal.
/// * [ProfileQuote] — a bio set as something she said.
/// * [ProfileArchStats] — counts in a row of small arches.
/// * [ProfileAwning] — a boutique's figures under a scalloped shop awning.
/// * [ProfileTabBar] — icons that open into a lit pill when chosen.
///
/// Two tones: [ProfileTone.shopper] is rose; [ProfileTone.boutique] is
/// champagne gold, so a shop reads as a shop before a word is read.
enum ProfileTone { shopper, boutique }

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

/// The top of a profile: aurora ground, a row of floating glass buttons, and
/// the arch portrait settled at the foot where the ground fades into the page.
class ProfileHero extends StatelessWidget {
  const ProfileHero({
    super.key,
    required this.name,
    this.imageUrl,
    this.tone = ProfileTone.shopper,
    this.hasStory = false,
    this.onPortraitTap,
    this.leading,
    this.actions = const [],
  });

  final String name;
  final String? imageUrl;
  final ProfileTone tone;
  final bool hasStory;
  final VoidCallback? onPortraitTap;

  /// Usually a back button; null on a root tab.
  final Widget? leading;
  final List<Widget> actions;

  static const double _groundHeight = 296;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final top = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: top + _groundHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AuthAurora(
            tone: tone == ProfileTone.boutique
                ? AuroraTone.champagne
                : AuroraTone.rose,
          ),
          // The ground melts into the page, so the portrait stands on it
          // rather than on a seam.
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.background.withValues(alpha: 0),
                    colors.background,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: top + DsSpacing.xs,
            left: DsSpacing.md,
            right: DsSpacing.md,
            child: Row(
              children: [
                ?leading,
                const Spacer(),
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) DsGaps.hXs,
                  actions[i],
                ],
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ProfilePortrait(
              name: name,
              imageUrl: imageUrl,
              tone: tone,
              hasStory: hasStory,
              onTap: onPortraitTap,
            ),
          ),
        ],
      ),
    );
  }
}

/// A frosted round button that floats on the hero ground.
class ProfileCircleButton extends StatelessWidget {
  const ProfileCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surface.withValues(alpha: 0.72),
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
        boxShadow: context.shadowXs,
      ),
      child: IconButton(
        icon: Icon(icon, size: DsSizes.iconSm, color: colors.onSurface),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Portrait
// ---------------------------------------------------------------------------

/// Her photograph cut to the arch.
///
/// Framed by a thread that turns slowly: rose for a shopper, champagne for a
/// boutique. While there is a story to watch the thread thickens, turns three
/// times as fast and two sparkles orbit — the arch's version of the story ring,
/// and like the ring it is the thing to tap. With "reduce motion" on it holds
/// still and the thickness alone carries the meaning.
class ProfilePortrait extends StatefulWidget {
  const ProfilePortrait({
    super.key,
    required this.name,
    this.imageUrl,
    this.tone = ProfileTone.shopper,
    this.hasStory = false,
    this.onTap,
    this.width = 128,
  });

  final String name;
  final String? imageUrl;
  final ProfileTone tone;
  final bool hasStory;
  final VoidCallback? onTap;

  /// The arch's width; its height is proportional.
  final double width;

  @override
  State<ProfilePortrait> createState() => _ProfilePortraitState();
}

class _ProfilePortraitState extends State<ProfilePortrait>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _controller
        ..stop()
        ..value = 0.15;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boutique = widget.tone == ProfileTone.boutique;
    final archWidth = widget.width;
    final archHeight = archWidth * 1.24;
    final canvas = Size(archWidth * 1.6, archHeight + 36);
    final arch = Rect.fromLTWH(
      (canvas.width - archWidth) / 2,
      canvas.height - archHeight - 6,
      archWidth,
      archHeight,
    );
    final thread = widget.hasStory ? 4.5 : 3.0;
    final photo = arch.deflate(thread + 2);

    final portrait = SizedBox.fromSize(
      size: canvas,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _PortraitBackPainter(
                animation: _controller,
                arch: arch,
                thread: thread,
                speed: widget.hasStory ? 3 : 1,
                colors: boutique ? _boutiqueThread : _shopperThread,
                glow: (boutique ? DsColors.gold400 : colors.primary).withValues(
                  alpha: isDark ? 0.42 : 0.34,
                ),
                gap: colors.background,
              ),
            ),
          ),
          Positioned.fromRect(
            rect: photo,
            child: ClipPath(
              clipper: const DsArchClipper(),
              child: _PortraitImage(
                name: widget.name,
                imageUrl: widget.imageUrl,
                width: photo.width,
                boutique: boutique,
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _PortraitFrontPainter(
                  animation: _controller,
                  arch: arch,
                  photo: photo,
                  orbit: widget.hasStory,
                  sparkle: isDark ? DsColors.gold300 : DsColors.gold400,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      label: widget.name,
      image: widget.imageUrl != null && widget.imageUrl!.isNotEmpty,
      button: widget.onTap != null,
      excludeSemantics: true,
      child: widget.onTap == null
          ? portrait
          : GestureDetector(
              onTap: widget.onTap,
              behavior: HitTestBehavior.opaque,
              child: portrait,
            ),
    );
  }

  static const _shopperThread = [
    DsColors.primary500,
    DsColors.secondary400,
    DsColors.gold300,
    DsColors.primary300,
    DsColors.primary500,
  ];

  static const _boutiqueThread = [
    DsColors.gold500,
    DsColors.gold200,
    DsColors.primary400,
    DsColors.gold300,
    DsColors.gold500,
  ];
}

class _PortraitImage extends StatelessWidget {
  const _PortraitImage({
    required this.name,
    required this.imageUrl,
    required this.width,
    required this.boutique,
  });

  final String name;
  final String? imageUrl;
  final double width;
  final bool boutique;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      final pixels = MediaDecode.widthFor(context, width);
      return CachedNetworkImage(
        imageUrl: MediaVariants.at(url, pixels ?? 512),
        fit: BoxFit.cover,
        memCacheWidth: pixels,
        placeholder: (_, _) => ColoredBox(color: context.dsColors.shimmerBase),
        errorWidget: (_, _, _) => _initials(context),
      );
    }
    return _initials(context);
  }

  /// No photograph: her initials, large and in the display serif, on the
  /// tone's own blend.
  Widget _initials(BuildContext context) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    // One letter for an Arabic name: two Arabic initials side by side join
    // into a word — «لمى الحسن» would read «لا».
    final arabic =
        words.isNotEmpty &&
        RegExp(r'[؀-ۿ]').hasMatch(words.first.characters.first);
    final letters = words
        .take(arabic ? 1 : 2)
        .map((part) => part.characters.first)
        .join();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: boutique
              ? const [DsColors.gold200, DsColors.gold400, DsColors.gold600]
              : const [
                  DsColors.primary300,
                  DsColors.primary600,
                  DsColors.secondary600,
                ],
        ),
      ),
      child: Align(
        alignment: const Alignment(0, 0.25),
        child: letters.isEmpty
            ? Icon(
                Icons.person_rounded,
                size: width * 0.4,
                color: DsColors.onMedia,
              )
            : Text(
                letters,
                style: TextStyle(
                  fontFamily: DsTypography.fontFamilyDisplay,
                  fontFamilyFallback: DsTypography.displayFallback,
                  fontSize: width * 0.34,
                  fontWeight: DsTypography.bold,
                  color: DsColors.onMedia,
                  height: 1,
                ),
              ),
      ),
    );
  }
}

class _PortraitBackPainter extends CustomPainter {
  _PortraitBackPainter({
    required this.animation,
    required this.arch,
    required this.thread,
    required this.speed,
    required this.colors,
    required this.glow,
    required this.gap,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Rect arch;
  final double thread;
  final int speed;
  final List<Color> colors;
  final Color glow;

  /// The page colour, painted between the thread and the photograph so the
  /// two read as separate lines.
  final Color gap;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;

    canvas.drawPath(
      dsArchPath(arch.inflate(6)),
      Paint()
        ..color = glow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );
    canvas.drawPath(
      dsArchPath(arch),
      Paint()
        ..shader = SweepGradient(
          colors: colors,
          transform: GradientRotation(math.pi * 2 * t * speed),
        ).createShader(arch),
    );
    canvas.drawPath(dsArchPath(arch.deflate(thread)), Paint()..color = gap);
  }

  @override
  bool shouldRepaint(_PortraitBackPainter old) =>
      old.arch != arch ||
      old.thread != thread ||
      old.speed != speed ||
      old.glow != glow ||
      old.gap != gap ||
      old.colors != colors;
}

class _PortraitFrontPainter extends CustomPainter {
  _PortraitFrontPainter({
    required this.animation,
    required this.arch,
    required this.photo,
    required this.orbit,
    required this.sparkle,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Rect arch;
  final Rect photo;
  final bool orbit;
  final Color sparkle;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    const tau = math.pi * 2;

    // Light through the glass: a pearl sheen down from the crown.
    canvas.save();
    canvas.clipPath(dsArchPath(photo));
    canvas.drawRect(
      photo,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [Color(0x40FFFFFF), Color(0x00FFFFFF)],
        ).createShader(photo),
    );
    canvas.restore();

    // A fine pearl line just inside the photograph.
    canvas.drawPath(
      dsArchPath(photo.deflate(6)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x59FFFFFF),
    );

    // The keystone.
    final pulse = (math.sin(tau * t * 4) + 1) / 2;
    _star(
      canvas,
      Offset(arch.center.dx, arch.top - 12),
      13 + 4 * pulse,
      sparkle.withValues(alpha: 0.55 + 0.45 * pulse),
    );

    if (!orbit) return;
    final rx = arch.width * 0.72;
    final ry = arch.height * 0.5;
    for (var i = 0; i < 2; i++) {
      final angle = tau * t * 2 + i * math.pi;
      final depth = (math.sin(angle) + 1) / 2;
      _star(
        canvas,
        Offset(
          arch.center.dx + rx * math.cos(angle),
          arch.center.dy + ry * math.sin(angle) * 0.85,
        ),
        7 + 5 * depth,
        sparkle.withValues(alpha: 0.3 + 0.6 * depth),
      );
    }
  }

  @override
  bool shouldRepaint(_PortraitFrontPainter old) =>
      old.arch != arch ||
      old.photo != photo ||
      old.orbit != orbit ||
      old.sparkle != sparkle;
}

/// The four-point couture star.
void _star(Canvas canvas, Offset centre, double size, Color colour) {
  final r = size / 2;
  final k = r * 0.14;
  final cx = centre.dx;
  final cy = centre.dy;
  canvas.drawPath(
    Path()
      ..moveTo(cx, cy - r)
      ..quadraticBezierTo(cx + k, cy - k, cx + r, cy)
      ..quadraticBezierTo(cx + k, cy + k, cx, cy + r)
      ..quadraticBezierTo(cx - k, cy + k, cx - r, cy)
      ..quadraticBezierTo(cx - k, cy - k, cx, cy - r)
      ..close(),
    Paint()..color = colour,
  );
}

// ---------------------------------------------------------------------------
// Nameplate
// ---------------------------------------------------------------------------

/// Name in the display serif, the handle, a role seal and where she is.
class ProfileNameplate extends StatelessWidget {
  const ProfileNameplate({
    super.key,
    required this.name,
    required this.roleLabel,
    this.username,
    this.tone = ProfileTone.shopper,
    this.isVerified = false,
    this.verifiedLabel,
    this.location,
  });

  final String name;
  final String? username;
  final String roleLabel;
  final ProfileTone tone;
  final bool isVerified;

  /// Read aloud for the verified mark.
  final String? verifiedLabel;
  final String? location;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final text = context.dsText;
    final boutique = tone == ProfileTone.boutique;
    final ink = boutique
        ? [DsColors.gold600, colors.primary, DsColors.gold500]
        : [colors.primary, colors.secondary, colors.primary];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) =>
                    LinearGradient(colors: ink).createShader(bounds),
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.pageTitle.bold.copyWith(
                    color: DsColors.onMedia,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            if (isVerified) ...[
              DsGaps.hXs,
              Icon(
                Icons.verified_rounded,
                size: DsSizes.iconMd,
                color: boutique ? DsColors.gold500 : colors.primary,
                semanticLabel: verifiedLabel,
              ),
            ],
          ],
        ),
        DsGaps.vXs,
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: DsSpacing.xs,
          runSpacing: DsSpacing.xxs,
          children: [
            if (username != null && username!.isNotEmpty)
              Text(
                '@$username',
                textDirection: TextDirection.ltr,
                style: text.body.copyWith(color: colors.onSurfaceVariant),
              ),
            _RoleSeal(label: roleLabel, boutique: boutique),
          ],
        ),
        if (location != null && location!.isNotEmpty) ...[
          DsGaps.vXs,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.place_rounded,
                size: DsSizes.iconXs,
                color: boutique ? DsColors.gold500 : colors.primary,
              ),
              DsGaps.hXxs,
              Flexible(
                child: Text(
                  location!,
                  style: text.bodySmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The role as a small seal: a gold blend for a boutique, a blush one for a
/// shopper, each with its mark.
class _RoleSeal extends StatelessWidget {
  const _RoleSeal({required this.label, required this.boutique});

  final String label;
  final bool boutique;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final ink = boutique ? DsColors.onGold : colors.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.sm,
        vertical: DsSpacing.xxxs,
      ),
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderPill,
        gradient: boutique
            ? DsGradients.gold
            : LinearGradient(
                colors: [colors.primaryContainer, colors.secondaryContainer],
              ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            boutique ? Icons.storefront_rounded : Icons.spa_rounded,
            size: DsSizes.iconXxs,
            color: ink,
          ),
          DsGaps.hXxs,
          Text(label, style: context.dsText.captionStrong.copyWith(color: ink)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quote
// ---------------------------------------------------------------------------

/// A bio set as something she said: centred, between two large quote marks
/// in the display serif.
class ProfileQuote extends StatelessWidget {
  const ProfileQuote({
    super.key,
    required this.text,
    this.tone = ProfileTone.shopper,
  });

  final String text;
  final ProfileTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final mark =
        (tone == ProfileTone.boutique ? DsColors.gold400 : colors.primary)
            .withValues(alpha: 0.35);
    final markStyle = TextStyle(
      fontFamily: DsTypography.fontFamilyDisplay,
      fontSize: 56,
      height: 1,
      fontWeight: DsTypography.bold,
      color: mark,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xl),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PositionedDirectional(
            top: -DsSpacing.sm,
            start: -DsSpacing.md,
            child: ExcludeSemantics(child: Text('“', style: markStyle)),
          ),
          PositionedDirectional(
            bottom: -DsSpacing.xxl,
            end: -DsSpacing.md,
            child: ExcludeSemantics(child: Text('”', style: markStyle)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DsSpacing.sm,
              vertical: DsSpacing.xs,
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: context.dsText.body.copyWith(
                color: colors.onSurface,
                height: 1.65,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats
// ---------------------------------------------------------------------------

/// One count on a profile.
@immutable
class ProfileStatItem {
  const ProfileStatItem({required this.value, required this.label, this.onTap});

  final String value;
  final String label;

  /// What the count opens. A count that cannot be opened reads as decoration.
  final VoidCallback? onTap;
}

/// Counts in a row of small arches, each a window onto what it counts.
class ProfileArchStats extends StatelessWidget {
  const ProfileArchStats({
    super.key,
    required this.items,
    this.tone = ProfileTone.shopper,
  });

  final List<ProfileStatItem> items;
  final ProfileTone tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) DsGaps.hSm,
            Expanded(
              child: _ArchStat(item: items[i], tone: tone),
            ),
          ],
        ],
      ),
    );
  }
}

class _ArchStat extends StatelessWidget {
  const _ArchStat({required this.item, required this.tone});

  final ProfileStatItem item;
  final ProfileTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boutique = tone == ProfileTone.boutique;
    final rim = boutique
        ? [DsColors.gold300, DsColors.gold500.withValues(alpha: 0.4)]
        : [DsColors.primary300, colors.secondary.withValues(alpha: 0.35)];

    final tile = CustomPaint(
      painter: _ArchTilePainter(
        fill: (isDark ? colors.surfaceElevated : colors.surface).withValues(
          alpha: isDark ? 0.8 : 0.88,
        ),
        rim: rim,
        shadow: colors.shadow,
      ),
      child: SizedBox(
        height: 104,
        child: Padding(
          padding: const EdgeInsets.only(
            top: DsSpacing.xl,
            bottom: DsSpacing.sm,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                child: Text(
                  item.value,
                  style: context.dsText.sectionTitle.displayFamily.bold
                      .copyWith(
                        color: boutique ? DsColors.gold600 : colors.primary,
                        height: 1,
                      ),
                ),
              ),
              DsGaps.vXxs,
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.dsText.caption.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      button: item.onTap != null,
      label: '${item.label} ${item.value}',
      excludeSemantics: true,
      child: item.onTap == null
          ? tile
          : GestureDetector(
              onTap: item.onTap,
              behavior: HitTestBehavior.opaque,
              child: tile,
            ),
    );
  }
}

class _ArchTilePainter extends CustomPainter {
  const _ArchTilePainter({
    required this.fill,
    required this.rim,
    required this.shadow,
  });

  final Color fill;
  final List<Color> rim;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    // A squatter arch than the portrait's: the crown is drawn from the width,
    // so the tile keeps the window's shape at stat-tile proportions.
    final rect = (Offset.zero & size).deflate(1);
    final path = dsArchPath(rect);
    canvas.drawPath(
      path.shift(const Offset(0, 8)),
      Paint()
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: rim,
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ArchTilePainter old) =>
      old.fill != fill || old.shadow != shadow || old.rim != rim;
}

// ---------------------------------------------------------------------------
// Awning
// ---------------------------------------------------------------------------

/// A boutique's figures under a shop awning: champagne and cream stripes with
/// a scalloped edge, over a pearl card.
class ProfileAwning extends StatelessWidget {
  const ProfileAwning({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  static const double _awningHeight = 34;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _awningHeight,
            child: CustomPaint(
              painter: _AwningPainter(
                stripe: DsColors.gold300,
                cream: isDark ? DsColors.gold700 : DsColors.gold50,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: DsSpacing.xs),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DsSpacing.md,
                      vertical: DsSpacing.xxxs,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: DsRadius.borderPill,
                      color: colors.surface,
                      boxShadow: context.shadowXs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.storefront_rounded,
                          size: DsSizes.iconXxs,
                          color: DsColors.gold600,
                        ),
                        DsGaps.hXxs,
                        Text(
                          title,
                          style: context.dsText.captionStrong.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.md,
              DsSpacing.lg,
              DsSpacing.md,
              DsSpacing.md,
            ),
            decoration: BoxDecoration(
              color: (isDark ? colors.surfaceElevated : colors.surface)
                  .withValues(alpha: 0.92),
              borderRadius: const BorderRadius.vertical(
                bottom: DsRadius.circularXxl,
              ),
              border: Border.all(
                color: DsColors.gold300.withValues(alpha: 0.5),
              ),
              boxShadow: context.shadowSoft,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _AwningPainter extends CustomPainter {
  const _AwningPainter({required this.stripe, required this.cream});

  final Color stripe;
  final Color cream;

  @override
  void paint(Canvas canvas, Size size) {
    const stripes = 9;
    final w = size.width / stripes;
    final scallop = w / 2;
    final body = size.height - scallop;

    final outline = Path()
      ..moveTo(0, DsRadius.lg)
      ..quadraticBezierTo(0, 0, DsRadius.lg, 0)
      ..lineTo(size.width - DsRadius.lg, 0)
      ..quadraticBezierTo(size.width, 0, size.width, DsRadius.lg)
      ..lineTo(size.width, body);
    for (var i = stripes - 1; i >= 0; i--) {
      final left = i * w;
      outline.arcToPoint(
        Offset(left, body),
        radius: Radius.circular(scallop),
        clockwise: true,
      );
    }
    outline.close();

    canvas.save();
    canvas.clipPath(outline);
    for (var i = 0; i < stripes; i++) {
      canvas.drawRect(
        Rect.fromLTWH(i * w, 0, w + 0.5, size.height),
        Paint()..color = i.isEven ? stripe : cream,
      );
    }
    // A soft fold of shade under the top edge.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x26FFFFFF), Color(0x00FFFFFF), Color(0x1A6A5232)] // gold700 @ 10%,
        ).createShader(Offset.zero & size),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AwningPainter old) =>
      old.stripe != stripe || old.cream != cream;
}

// ---------------------------------------------------------------------------
// Tabs
// ---------------------------------------------------------------------------

/// One tab: its mark and its name.
@immutable
class ProfileTabItem {
  const ProfileTabItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Tabs as a frosted rail of icons; the chosen one opens into a lit pill that
/// carries its name. Five tabs fit a phone this way where five labelled chips
/// would not, and the name is never far — it is on the one she is reading.
class ProfileTabBar extends StatelessWidget {
  const ProfileTabBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
    this.tone = ProfileTone.shopper,
  });

  final List<ProfileTabItem> items;
  final int selected;
  final ValueChanged<int> onSelect;
  final ProfileTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final boutique = tone == ProfileTone.boutique;
    final lit = boutique
        ? const LinearGradient(colors: [DsColors.gold400, DsColors.gold600])
        : context.primaryGradient;

    return Center(
      child: Container(
        padding: const EdgeInsets.all(DsSpacing.xxs),
        decoration: BoxDecoration(
          borderRadius: DsRadius.borderPill,
          color: colors.surface.withValues(alpha: 0.85),
          border: Border.all(color: colors.border.withValues(alpha: 0.7)),
          boxShadow: context.shadowSoft,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++)
                Semantics(
                  selected: i == selected,
                  button: true,
                  label: items[i].label,
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () => onSelect(i),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: DsMotion.moderate,
                      curve: DsMotion.gentle,
                      height: 44,
                      padding: EdgeInsets.symmetric(
                        horizontal: i == selected ? DsSpacing.md : DsSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: DsRadius.borderPill,
                        gradient: i == selected ? lit : null,
                        boxShadow: i == selected
                            ? context.glowShadow(
                                boutique ? DsColors.gold500 : colors.primary,
                                blur: 14,
                                alpha: 0.3,
                              )
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            items[i].icon,
                            size: DsSizes.iconSm,
                            color: i == selected
                                ? DsColors.onMedia
                                : colors.onSurfaceVariant,
                          ),
                          AnimatedSize(
                            duration: DsMotion.moderate,
                            curve: DsMotion.gentle,
                            child: i == selected
                                ? Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      start: DsSpacing.xs,
                                    ),
                                    child: Text(
                                      items[i].label,
                                      style: context.dsText.labelStrong
                                          .copyWith(color: DsColors.onMedia),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
