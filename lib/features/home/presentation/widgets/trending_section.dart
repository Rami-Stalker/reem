import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import 'luxury_post_card.dart';

class TrendingSection extends StatelessWidget {
  const TrendingSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReemSectionHeader(
          title: l10n.trendingNow,
          subtitle: l10n.trendingSubtitle,
        ),
        const SizedBox(height: DsSpacing.lg),
        SizedBox(
          height: 300,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(width: DsSpacing.lg),
            itemBuilder: (context, index) {
              return LuxuryPostCard(
                image:
                    'https://images.unsplash.com/photo-1524504388940-b1c1722653e1',
                title: 'Silk Evening Dress',
                likes: '${(index + 2) * 3}K',
                comments: '${(index + 1) * 120}',
              );
            },
          ),
        ),
      ],
    );
  }
}
