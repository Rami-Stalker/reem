import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../widgets/admin_page_header.dart';
import '../widgets/admin_stat_card.dart';

class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: l10n.adminAnalytics,
            subtitle: l10n.adminViewReports,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xl),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: DsSpacing.md,
              crossAxisSpacing: DsSpacing.md,
              childAspectRatio: 2.2,
              children: [
                AdminStatCard(
                  label: l10n.adminConversion,
                  value: '4.8%',
                  icon: Icons.percent_rounded,
                  trend: '+0.6%',
                ),
                AdminStatCard(
                  label: l10n.adminTotalSales,
                  value: '\$12.4k',
                  icon: Icons.calendar_month_outlined,
                  trend: '+18%',
                ),
              ],
            ),
          ),
          const SizedBox(height: DsSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xl),
            child: Container(
              height: 280,
              padding: const EdgeInsets.all(DsSpacing.lg),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: DsRadius.borderLg,
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.adminViewReports,
                    style: TextStyle(
                      fontWeight: DsTypography.bold,
                      fontSize: DsTypography.titleMedium,
                    ),
                  ),
                  const SizedBox(height: DsSpacing.lg),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(12, (i) {
                        final height = 40.0 + (i % 5) * 28;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Container(
                              height: height,
                              decoration: BoxDecoration(
                                gradient: context.primaryGradient,
                                borderRadius: DsRadius.borderSm,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: DsSpacing.xxxl),
        ],
      ),
    );
  }
}
