import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/admin/data/models/admin_briefing_model.dart';
import 'package:ohara/features/admin/presentation/providers/admin_provider.dart';
import 'package:ohara/l10n/app_localizations.dart';

/// What the marketplace thinks somebody should look at today — as an agenda.
///
/// Not a list of equals. The server has already ranked the findings, so the
/// first one is drawn as the thing to do now: large, with its severity named
/// and one button that goes there. The rest follow under «بعد ذلك», numbered,
/// in the server's order. An operator with five minutes does the first; one
/// with an hour works down the list.
///
/// Everything in it comes from the server — the ordering, the wording, the
/// severity — because a phone re-ranking the list would eventually disagree
/// with the system that computed it. It says "nothing needs you today" out
/// loud when the week was quiet, and stays muted rather than alarming when the
/// read fails: the briefing is advisory, and a console that shouts because an
/// advisory endpoint timed out teaches its operator to ignore the shouting.
class AdminBriefingPanel extends ConsumerWidget {
  const AdminBriefingPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.console;
    final l10n = context.l10n;
    final briefing = ref.watch(adminBriefingProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.adminBriefing,
          style: context.dsText.sectionTitle.bold.tint(palette.ink),
        ),
        DsGaps.vMd,
        briefing.when(
          loading: () => const _Shell(
            child: Center(child: DsLoadingIndicator()),
          ),
          error: (_, _) => _Shell(
            child: Text(
              l10n.adminBriefingUnavailable,
              style: context.dsText.body.tint(palette.muted),
            ),
          ),
          data: (data) => data.quiet || data.findings.isEmpty
              ? _Shell(
                  child: Row(
                    children: [
                      Icon(
                        Icons.spa_outlined,
                        size: DsSizes.iconLg,
                        color: palette.positive,
                      ),
                      DsGaps.hMd,
                      Expanded(
                        child: Text(
                          l10n.adminBriefingQuiet,
                          style: context.dsText.body.tint(palette.muted),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _NowCard(finding: data.findings.first),
                    if (data.findings.length > 1) ...[
                      DsGaps.vLg,
                      Text(
                        l10n.adminCourtThenTitle,
                        style: context.dsText.overline.tint(palette.muted),
                      ),
                      DsGaps.vXs,
                      for (var i = 1; i < data.findings.length; i++)
                        DsStaggerAnimations.item(
                          index: i,
                          child: _ThenRow(
                            position: i + 1,
                            finding: data.findings[i],
                          ),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// The panel's plain container, shared by the loading, quiet and unavailable
/// states.
class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    return Container(
      width: double.infinity,
      padding: DsSpacing.paddingXl,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: DsRadius.borderXxl,
        border: Border.all(color: palette.line),
      ),
      child: child,
    );
  }
}

Color _severityColor(AdminConsolePalette palette, FindingSeverity severity) =>
    switch (severity) {
      FindingSeverity.critical => palette.critical,
      FindingSeverity.warning => palette.caution,
      FindingSeverity.opportunity => palette.info,
    };

String _severityLabel(AppLocalizations l10n, FindingSeverity severity) =>
    switch (severity) {
      FindingSeverity.critical => l10n.adminCourtSeverityCritical,
      FindingSeverity.warning => l10n.adminCourtSeverityWarning,
      FindingSeverity.opportunity => l10n.adminCourtSeverityOpportunity,
    };

/// The one thing to do now.
class _NowCard extends StatelessWidget {
  const _NowCard({required this.finding});

  final AdminFinding finding;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final l10n = context.l10n;
    final accent = _severityColor(palette, finding.severity);
    final destination = adminRouteForFinding(finding.href);

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: DsRadius.borderXxl,
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        boxShadow: context.glowShadow(accent, blur: 28, alpha: 0.14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // A wash of the severity's colour from the reading corner — the
          // card is lit by what it is about, not painted in it.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: AlignmentDirectional.topStart.resolve(
                    Directionality.of(context),
                  ),
                  radius: 1.4,
                  colors: [
                    accent.withValues(alpha: 0.12),
                    accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: DsSpacing.paddingXl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _SeverityTag(
                      color: accent,
                      label: _severityLabel(l10n, finding.severity),
                    ),
                    const Spacer(),
                    Text(
                      l10n.adminCourtNowTitle,
                      style: context.dsText.overline.tint(palette.muted),
                    ),
                  ],
                ),
                DsGaps.vMd,
                Text(
                  finding.title,
                  style: context.dsText.screenTitle.bold.tint(palette.ink),
                ),
                DsGaps.vXs,
                Text(
                  finding.action,
                  style: context.dsText.bodyLarge.tint(palette.muted),
                ),
                if (destination != null) ...[
                  DsGaps.vLg,
                  // The button's frame fills whatever width it is offered,
                  // so it is offered only its own.
                  IntrinsicWidth(
                    child: PrimaryButton(
                      label: l10n.adminCourtNowOpen,
                      icon: Directionality.of(context) == TextDirection.rtl
                          ? Icons.north_west_rounded
                          : Icons.north_east_rounded,
                      isExpanded: false,
                      onPressed: () => context.push(destination),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeverityTag extends StatelessWidget {
  const _SeverityTag({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DsSpacing.pillPadding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: DsRadius.borderPill,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: DsSpacing.xs,
            height: DsSpacing.xs,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          DsGaps.hXs,
          Text(label, style: context.dsText.captionStrong.tint(color)),
        ],
      ),
    );
  }
}

/// One of the findings after the first, numbered in the server's order.
class _ThenRow extends StatelessWidget {
  const _ThenRow({required this.position, required this.finding});

  final int position;
  final AdminFinding finding;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final accent = _severityColor(palette, finding.severity);
    final destination = adminRouteForFinding(finding.href);
    final rtl = Directionality.of(context) == TextDirection.rtl;

    final row = Padding(
      padding: const EdgeInsets.symmetric(
        vertical: DsSpacing.sm,
        horizontal: DsSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: DsSizes.controlSm,
            child: Text(
              '$position',
              style: context.dsText.metricSmall.displayFamily.tint(accent),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  finding.title,
                  style: context.dsText.bodyStrong.tint(palette.ink),
                ),
                DsGaps.vXxs,
                Text(
                  finding.action,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.cardSubtitle.tint(palette.muted),
                ),
              ],
            ),
          ),
          if (destination != null) ...[
            DsGaps.hSm,
            Icon(
              rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              size: DsSizes.iconSm,
              color: palette.muted,
            ),
          ],
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      child: destination == null
          ? row
          : InkWell(
              borderRadius: DsRadius.borderMd,
              onTap: () => context.push(destination),
              child: row,
            ),
    );
  }
}

/// Maps a finding's server-side link to a screen this app actually has.
///
/// The server names the *subject* of a finding — `/admin/trust`, say — which
/// is a stable identifier, not a client route. Several of those subjects have
/// no console screen yet, and the honest rendering of that is a row with no
/// chevron: a tap that lands on a 404, or worse on a plausible-looking wrong
/// screen, costs more trust than the missing shortcut does.
///
/// Only exact and unambiguous matches are listed. When a screen for one of the
/// unmapped subjects is built, it is added here.
String? adminRouteForFinding(String? href) => switch (href) {
  '/admin/economics' => RoutePaths.adminAnalytics,
  '/admin/commissions' => RoutePaths.adminCommissions,
  '/admin/trust' => RoutePaths.adminModeration,
  '/admin/sellers/retention' => RoutePaths.adminSellers,
  '/admin/products' => RoutePaths.adminProducts,
  '/admin/catalog/duplicates' => RoutePaths.adminProducts,
  // /admin/lifecycle, /admin/ranking and the unanswered-search queue have no
  // screen in this build.
  _ => null,
};
