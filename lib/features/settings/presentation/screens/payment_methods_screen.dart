import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/patterns/reem_page_scaffold.dart';
import '../../../../core/shared/wedgets/app/premium_app_bar.dart';
import '../../../../core/shared/wedgets/app/reem_section_header.dart';
import '../widgets/payment_card.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ReemScrollPage(
      slivers: [
        const PremiumAppBar(title: 'Payment Methods', showBack: true),
        SliverPadding(
          padding: const EdgeInsets.all(DsSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const ReemSectionHeader(
                title: 'Secure checkout',
                subtitle: 'Manage cards & wallets',
              ),
              const SizedBox(height: DsSpacing.lg),
              for (var i = 0; i < 3; i++) ...[
                PaymentCard(index: i),
                const SizedBox(height: DsSpacing.md),
              ],
              const SizedBox(height: DsSpacing.md),
              PrimaryButton(label: 'Add payment method', onPressed: () {}),
            ]),
          ),
        ),
      ],
    );
  }
}
