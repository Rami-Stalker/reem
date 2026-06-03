import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

class PremiumActions extends StatelessWidget {
  const PremiumActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: PrimaryButton(
              label: 'Edit Profile',
              size: DsButtonSize.md,
              isExpanded: false,
              onPressed: () {},
            ),
          ),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: SecondaryButton(
              label: 'Share',
              size: DsButtonSize.md,
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}
