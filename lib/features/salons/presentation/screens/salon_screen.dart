import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/services/share_links.dart';
import 'package:reem/core/shared/services/share_service.dart';
import 'package:reem/features/chat/domain/entities/chat_start_request.dart';
import 'package:reem/features/chat/presentation/widgets/message_seller_button.dart';
import 'package:reem/features/salons/domain/entities/salon.dart';
import 'package:reem/features/salons/presentation/providers/salons_providers.dart';
import 'package:reem/features/salons/presentation/widgets/salon_labels.dart';
import 'package:reem/features/salons/presentation/widgets/salon_service_tile.dart';
import 'package:url_launcher/url_launcher.dart';

/// One salon's page.
///
/// Deliberately shaped like a boutique's page, because it answers the same
/// question in the same order: who are you, where are you, what do you do and
/// what does it cost, what do people say — and one obvious way to act.
class SalonScreen extends ConsumerWidget {
  const SalonScreen({super.key, required this.salonId});

  /// An id or a slug. A shared link carries the slug.
  final String salonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.dsColors;
    final async = ref.watch(salonProvider(salonId));

    return Scaffold(
      backgroundColor: c.background,
      body: async.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          title: 'ما لقينا هالصالون',
          message: 'يمكن يكون أُغلق أو ما عاد متاح.',
          onRetry: () => ref.invalidate(salonProvider(salonId)),
        ),
        data: (salon) => _Body(salon: salon),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.dsColors;
    final reviews = ref.watch(salonReviewsProvider(salon.id));

    return CustomScrollView(
      slivers: [
        _Header(salon: salon),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.md,
            DsSpacing.lg,
            DsSpacing.xxxl,
          ),
          sliver: SliverList.list(
            children: [
              _Identity(salon: salon),
              DsGaps.vMd,
              _Actions(salon: salon),
              DsGaps.vLg,

              if (salon.about != null && salon.about!.trim().isNotEmpty) ...[
                Text(
                  salon.about!,
                  style: context.dsText.body
                      .tint(c.onSurfaceVariant)
                      .copyWith(height: 1.7),
                ),
                DsGaps.vLg,
              ],

              _SectionTitle('الخدمات'),
              if (salon.services.isEmpty)
                DsEmptyState(
                  icon: Icons.spa_outlined,
                  title: 'لسّا ما أضاف الصالون خدماته',
                  message: 'راسليه لتعرفي شو بيقدّم.',
                )
              else
                // Grouped by category, because a menu of thirty services with
                // no headings is a menu nobody reads to the bottom of.
                ...salon.categories.expand(
                  (category) => [
                    DsGaps.vSm,
                    Text(
                      SalonLabels.category(category),
                      style: context.dsText.labelLarge.semibold.tint(c.primary),
                    ),
                    DsGaps.vXs,
                    ...salon.services
                        .where((service) => service.category == category)
                        .map(
                          (service) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: DsSpacing.sm,
                            ),
                            child: SalonServiceTile(
                              service: service,
                              onBook: () => context.push(
                                RoutePaths.salonBookingOf(
                                  salon.id,
                                  service.id,
                                ),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),

              DsGaps.vLg,
              _SectionTitle('أوقات العمل'),
              _Hours(salon: salon),

              DsGaps.vLg,
              _SectionTitle('الموقع'),
              _Location(salon: salon),

              DsGaps.vLg,
              _SectionTitle(
                salon.hasBeenReviewed
                    ? 'التقييمات (${salon.reviewsCount})'
                    : 'التقييمات',
              ),
              reviews.when(
                loading: () => const DsLoadingIndicator(),
                error: (_, _) => const SizedBox.shrink(),
                data: (page) => page.items.isEmpty
                    ? Text(
                        'لسّا ما في تقييمات. كوني أول وحدة تجرّبي وتقيّمي.',
                        style: context.dsText.cardSubtitle.tint(
                          c.onSurfaceVariant,
                        ),
                      )
                    : Column(
                        children: [
                          for (final review in page.items)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: DsSpacing.sm,
                              ),
                              child: _ReviewCard(review: review),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: DsSpacing.xs),
    child: Text(
      title,
      style: context.dsText.sectionTitle.tint(context.dsColors.onSurface),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final url = salon.coverUrl ?? salon.logoUrl;

    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: c.surface,
      leading: const _GlassBack(),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null && url.isNotEmpty)
              AuthorizedMediaImage(url: url)
            else
              DecoratedBox(
                decoration: BoxDecoration(gradient: context.primaryGradient),
              ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: context.imageScrim),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassBack extends StatelessWidget {
  const _GlassBack();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(DsSpacing.xs),
    child: DsIconButton(
      icon: Icons.arrow_back_rounded,
      tooltip: context.l10n.a11yBack,
      variant: DsIconButtonVariant.glass,
      onPressed: () => context.canPop()
          ? context.pop()
          : context.go(RoutePaths.salons),
    ),
  );
}

class _Identity extends StatelessWidget {
  const _Identity({required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                salon.name,
                style: context.dsText.screenTitle.tint(c.onSurface),
              ),
            ),
            if (salon.hasBeenReviewed) ...[
              Icon(Icons.star_rounded, size: 18, color: c.warning),
              DsGaps.hXxxs,
              Text(
                salon.rating.toStringAsFixed(1),
                style: context.dsText.body.semibold.tint(c.onSurface),
              ),
            ],
          ],
        ),
        if (salon.tagline != null && salon.tagline!.isNotEmpty) ...[
          DsGaps.vXxs,
          Text(
            salon.tagline!,
            style: context.dsText.cardSubtitle.tint(c.onSurfaceVariant),
          ),
        ],
        DsGaps.vXs,
        Wrap(
          spacing: DsSpacing.xs,
          runSpacing: DsSpacing.xxs,
          children: [
            DsChip(label: salon.area, icon: Icons.place_outlined),
            if (salon.homeService)
              DsChip(
                label: 'خدمة منزلية',
                icon: Icons.home_outlined,
                selected: true,
              ),
            if (salon.servicesCount > 0)
              DsChip(
                label: '${salon.servicesCount} خدمة',
                icon: Icons.spa_outlined,
              ),
          ],
        ),
      ],
    );
  }
}

/// What she can do from here, in the order she is likely to want it.
class _Actions extends StatelessWidget {
  const _Actions({required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // A salon has no inbox of its own: a question about an appointment
        // goes to the woman who runs it, through `MessageSellerButton` and the
        // chat that already exists. No second messaging system.
        if (salon.owner != null)
          Expanded(
            child: MessageSellerButton(
              label: 'راسلي الصالون',
              variant: DsButtonVariant.tonal,
              request: ChatStartRequest.peer(peerId: salon.owner!.id),
            ),
          ),
        if (salon.phone != null && salon.phone!.isNotEmpty) ...[
          const SizedBox(width: DsSpacing.sm),
          DsIconButton(
            icon: Icons.call_outlined,
            tooltip: 'اتصلي',
            variant: DsIconButtonVariant.surface,
            onPressed: () => _launch('tel:${salon.phone}'),
          ),
        ],
        const SizedBox(width: DsSpacing.sm),
        DsIconButton(
          icon: Icons.ios_share_rounded,
          tooltip: 'مشاركة',
          variant: DsIconButtonVariant.surface,
          // Through the same registry every other share uses, so a salon link
          // previews in WhatsApp and opens the app exactly as a product link
          // does. The slug travels, not the id.
          onPressed: () => unawaited(
            ShareService.link(
              context: context,
              url: ShareLinks.salon(salon.slug),
              text: '${salon.name} — ${salon.area}',
              imageUrl: salon.coverUrl ?? salon.logoUrl,
            ),
          ),
        ),
      ],
    );
  }
}

/// «عرض الموقع والخريطة للصالون».
///
/// Opened in whichever maps app she has, rather than drawn here. There is no
/// map SDK in this project and adding one would drag in an API key, a billing
/// account and a native dependency for a single screen — while `url_launcher`
/// is already used for exactly this by the courier's round.
class _Location extends StatelessWidget {
  const _Location({required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return SurfaceCard(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.place_rounded, size: 18, color: c.primary),
              const SizedBox(width: DsSpacing.xs),
              Expanded(
                child: Text(
                  salon.fullAddress,
                  style: context.dsText.body.tint(c.onSurface),
                ),
              ),
            ],
          ),
          DsGaps.vSm,
          DsButton(
            label: 'افتحي على الخريطة',
            icon: Icons.map_outlined,
            variant: DsButtonVariant.tonal,
            size: DsButtonSize.md,
            onPressed: () => _launch(_mapsUrl),
          ),
        ],
      ),
    );
  }

  /// A dropped pin when there is one, otherwise a search for the written
  /// address — which still lands her in the right street.
  String get _mapsUrl => salon.hasCoordinates
      ? 'https://www.google.com/maps/search/?api=1&query='
            '${salon.latitude},${salon.longitude}'
      : 'https://www.google.com/maps/search/?api=1&query='
            '${Uri.encodeComponent(salon.fullAddress)}';
}

