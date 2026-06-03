import 'package:flutter/material.dart';

import 'luxury_post_card.dart';

class LuxuryPostGrid
    extends StatelessWidget {
  const LuxuryPostGrid({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 18,
      ),

      sliver: SliverGrid(
        delegate:
            SliverChildBuilderDelegate(
          (context, index) {
            return LuxuryPostCard(
              index: index,
            );
          },
          childCount: 12,
        ),

        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 18,
          crossAxisSpacing: 18,
          childAspectRatio: .72,
        ),
      ),
    );
  }
}