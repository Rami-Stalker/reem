import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/patterns/reem_page_scaffold.dart';
import '../../../../core/shared/wedgets/app/premium_app_bar.dart';
import '../../../../core/shared/wedgets/app/reem_section_header.dart';
import '../widgets/address_card.dart';

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ReemScrollPage(
      slivers: [
        const PremiumAppBar(title: 'My Addresses', showBack: true),
        SliverPadding(
          padding: const EdgeInsets.all(DsSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const ReemSectionHeader(
                title: 'Delivery addresses',
                subtitle: 'Where should we send your goodies?',
              ),
              const SizedBox(height: DsSpacing.lg),
              for (var i = 0; i < 4; i++) ...[
                AddressCard(index: i),
                const SizedBox(height: DsSpacing.md),
              ],
              const SizedBox(height: DsSpacing.md),
              SecondaryButton(label: 'Add new address', onPressed: () {}),
            ]),
          ),
        ),
      ],
    );
  }
}
