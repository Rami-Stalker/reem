import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../providers/admin_provider.dart';
import '../widgets/admin_page_header.dart';

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
                            value: '\$${stats?.totalSales.toStringAsFixed(0) ?? '0'}',
                            icon: Icons.payments_outlined,
                            trend: stats?.salesTrend ?? '+0%',
                            trendUp: true,
                            gradient: DsGradients.primarySoft,
                            index: 0,
                          ),
                          _StatCard(
                            label: l10n.adminTotalOrders,
                            value: '${stats?.totalOrders ?? 0}',
                            icon: Icons.shopping_bag_outlined,
                            trend: stats?.ordersTrend ?? '+0%',
                            trendUp: true,
                            gradient: DsGradients.sunset,
                            index: 1,
                          ),
                          _StatCard(
                            label: l10n.adminActiveUsers,
                            value: '${stats?.activeUsers ?? 0}',
                            icon: Icons.people_alt_outlined,
                            trend: stats?.usersTrend ?? '+0%',
                            trendUp: true,
                            gradient: DsGradients.accent,
                            index: 2,
                          ),
                          _StatCard(
                            label: l10n.adminConversion,
                            value: '${stats?.conversionRate.toStringAsFixed(1) ?? '0'}%',
                            icon: Icons.show_chart_rounded,
                            trend: stats?.conversionTrend ?? '+0%',
                            trendUp: stats?.conversionTrend != null && 
                                !(stats?.conversionTrend ?? '').startsWith('-'),
                            gradient: DsGradients.lavenderBlush,
                            index: 3,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: DsSpacing.xxl),

                  // Quick Actions
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: DsTypography.titleMedium,
                      fontWeight: DsTypography.bold,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: DsSpacing.md),
                  
                  Wrap(
                    spacing: DsSpacing.md,
                    runSpacing: DsSpacing.md,
                    children: [
                      _QuickActionButton(
                        icon: Icons.add_shopping_cart_rounded,
                        label: 'Add Product',
                        onPressed: () {},
                        index: 0,
                      ),
                      _QuickActionButton(
                        icon: Icons.receipt_long_rounded,
                        label: 'View Orders',
                        onPressed: () {},
                        index: 1,
                      ),
                      _QuickActionButton(
                        icon: Icons.people_rounded,
                        label: 'Manage Users',
                        onPressed: () {},
                        index: 2,
                      ),
                      _QuickActionButton(
                        icon: Icons.analytics_rounded,
                        label: 'Analytics',
                        onPressed: () {},
                        index: 3,
                      ),
                    ],
                  ),

                  const SizedBox(height: DsSpacing.xxl),

                  // Recent Activity
                  Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: DsTypography.titleMedium,
                      fontWeight: DsTypography.bold,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: DsSpacing.md),
                  
                  _RecentActivityCard(
                    title: 'New Order #10284',
                    subtitle: 'Sara M. ordered 3 items',
                    time: '2 minutes ago',
                    icon: Icons.shopping_bag_rounded,
                    index: 0,
                  ),
                  _RecentActivityCard(
                    title: 'New User Registered',
                    subtitle: 'Layla K. joined the platform',
                    time: '15 minutes ago',
                    icon: Icons.person_add_rounded,
                    index: 1,
                  ),
                  _RecentActivityCard(
                    title: 'Product Review',
                    subtitle: 'Nour A. reviewed "Silk Dress"',
                    time: '1 hour ago',
                    icon: Icons.star_rounded,
                    index: 2,
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
    required this.gradient,
    required this.index,
  });

  final String label;
  final String value;
  final IconData icon;
  final String trend;
  final bool trendUp;
  final Gradient gradient;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: DsRadius.borderXxl,
        boxShadow: context.softShadow,
        border: Border.all(color: colors.glassBorder),
      ),
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
                  gradient: gradient,
                  borderRadius: DsRadius.borderLg,
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: trendUp ? colors.success.withValues(alpha: 0.15) : colors.error.withValues(alpha: 0.15),
                  borderRadius: DsRadius.borderFull,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      trendUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 14,
                      color: trendUp ? colors.success : colors.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      trend,
                      style: TextStyle(
                        fontSize: DsTypography.labelSmall,
                        fontWeight: DsTypography.semiBold,
                        color: trendUp ? colors.success : colors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.md),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: DsTypography.bold,
              color: colors.onSurface,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: DsTypography.labelMedium,
              color: colors.onSurfaceVariant,
            ),
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
    final colors = context.dsColors;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg, vertical: DsSpacing.md),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: DsRadius.borderFull,
          boxShadow: context.softShadow,
          border: Border.all(color: colors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: colors.primary),
            const SizedBox(width: DsSpacing.sm),
            Text(
              label,
              style: TextStyle(
                fontWeight: DsTypography.semiBold,
                color: colors.onSurface,
                fontSize: DsTypography.labelLarge,
              ),
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
    final colors = context.dsColors;

    return Container(
      margin: const EdgeInsets.only(bottom: DsSpacing.sm),
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: DsRadius.borderXl,
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(DsSpacing.sm),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: DsRadius.borderLg,
            ),
            child: Icon(icon, size: 20, color: colors.primary),
          ),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: DsTypography.semiBold,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: DsTypography.labelSmall,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: DsTypography.labelSmall,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (100 * index).ms, duration: 300.ms).slideX(begin: -0.05);
  }
}