import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/auth/app_permissions.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/shared/value_objects/money_format.dart';
import 'package:ohara/core/utils/relative_time.dart';
import 'package:ohara/features/admin/data/models/admin_briefing_model.dart';
import 'package:ohara/features/admin/domain/entities/admin_stats_entity.dart';
import 'package:ohara/features/admin/presentation/providers/admin_provider.dart';
import 'package:ohara/features/admin/presentation/widgets/admin_briefing_panel.dart';
import 'package:ohara/features/admin/presentation/widgets/admin_jump_palette.dart';
import 'package:ohara/features/experience/presentation/providers/role_experience_provider.dart';

/// The console's home: **the courtyard**.
///
/// Laid out in the order an operator's morning goes. The sky says good
/// morning, says in one sentence whether anything needs her, and holds the
/// field that takes her to any section. Under it, the agenda puts the single
/// most important thing first. The doors show where people are waiting — a
/// lit door has a queue behind it. The rose shows the shape of the month, and
/// the thread what has happened since she last looked.
///
/// On a wide screen the work (agenda, doors) and the reading (rose, thread)
/// stand side by side; on a phone they stack, work first.
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

  Future<void> _refresh() async {
    ref.invalidate(adminBriefingProvider);
    for (final key in adminQueueSummaryKeys.keys) {
      ref.invalidate(adminQueueDepthProvider(key));
    }
    unawaited(
      ref
          .read(
            adminSectionNotifierProvider(
              adminSectionConfigs['audit']!,
            ).notifier,
          )
          .load(),
    );
    await ref.read(adminDashboardNotifierProvider.notifier).load();
  }

  void _openJump() {
    final destinations = adminJumpDestinations(
      ref.read(currentPermissionsProvider),
      context.l10n,
    );
    showAdminJumpPalette(context, destinations);
  }

  @override
  Widget build(BuildContext context) {
    // Ctrl/⌘ K is the shell's, so it works on every page, not only here.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= 1000;
        final gutter = width < 600 ? DsSpacing.md : DsSpacing.xl;

        final work = [const AdminBriefingPanel(), DsGaps.vXxl, const _Doors()];
        final reading = [const _Pulse(), DsGaps.vXxl, const _Thread()];

        return RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              gutter,
              gutter,
              gutter,
              DsSpacing.massive,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Sky(
                  compact: width < 600,
                  onJump: _openJump,
                  onRefresh: _refresh,
                ),
                DsGaps.vXxl,
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: work,
                        ),
                      ),
                      DsGaps.hXxl,
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: reading,
                        ),
                      ),
                    ],
                  )
                else ...[
                  ...work,
                  DsGaps.vXxl,
                  ...reading,
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// The sky: greeting, state of the house, the jump field
// ---------------------------------------------------------------------------

class _Sky extends ConsumerWidget {
  const _Sky({
    required this.compact,
    required this.onJump,
    required this.onRefresh,
  });

  final bool compact;
  final VoidCallback onJump;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.console;
    final name = ref.watch(adminOperatorNameProvider);
    final briefing = ref.watch(adminBriefingProvider);
    final now = DateTime.now();

    final greeting = now.hour < 12
        ? l10n.adminCourtGreetingMorning
        : l10n.adminCourtGreetingEvening;
    final heading = name == null
        ? greeting
        : l10n.adminCourtGreetingNamed(greeting, name);

    // The state of the house, in one sentence and one seal.
    final (Color seal, String sentence, int urgent) = briefing.when(
      loading: () => (DsColors.onMediaMuted, l10n.adminWelcome, 0),
      error: (_, _) => (palette.caution, l10n.adminCourtStateUnknown, 0),
      data: (data) => data.quiet || data.findings.isEmpty
          ? (palette.positive, l10n.adminCourtStateCalm, 0)
          : (
              data.findings.any((f) => f.severity == FindingSeverity.critical)
                  ? palette.critical
                  : palette.caution,
              l10n.adminCourtStateWaiting(data.findings.length),
              data.findings
                  .where((f) => f.severity == FindingSeverity.critical)
                  .length,
            ),
    );

    return CourtSky(
      padding: compact ? DsSpacing.paddingLg : DsSpacing.paddingXxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            MaterialLocalizations.of(context).formatFullDate(now),
            style: context.dsText.overline.tint(DsColors.onMediaMuted),
          ),
          DsGaps.vSm,
          Text(
            heading,
            style: (compact ? context.dsText.pageTitle : context.dsText.hero)
                .displayFamily
                .bold
                .tint(DsColors.onMedia),
          ),
          DsGaps.vSm,
          Wrap(
            spacing: DsSpacing.sm,
            runSpacing: DsSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Seal(color: seal),
              Text(
                sentence,
                style: context.dsText.bodyLarge.tint(DsColors.onMediaMuted),
              ),
              if (urgent > 0)
                Container(
                  padding: DsSpacing.pillPadding,
                  decoration: BoxDecoration(
                    color: palette.critical.withValues(alpha: 0.22),
                    borderRadius: DsRadius.borderPill,
                    border: Border.all(
                      color: palette.critical.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    l10n.adminCourtStateUrgent(urgent),
                    style: context.dsText.captionStrong.tint(DsColors.onMedia),
                  ),
                ),
            ],
          ),
          SizedBox(height: compact ? DsSpacing.lg : DsSpacing.xxl),
          // The jump field, and beside it the two things she does from here
          // without going anywhere: read the house again, or open reports.
          Row(
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: DsSizes.maxContentWidth,
                  ),
                  child: _JumpField(onTap: onJump, showKey: !compact),
                ),
              ),
              DsGaps.hSm,
              _SkyButton(
                icon: Icons.refresh_rounded,
                tooltip: l10n.refresh,
                onPressed: onRefresh,
              ),
              DsGaps.hXs,
              _SkyButton(
                icon: Icons.assessment_outlined,
                tooltip: l10n.adminViewReports,
                onPressed: () => context.push(RoutePaths.adminReports),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The state seal: a lit dot in the colour of the day.
class _Seal extends StatelessWidget {
  const _Seal({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: DsSpacing.sm,
      height: DsSpacing.sm,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: DsColors.onMedia.withValues(alpha: 0.6)),
        boxShadow: context.glowShadow(color, blur: 12, alpha: 0.8),
      ),
    );
  }
}

