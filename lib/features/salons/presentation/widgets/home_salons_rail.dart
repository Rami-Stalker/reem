import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/home/presentation/widgets/home_section_header.dart';
import 'package:reem/features/salons/domain/entities/salon.dart';
import 'package:reem/features/salons/presentation/providers/salons_providers.dart';
import 'package:reem/features/salons/presentation/widgets/salon_card.dart';

/// «الصالونات والجمال» on the home page.
///
/// A rail rather than a banner, for the same reason the other sections are
/// rails: a picture of a salon she can book is a better invitation than a
/// coloured box telling her salons exist.
///
/// It draws **nothing at all** when the directory is empty or has not answered
/// — which is every build before a single salon is published — so an app
/// shipped ahead of the first salon has an unchanged home page rather than a
/// band of unexplained emptiness. That is the same contract `HomeFlashDeals`
/// and `DropsRail` keep, and `_SectionGap` on the home screen removes the gap
/// with it.
class HomeSalonsRail extends ConsumerWidget {
  const HomeSalonsRail({super.key});

  static const double _railHeight = 268;
  static const int _max = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The directory's own top page, sorted by the server. No second query and
    // no second notion of "featured": what leads the section here is what
    // leads «الصالونات والجمال» when she opens it, so tapping «الكل» does not
    // reshuffle the shelf she just looked at.
    final state = ref.watch(salonDirectoryProvider);
    final salons = state.salons.take(_max).toList(growable: false);

    if (salons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          eyebrow: context.l10n.salonBookYourAppointment,
          title: context.l10n.salonsTitle,
          subtitle: context.l10n.salonsRailSubtitle,
          onSeeAll: () => unawaited(context.push(RoutePaths.salons)),
        ),
        SizedBox(
          height: _railHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
            itemCount: salons.length,
            separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.md),
            itemBuilder: (context, index) => SizedBox(
              width: 232,
              child: _RailCard(salon: salons[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _RailCard extends StatelessWidget {
  const _RailCard({required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context) {
    return SalonCard(
      salon: salon,
      onTap: () => unawaited(context.push(RoutePaths.salonOf(salon.slug))),
    );
  }
}
