import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/patterns/reem_page_scaffold.dart';
import '../../../../core/shared/wedgets/app/premium_app_bar.dart';
import '../../../../core/shared/wedgets/app/reem_section_header.dart';
import '../widgets/favorite_product_card.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ReemScrollPage(
      slivers: [
        const PremiumAppBar(title: 'Wishlist'),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg, DsSpacing.sm, DsSpacing.lg, 120,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ReemSectionHeader(
                  title: 'Saved with love',
                  subtitle: '12 items waiting for you',
                ),
                const SizedBox(height: DsSpacing.lg),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => FavoriteProductCard(index: index),
              childCount: 10,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: DsSpacing.md,
              mainAxisSpacing: DsSpacing.md,
              childAspectRatio: 0.68,
            ),
          ),
        ),
      ],
    );
  }
}