class _SkyButton extends StatelessWidget {
  const _SkyButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: Material(
          color: DsColors.mediaPlate,
          shape: const CircleBorder(
            side: BorderSide(color: DsColors.onMediaFaint),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox.square(
              dimension: DsSizes.controlMd,
              child: Icon(icon, size: DsSizes.iconSm, color: DsColors.onMedia),
            ),
          ),
        ),
      ),
    );
  }
}

/// «إلى أين؟» — a frosted field on the sky that opens the jump palette.
class _JumpField extends StatelessWidget {
  const _JumpField({required this.onTap, required this.showKey});

  final VoidCallback onTap;
  final bool showKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: l10n.adminCourtJumpHint,
      excludeSemantics: true,
      child: Material(
        color: DsColors.onMedia.withValues(alpha: 0.1),
        shape: const StadiumBorder(
          side: BorderSide(color: DsColors.onMediaFaint),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: DsSizes.fieldHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DsSpacing.lg,
                vertical: DsSpacing.sm,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.travel_explore_rounded,
                    size: DsSizes.iconSm,
                    color: DsColors.gold200,
                  ),
                  DsGaps.hSm,
                  Expanded(
                    child: Text(
                      l10n.adminCourtJumpHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.body.tint(DsColors.onMediaMuted),
                    ),
                  ),
                  if (showKey) ...[
                    DsGaps.hSm,
                    // l10n-ignore: a key cap names the keys printed on the keyboard
                    const CourtKeyCap(label: 'Ctrl K'),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section heading
// ---------------------------------------------------------------------------

class _Heading extends StatelessWidget {
  const _Heading({required this.title, this.caption, this.trailing});

  final String title;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.dsText.sectionTitle.bold.tint(palette.ink),
              ),
              if (caption != null) ...[
                DsGaps.vXxs,
                Text(
                  caption!,
                  style: context.dsText.cardSubtitle.tint(palette.muted),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The doors
// ---------------------------------------------------------------------------

@immutable
class _DoorSpec {
  const _DoorSpec({
    required this.icon,
    required this.label,
    required this.path,
    required this.permission,
    this.queue,
  });

  final IconData icon;
  final String Function(BuildContext) label;
  final String path;
  final String permission;

  /// The section whose backlog lights this door. Null for a room with no
  /// queue — finance is somewhere she goes, not something that waits.
  final String? queue;
}

final _doors = <_DoorSpec>[
  _DoorSpec(
    icon: Icons.assignment_ind_rounded,
    label: (c) => c.l10n.adminSellerApplications,
    path: RoutePaths.adminSellerApplications,
    permission: AppPermissions.sellerVerificationReview,
    queue: 'sellerApplications',
  ),
  _DoorSpec(
    icon: Icons.verified_user_rounded,
    label: (c) => c.l10n.adminAccountVerifications,
    path: RoutePaths.adminAccountVerifications,
    permission: AppPermissions.userManage,
    queue: 'accountVerifications',
  ),
  _DoorSpec(
    icon: Icons.gavel_rounded,
    label: (c) => c.l10n.adminModeration,
    path: RoutePaths.adminModeration,
    permission: AppPermissions.contentModerate,
    queue: 'moderation',
  ),
  _DoorSpec(
    icon: Icons.support_agent_rounded,
    label: (c) => c.l10n.adminSupportQueue,
    path: RoutePaths.adminSupport,
    permission: AppPermissions.supportRead,
    queue: 'support',
  ),
  _DoorSpec(
    icon: Icons.flag_rounded,
    label: (c) => c.l10n.adminReports,
    path: RoutePaths.adminReports,
    permission: AppPermissions.supportRead,
    queue: 'reports',
  ),
  _DoorSpec(
    icon: Icons.account_balance_rounded,
    label: (c) => c.l10n.adminFinancials,
    path: RoutePaths.adminFinancials,
    permission: AppPermissions.financeRead,
  ),
  _DoorSpec(
    icon: Icons.campaign_rounded,
    label: (c) => c.l10n.adminCampaigns,
    path: RoutePaths.adminCampaigns,
    permission: AppPermissions.adminDashboard,
  ),
  _DoorSpec(
    icon: Icons.query_stats_rounded,
    label: (c) => c.l10n.adminNotifyAnalytics,
    path: RoutePaths.adminNotificationAnalytics,
    permission: AppPermissions.adminDashboard,
  ),
];

class _Doors extends ConsumerWidget {
  const _Doors();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final permissions = ref.watch(currentPermissionsProvider);
    final doors = _doors
        .where((d) => permissions.isEmpty || permissions.contains(d.permission))
        .toList(growable: false);
    if (doors.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(
          title: l10n.adminCourtDoorsTitle,
          caption: l10n.adminCourtDoorsCaption,
        ),
        DsGaps.vLg,
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = DsSpacing.md;
            // Three across on a phone, so eight doors are three rows rather
            // than a corridor; never more than four, so a door stays a door.
            final columns = (constraints.maxWidth / 112).floor().clamp(3, 4);
            final doorWidth =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: DsSpacing.lg,
              children: [
                for (var i = 0; i < doors.length; i++)
                  SizedBox(
                    width: doorWidth,
                    child: DsStaggerAnimations.item(
                      index: i,
                      child: _Door(spec: doors[i]),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Door extends ConsumerWidget {
  const _Door({required this.spec});

  final _DoorSpec spec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final queue = spec.queue;
    final depth = queue == null
        ? null
        : ref.watch(adminQueueDepthProvider(queue));

    final (bool lit, String? count, String status) = switch (depth) {
      null => (false, null, l10n.adminCourtDoorEnter),
      AsyncData(value: final n?) when n > 0 => (
        true,
        formatCount(n),
        l10n.adminCourtDoorWaiting,
      ),
      AsyncData(value: 0) => (false, null, l10n.adminCourtDoorClear),
      AsyncData() || AsyncError() => (false, null, l10n.adminCourtDoorUnknown),
      _ => (false, null, '…'), // l10n-ignore: an ellipsis while counting
    };

    return CourtDoor(
      icon: spec.icon,
      label: spec.label(context),
      status: status,
      count: count,
      lit: lit,
      onTap: () => context.push(spec.path),
    );
  }
}

// ---------------------------------------------------------------------------
// The rose
// ---------------------------------------------------------------------------

/// `+18.4%` → 18.4. A trend the server did not send is flat.
double _trendValue(String? trend) {
  if (trend == null) return 0;
  final cleaned = trend.replaceAll(RegExp(r'[^0-9.\-]'), '');
  return double.tryParse(cleaned) ?? 0;
}

class _Pulse extends ConsumerWidget {
  const _Pulse();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.console;
    final l10n = context.l10n;
    final state = ref.watch(adminDashboardNotifierProvider);

    Widget body;
    if (state.isLoading || (state.stats == null && state.error == null)) {
      body = const Padding(
        padding: DsSpacing.paddingXl,
        child: Center(child: DsLoadingIndicator()),
      );
    } else if (state.error != null) {
      body = Text(
        state.error!,
        style: context.dsText.body.tint(palette.criticalInk),
      );
    } else {
      body = _PulseBody(stats: state.stats!);
    }

    return Container(
      padding: DsSpacing.paddingXl,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: DsRadius.borderXxl,
        border: Border.all(color: palette.line),
        boxShadow: palette.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Heading(
            title: l10n.adminCourtPulseTitle,
            caption: l10n.adminCourtPulseCaption,
          ),
          DsGaps.vLg,
          body,
        ],
      ),
    );
  }
}

class _PulseBody extends StatelessWidget {
  const _PulseBody({required this.stats});

  final AdminStatsEntity stats;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final l10n = context.l10n;
    final metrics = [
      (
        l10n.adminTotalSales,
        stats.totalSales.sypCompact,
        stats.salesTrend,
        Icons.payments_outlined,
      ),
      (
        l10n.adminTotalOrders,
        formatCount(stats.totalOrders),
        stats.ordersTrend,
        Icons.shopping_bag_outlined,
      ),
      (
        l10n.adminActiveUsers,
        formatCount(stats.activeUsers),
        stats.usersTrend,
        Icons.people_alt_outlined,
      ),
      (
        l10n.adminConversion,
        '${stats.conversionRate.toStringAsFixed(1)}%',
        stats.conversionTrend,
        Icons.show_chart_rounded,
      ),
    ];
    final trends = [for (final m in metrics) _trendValue(m.$3)];
    final strongest = trends.fold<double>(0, (a, b) => math.max(a, b.abs()));
    final scale = strongest == 0 ? 1.0 : strongest;
    final colors = [
      for (var i = 0; i < metrics.length; i++)
        palette.series[i % palette.series.length],
    ];

    final rose = PulseRose(
      size: 196,
      semanticLabel: l10n.adminCourtPulseSemantics,
      petals: [
        for (var i = 0; i < metrics.length; i++)
          PulsePetal(strength: trends[i] / scale, color: colors[i]),
      ],
    );

    final legend = LayoutBuilder(
      builder: (context, constraints) {
        const gap = DsSpacing.md;
        final columns = constraints.maxWidth >= 300 ? 2 : 1;
        final tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < metrics.length; i++)
              SizedBox(
                width: tileWidth,
                child: _PulseReading(
                  color: colors[i],
                  label: metrics[i].$1,
                  value: metrics[i].$2,
                  trend: metrics[i].$3,
                  falling: trends[i] < 0,
                ),
              ),
          ],
        );
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 560) {
          return Row(
            children: [
              rose,
              DsGaps.hXl,
              Expanded(child: legend),
            ],
          );
        }
        return Column(
          children: [
            Center(child: rose),
            DsGaps.vXl,
            legend,
          ],
        );
      },
    );
  }
}

/// One figure beside the rose, keyed to its petal by colour.
class _PulseReading extends StatelessWidget {
  const _PulseReading({
    required this.color,
    required this.label,
    required this.value,
    required this.trend,
    required this.falling,
  });