class _Hours extends StatelessWidget {
  const _Hours({required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    if (salon.hours.isEmpty) {
      return Text(
        'ما حدّد الصالون أوقات عمله بعد.',
        style: context.dsText.cardSubtitle.tint(c.onSurfaceVariant),
      );
    }

    final today = DateTime.now().weekday % 7;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.md,
        vertical: DsSpacing.xs,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final day in salon.hours)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      SalonLabels.weekday(day.weekday),
                      style: day.weekday == today
                          ? context.dsText.body.semibold.tint(c.primary)
                          : context.dsText.body.tint(c.onSurface),
                    ),
                  ),
                  Text(
                    day.isClosed
                        ? 'مغلق'
                        : day.hasBreak
                        ? '${day.opensAt}–${day.breakStartsAt} · '
                              '${day.breakEndsAt}–${day.closesAt}'
                        : '${day.opensAt} – ${day.closesAt}',
                    style: context.dsText.cardSubtitle.tint(
                      day.isClosed ? c.onSurfaceVariant : c.onSurface,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final SalonReview review;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return SurfaceCard(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.user?.name ?? 'عميلة',
                  style: context.dsText.tileTitle.semibold.tint(c.onSurface),
                ),
              ),
              for (var star = 1; star <= 5; star += 1)
                Icon(
                  star <= review.rating
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 15,
                  color: c.warning,
                ),
            ],
          ),
          // Every rating here is verified by construction — only a completed
          // appointment can produce one — so it is stated rather than implied.
          DsGaps.vXxxs,
          Text(
            'زيارة مؤكّدة',
            style: context.dsText.micro.tint(c.success),
          ),
          if (review.body != null && review.body!.isNotEmpty) ...[
            DsGaps.vXs,
            Text(
              review.body!,
              style: context.dsText.body.tint(c.onSurfaceVariant),
            ),
          ],
          if (review.salonReply != null && review.salonReply!.isNotEmpty) ...[
            DsGaps.vSm,
            Container(
              padding: const EdgeInsets.all(DsSpacing.sm),
              decoration: BoxDecoration(
                color: c.surfaceVariant,
                borderRadius: DsRadius.borderMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ردّ الصالون',
                    style: context.dsText.micro.semibold.tint(c.primary),
                  ),
                  DsGaps.vXxxs,
                  Text(
                    review.salonReply!,
                    style: context.dsText.cardSubtitle.tint(c.onSurface),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _launch(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
