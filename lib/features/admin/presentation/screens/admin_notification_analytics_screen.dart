import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/shared/value_objects/money_format.dart';
import 'package:reem/features/admin/data/models/notification_analytics_model.dart';
import 'package:reem/features/admin/presentation/providers/admin_actions.dart';
import 'package:reem/features/admin/presentation/providers/admin_provider.dart';
import 'package:reem/features/admin/presentation/widgets/admin_page_header.dart';
import 'package:reem/l10n/app_localizations.dart';

/// How many messages went out, down which channel, and how many landed.
///
/// This screen exists because the generic section screen could not render it.
/// That screen draws a queue of records, and this endpoint answers with three
/// cross-tabs and a scalar — `{unread_in_app, deliveries[], campaigns[],
/// events[]}` — where a row is `{channel, status, count}` with no id and no
/// name. Fed through the record mapper it produced four rows titled
/// `notificationAnalytics`, one badge each, and no way to tell push from
/// in-app. A count by two axes is a small table, so it is drawn as one.
class AdminNotificationAnalyticsScreen extends ConsumerWidget {
  const AdminNotificationAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.console;
    final snapshot = ref.watch(notificationAnalyticsProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: l10n.adminNotificationAnalytics,
            icon: Icons.query_stats_rounded,
            subtitle: l10n.adminNotificationAnalyticsSubtitle,
            actions: [
              IconButton(
                tooltip: l10n.refresh,
                onPressed: () =>
                    ref.invalidate(notificationAnalyticsProvider),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: courtGutter(context)),
            child: switch (snapshot) {
              AsyncData(:final value) => _Content(report: value),
              AsyncError(:final error) => _Failed(
                message: '$error',
                onRetry: () => ref.invalidate(notificationAnalyticsProvider),
              ),
              _ => const Padding(
                padding: EdgeInsets.all(DsSpacing.xxxl),
                child: Center(child: DsLoadingIndicator()),
              ),
            },
          ),
          const SizedBox(height: DsSpacing.xxxl),
        ],
      ),
    ).withBackground(palette.background);
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.report});

  final NotificationAnalytics report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.console;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CourtFigureRow(
          minTileWidth: 200,
          children: [
            CourtFigure(
              label: l10n.adminUnreadInApp,
              value: formatCount(report.unreadInApp),
              icon: Icons.mark_email_unread_outlined,
            ),
            CourtFigure(
              label: l10n.adminNotificationsSent,
              value: formatCount(report.sent),
              icon: Icons.send_rounded,
              accent: palette.positive,
            ),
            CourtFigure(
              label: l10n.adminNotificationsFailed,
              value: formatCount(report.failed),
              icon: Icons.error_outline_rounded,
              accent: report.failed > 0 ? palette.critical : palette.muted,
            ),
          ],
        ),
        const SizedBox(height: DsSpacing.lg),
        _Breakdown(
          title: l10n.adminDeliveriesByChannel,
          rows: [
            for (final row in report.deliveries)
              _BreakdownRow(
                label: adminChannelLabel(l10n, row.channel),
                detail: adminStatusLabel(l10n, row.status),
                count: row.count,
              ),
          ],
        ),
        const SizedBox(height: DsSpacing.lg),
        _Breakdown(
          title: l10n.adminCampaignsByStatus,
          rows: [
            for (final row in report.campaigns)
              _BreakdownRow(
                label: adminStatusLabel(l10n, row.status),
                count: row.count,
              ),
          ],
        ),
        const SizedBox(height: DsSpacing.lg),
        _Breakdown(
          title: l10n.adminDeliveryEvents,
          rows: [
            for (final row in report.events)
              _BreakdownRow(
                label: adminStatusLabel(l10n, row.event),
                count: row.count,
              ),
          ],
        ),
      ],
    );
  }
}

class _BreakdownRow {
  const _BreakdownRow({required this.label, required this.count, this.detail});

  final String label;
  final String? detail;
  final int count;
}

/// One cross-tab, drawn as a bar per row so the shape is readable at a glance
/// rather than needing three numbers to be compared in the head.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.title, required this.rows});

  final String title;
  final List<_BreakdownRow> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.console;
    final largest = rows.fold<int>(0, (top, row) => row.count > top ? row.count : top);

    return CourtPanel(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rows.isEmpty)
            Text(
              l10n.adminNoRankedData,
              style: context.dsText.body.tint(palette.muted),
            )
          else
            for (final row in rows) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        row.detail == null
                            ? row.label
                            : '${row.label} · ${row.detail}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.body.tint(palette.ink),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: DsMeter(
                        value: largest == 0 ? 0 : row.count / largest,
                        weight: DsMeterWeight.regular,
                        color: palette.primary,
                        track: palette.surfaceAlt,
                      ),
                    ),
                    const SizedBox(width: DsSpacing.sm),
                    Text(
                      '${row.count}',
                      style: context.dsText.body.semibold.tint(palette.ink),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CourtQuietNote(
      icon: Icons.cloud_off_rounded,
      color: context.console.critical,
      message: '${l10n.adminSectionUnavailable}\n$message',
      action: SecondaryButton(
        label: l10n.retry,
        icon: Icons.refresh_rounded,
        isExpanded: false,
        onPressed: onRetry,
      ),
    );
  }
}

/// The channel a message went down, in her language.
String adminChannelLabel(AppLocalizations l10n, String token) {
  return switch (token.toLowerCase()) {
    'push' => l10n.adminChannelPush,
    'in_app' => l10n.adminChannelInApp,
    'email' => l10n.adminChannelEmail,
    'sms' => l10n.adminChannelSms,
    'whatsapp' => l10n.adminChannelWhatsapp,
    _ => token,
  };
}

extension _Backdrop on Widget {
  Widget withBackground(Color color) => ColoredBox(color: color, child: this);
}

/// The reading itself.
///
/// Reads the datasource directly, for the same reason `adminBriefingProvider`
/// does: there is no mapping and no business rule between the wire and the
/// screen, so a repository and a use case would be two files that only forward.
final notificationAnalyticsProvider =
    FutureProvider.autoDispose<NotificationAnalytics>((ref) {
      return ref
          .watch(adminRemoteDataSourceProvider)
          .getNotificationAnalytics();
    });
