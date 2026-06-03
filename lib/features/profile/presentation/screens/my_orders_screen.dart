import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/patterns/reem_page_scaffold.dart';
import '../../../../core/shared/wedgets/app/premium_app_bar.dart';
import '../../../../core/shared/wedgets/app/reem_section_header.dart';
import '../widgets/order_card.dart';

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ReemScrollPage(
      slivers: [
        const PremiumAppBar(title: 'My Orders', showBack: true),
        SliverPadding(
          padding: const EdgeInsets.all(DsSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const ReemSectionHeader(
                title: 'Your orders',
                subtitle: 'Track, review & reorder',
              ),
              const SizedBox(height: DsSpacing.lg),
              for (var i = 0; i < 6; i++) ...[
                OrderCard(index: i),
                const SizedBox(height: DsSpacing.md),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}
