import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../providers/admin_provider.dart';
import '../widgets/admin_page_header.dart';
import '../widgets/admin_stat_card.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminDashboardNotifierProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final state = ref.watch(adminDashboardNotifierProvider);
    final stats = state.stats;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: l10n.adminDashboard,
            subtitle: l10n.adminWelcome,
            actions: [
              PrimaryButton(
                label: l10n.adminViewReports,
                onPressed: () {},
              ),
            ],
          ),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.all(DsSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(DsSpacing.xl),
              child: Text(state.error!, style: TextStyle(color: colors.error)),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xl),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossCount = constraints.maxWidth > 1100
                      ? 4
                      : constraints.maxWidth > 700
                          ? 2
                          : 1;
                  return GridView.count(
                    crossAxisCount: crossCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: DsSpacing.md,
                    crossAxisSpacing: DsSpacing.md,
                    childAspectRatio: 1.6,
                    children: [
                      AdminStatCard(
                        label: l10n.adminTotalSales,
                        value: '\$${stats?.totalSales.toStringAsFixed(0) ?? '0'}',
                        icon: Icons.payments_outlined,
                        trend: stats?.salesTrend ?? '+0%',
                      ),
                      AdminStatCard(
                        label: l10n.adminTotalOrders,
                        value: '${stats?.totalOrders ?? 0}',
                        icon: Icons.shopping_bag_outlined,
                        trend: stats?.ordersTrend ?? '+0%',
                      ),
                      AdminStatCard(
                        label: l10n.adminActiveUsers,
                        value: '${stats?.activeUsers ?? 0}',
                        icon: Icons.people_alt_outlined,
                        trend: stats?.usersTrend ?? '+0%',
                      ),
                      AdminStatCard(
                        label: l10n.adminConversion,
                        value: '${stats?.conversionRate.toStringAsFixed(1) ?? '0'}%',
                        icon: Icons.show_chart_rounded,
                        trend: stats?.conversionTrend ?? '+0%',
                        trendUp: false,
                      ),
                    ],
                  );
                },
              ),
            ),
          const SizedBox(height: DsSpacing.xxxl),
        ],
      ),
    );
  }
}
