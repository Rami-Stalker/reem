import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/value_objects/money_format.dart';
import 'package:reem/features/admin/presentation/providers/admin_provider.dart';
import 'package:reem/features/admin/presentation/widgets/admin_briefing_panel.dart';
import 'package:reem/features/admin/presentation/widgets/admin_page_header.dart';

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
    final palette = context.console;
    final l10n = context.l10n;
    final state = ref.watch(adminDashboardNotifierProvider);
    final stats = state.stats;
    final audit = ref.watch(
      adminSectionNotifierProvider(adminSectionConfigs['audit']!),
    );

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
                // The header's action slot is content-sized; an expanding
                // button there asks for infinite width.
                isExpanded: false,
                onPressed: () => context.go(RoutePaths.adminReports),
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
              child: Text(
                state.error!,
                style: context.dsText.body.tint(palette.critical),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Grid
                  LayoutBuilder(
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
                        childAspectRatio: 1.8,
                        children: [
                          _StatCard(
                            label: l10n.adminTotalSales,
                            value: (stats?.totalSales ?? 0).sypCompact,
                            icon: Icons.payments_outlined,
                            trend: stats?.salesTrend ?? '+0%',
                            trendUp: true,
                            index: 0,
                          ),
                          _StatCard(
                            label: l10n.adminTotalOrders,
                            value: formatCount(stats?.totalOrders ?? 0),
                            icon: Icons.shopping_bag_outlined,
                            trend: stats?.ordersTrend ?? '+0%',
                            trendUp: true,
                            index: 1,
                          ),
                          _StatCard(
                            label: l10n.adminActiveUsers,
                            value: formatCount(stats?.activeUsers ?? 0),
                            icon: Icons.people_alt_outlined,
                            trend: stats?.usersTrend ?? '+0%',
                            trendUp: true,
                            index: 2,
                          ),
                          _StatCard(
                            label: l10n.adminConversion,
                            value: '${stats?.conversionRate.toStringAsFixed(1) ?? '0'}%',
                            icon: Icons.show_chart_rounded,
                            trend: stats?.conversionTrend ?? '+0%',
                            trendUp: stats?.conversionTrend != null && 
                                !(stats?.conversionTrend ?? '').startsWith('-'),
                            index: 3,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: DsSpacing.xxl),

                  // What the marketplace thinks needs a person today. Above
                  // the quick actions on purpose: the counters say how the
                  // month went, this says what to do about it.
                  const AdminBriefingPanel(),

                  const SizedBox(height: DsSpacing.xxl),

                  // Quick Actions
                  Text(
                    l10n.adminQuickActions,
                    style: context.dsText.cardTitle.bold.tint(palette.ink),
                  ),
                  const SizedBox(height: DsSpacing.md),
                  
                  Wrap(
                    spacing: DsSpacing.md,
                    runSpacing: DsSpacing.md,
                    children: [
                      _QuickActionButton(
                        icon: Icons.storefront_rounded,
                        label: l10n.adminSellerReview,
                        onPressed: () => context.go(RoutePaths.adminSellers),
                        index: 0,
                      ),
                      _QuickActionButton(
                        icon: Icons.support_agent_rounded,
                        label: l10n.adminSupportQueue,
                        onPressed: () => context.go(RoutePaths.adminSupport),
                        index: 1,
                      ),
                      _QuickActionButton(
                        icon: Icons.campaign_rounded,
                        label: l10n.adminCampaigns,
                        onPressed: () => context.go(RoutePaths.adminCampaigns),
                        index: 2,
                      ),
                      _QuickActionButton(
                        icon: Icons.account_balance_rounded,
                        label: l10n.adminFinancials,
                        onPressed: () => context.go(RoutePaths.adminFinancials),
                        index: 3,
                      ),
                      _QuickActionButton(
                        icon: Icons.gavel_rounded,
                        label: l10n.adminModeration,
                        onPressed: () => context.go(RoutePaths.adminModeration),
                        index: 4,
                      ),
                      _QuickActionButton(
                        icon: Icons.query_stats_rounded,
                        label: l10n.adminNotifyAnalytics,
                        onPressed: () =>
                            context.go(RoutePaths.adminNotificationAnalytics),
                        index: 5,
                      ),
                    ],
                  ),

                  const SizedBox(height: DsSpacing.xxl),

                  // Recent Activity
                  Text(
                    l10n.adminRecentActivity,
                    style: context.dsText.cardTitle.bold.tint(palette.ink),
                  ),
                  const SizedBox(height: DsSpacing.md),
                  
                  if (audit.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(DsSpacing.lg),
                      child: Center(child: DsLoadingIndicator()),
                    )
                  else if (audit.error != null)
                    _RecentActivityCard(
                      title: l10n.adminAuditUnavailable,
                      subtitle: audit.error!,
                      time: l10n.adminRetryFromAudit,
                      icon: Icons.warning_amber_rounded,
                      index: 0,
                    )
                  else if (audit.records.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(DsSpacing.lg),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: DsRadius.borderSm,
                        border: Border.all(color: palette.line),
                      ),
                      child: Text(
                        l10n.adminNoRecentActivity,
                        style: context.dsText.body.tint(palette.muted),
                      ),
                    )
                  else
                    Column(
                      children: [
                        for (final entry
                            in audit.records.take(5).toList().asMap().entries)
                          _RecentActivityCard(
                            title: entry.value.title,
                            subtitle: entry.value.subtitle,
                            time:
                                entry.value.metrics['created_at'] ??
                                entry.value.status,
                            icon: Icons.manage_search_rounded,
                            index: entry.key,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          const SizedBox(height: DsSpacing.xxxl),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.trend,
    required this.trendUp,
    required this.index,
  });

  final String label;
  final String value;
  final IconData icon;
  final String trend;
  final bool trendUp;
  final int index;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final trendColor =
        trendUp ? palette.positive : palette.critical;

    return AdminPanel(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(DsSpacing.sm),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: .1),
                  borderRadius: DsRadius.borderSm,
                ),
                child: Icon(icon, color: palette.primary, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xs, vertical: DsSpacing.xxs),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.1),
                  borderRadius: DsRadius.borderSm,
                  border: Border.all(color: trendColor.withValues(alpha: .18)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      trendUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 14,
                      color: trendColor,
                    ),
                    DsGaps.hXxs,
                    Text(
                      trend,
                      style: context.dsText.caption.semibold.tint(trendColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.md),
          Text(
            value,
            style: context.dsText.pageTitle.bold.tint(palette.ink).copyWith(height: 1.2),
          ),
          DsGaps.vXxs,
          Text(
            label,
            style: context.dsText.labelMedium.tint(palette.muted),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (100 * index).ms, duration: 400.ms).slideY(begin: 0.1);
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.index,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final int index;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg, vertical: DsSpacing.md),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: DsRadius.borderSm,
          boxShadow: palette.shadow,
          border: Border.all(color: palette.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: palette.primary),
            const SizedBox(width: DsSpacing.sm),
            Text(
              label,
              style: context.dsText.labelLarge.tint(palette.ink),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (80 * index).ms, duration: 300.ms).scale(begin: const Offset(0.95, 0.95));
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.index,
  });

  final String title;
  final String subtitle;
  final String time;
  final IconData icon;
  final int index;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    return Container(
      margin: const EdgeInsets.only(bottom: DsSpacing.sm),
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: DsRadius.borderSm,
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(DsSpacing.sm),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: DsRadius.borderSm,
            ),
            child: Icon(icon, size: 20, color: palette.primary),
          ),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.dsText.body.semibold.tint(palette.ink),
                ),
                DsGaps.vXxxs,
                Text(
                  subtitle,
                  style: context.dsText.caption.tint(palette.muted),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: context.dsText.caption.tint(palette.muted),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (100 * index).ms, duration: 300.ms).slideX(begin: -0.05);
  }
}