  final Color color;
  final String label;
  final String value;
  final String? trend;
  final bool falling;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final trendColor = falling ? palette.critical : palette.positive;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.md,
        vertical: DsSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceAlt.withValues(alpha: 0.6),
        borderRadius: DsRadius.borderLg,
        border: BorderDirectional(
          start: BorderSide(color: color, width: DsSpacing.xxs),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.metricLabel.tint(palette.muted),
          ),
          DsGaps.vXxs,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: context.dsText.metric.displayFamily.tint(palette.ink),
            ),
          ),
          if (trend != null) ...[
            DsGaps.vXxs,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  falling ? Icons.south_east_rounded : Icons.north_east_rounded,
                  size: DsSizes.iconXs,
                  color: trendColor,
                ),
                DsGaps.hXxs,
                Text(
                  trend!,
                  textDirection: TextDirection.ltr,
                  style: context.dsText.captionStrong.tint(trendColor),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The thread
// ---------------------------------------------------------------------------

class _Thread extends ConsumerWidget {
  const _Thread();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.console;
    final l10n = context.l10n;
    final permissions = ref.watch(currentPermissionsProvider);
    final canAudit =
        permissions.isEmpty || permissions.contains(AppPermissions.auditRead);
    if (!canAudit) return const SizedBox.shrink();

    final audit = ref.watch(
      adminSectionNotifierProvider(adminSectionConfigs['audit']!),
    );

    Widget body;
    if (audit.isLoading) {
      body = const Padding(
        padding: DsSpacing.paddingLg,
        child: Center(child: DsLoadingIndicator()),
      );
    } else if (audit.error != null) {
      body = Text(
        l10n.adminAuditUnavailable,
        style: context.dsText.body.tint(palette.muted),
      );
    } else if (audit.records.isEmpty) {
      body = Text(
        l10n.adminNoRecentActivity,
        style: context.dsText.body.tint(palette.muted),
      );
    } else {
      final records = audit.records.take(6).toList(growable: false);
      body = Column(
        children: [
          for (var i = 0; i < records.length; i++)
            DsStaggerAnimations.item(
              index: i,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CourtThreadBead(
                      first: i == 0,
                      last: i == records.length - 1,
                      highlight: i == 0,
                    ),
                    DsGaps.hSm,
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: DsSpacing.sm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              records[i].title,
                              style: context.dsText.bodyStrong.tint(
                                palette.ink,
                              ),
                            ),
                            if (records[i].subtitle.isNotEmpty) ...[
                              DsGaps.vXxxs,
                              Text(
                                records[i].subtitle,
                                style: context.dsText.caption.tint(
                                  palette.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // When it happened, as «قبل ساعة».
                    if (records[i].createdAt case final at?)
                      Padding(
                        padding: const EdgeInsets.only(top: DsSpacing.sm),
                        child: Text(
                          formatRelativeTime(l10n, at),
                          style: context.dsText.caption.tint(palette.muted),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    return Container(
      padding: DsSpacing.paddingXl,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: DsRadius.borderXxl,
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Heading(
            title: l10n.adminCourtThreadTitle,
            trailing: TextButton(
              onPressed: () => context.go(RoutePaths.adminAuditLogs),
              child: Text(
                l10n.adminCourtThreadAll,
                style: context.dsText.labelStrong.tint(palette.primary),
              ),
            ),
          ),
          DsGaps.vMd,
          body,
        ],
      ),
    );
  }
}
