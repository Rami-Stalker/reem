import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/patterns/reem_page_scaffold.dart';
import '../../../../core/shared/wedgets/app/premium_app_bar.dart';
import '../../../../core/shared/wedgets/app/reem_section_header.dart';
class CouponsScreen extends StatelessWidget {
  const CouponsScreen({super.key});

  static const _coupons = [
    ('SUMMER20', '20% off entire order', 'Min. \$50'),
    ('GLOW15', '15% off beauty', 'Expires in 3 days'),
    ('FREESHIP', 'Free shipping', 'No minimum'),
    ('VIP25', '25% VIP exclusive', 'Members only'),
  ];

  @override
  Widget build(BuildContext context) {
    return ReemScrollPage(
      slivers: [
        const PremiumAppBar(title: 'Coupons', showBack: true),
        SliverPadding(
          padding: const EdgeInsets.all(DsSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const ReemSectionHeader(
                title: 'Your offers',
                subtitle: 'Tap to copy code at checkout',
              ),
              const SizedBox(height: DsSpacing.lg),
              for (var i = 0; i < _coupons.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: DsSpacing.md),
                  child: _CouponTicket(
                    code: _coupons[i].$1,
                    title: _coupons[i].$2,
                    subtitle: _coupons[i].$3,
                    index: i,
                  ),
                ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _CouponTicket extends StatelessWidget {
  const _CouponTicket({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.index,
  });

  final String code;
  final String title;
  final String subtitle;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: code));
        DsSnackbar.show(
          context,
          message: 'Coupon $code copied!',
          type: DsSnackbarType.success,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: DsRadius.borderXxl,
          gradient: index.isEven ? context.primaryGradient : DsGradients.rewards,
          boxShadow: context.luxuryShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(DsSpacing.lg),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.onPrimary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.local_offer_rounded, color: colors.onPrimary),
              ),
              const SizedBox(width: DsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      code,
                      style: TextStyle(
                        fontFamily: DsTypography.fontFamily,
                        fontSize: DsTypography.titleLarge,
                        fontWeight: DsTypography.bold,
                        color: colors.onPrimary,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.onPrimary.withValues(alpha: 0.92),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.onPrimary.withValues(alpha: 0.75),
                        fontSize: DsTypography.labelSmall,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.copy_rounded, color: colors.onPrimary),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (80 * index).ms).slideX(begin: 0.08);
  }
}
