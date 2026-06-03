import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

class PremiumStats extends StatelessWidget {
  const PremiumStats({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: const [
        StatItem(number: '1.2K', title: 'Followers'),
        StatItem(number: '58', title: 'Posts'),
        StatItem(number: '320', title: 'Following'),
      ],
    );
  }
}

class StatItem extends StatelessWidget {
  const StatItem({super.key, required this.number, required this.title});

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Column(
      children: [
        DsGradientText(
          number,
          style: TextStyle(
            fontSize: 26,
            fontWeight: DsTypography.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: DsTypography.labelMedium,
          ),
        ),
      ],
    );
  }
}
