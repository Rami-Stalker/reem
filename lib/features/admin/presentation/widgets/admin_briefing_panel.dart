import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/admin/data/models/admin_briefing_model.dart';
import 'package:reem/features/admin/presentation/providers/admin_provider.dart';

/// What the marketplace thinks somebody should look at today.
///
/// The console already carries a wall of counters. This is the opposite of a
/// counter: a short, ordered list of things that are *wrong or worth doing*,
/// each with the numbers that make the claim checkable and a sentence naming
/// what a person could do about it. Everything in it comes from the server —
/// the ordering, the wording, the severity — because a phone re-ranking the
/// list would eventually disagree with the system that computed it.
///
/// It renders nothing at all rather than something reassuring when the read
/// fails, and says "nothing needs you today" out loud when the week was quiet.
/// Both matter: an operator who learns that this panel invents work stops
/// reading it, and one who cannot tell a quiet week from a broken screen
/// stops trusting it.
class AdminBriefingPanel extends ConsumerWidget {
  const AdminBriefingPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.console;
    final l10n = context.l10n;
    final briefing = ref.watch(adminBriefingProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.adminBriefing,
          style: context.dsText.cardTitle.bold.tint(palette.ink),
        ),
        const SizedBox(height: DsSpacing.md),
        briefing.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(DsSpacing.lg),
            child: Center(child: DsLoadingIndicator()),
          ),
          // Not an empty state and not an alarm. The briefing is advisory; a
          // console that shouts because an advisory endpoint timed out teaches
          // its operator to ignore the shouting.
          error: (_, _) => _Shell(
            palette: palette,
            child: Text(
              l10n.adminBriefingUnavailable,
              style: context.dsText.body.tint(palette.muted),
            ),
          ),
          data: (data) => data.quiet
              ? _Shell(
                  palette: palette,
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 20,
                        color: palette.positive,
                      ),
                      const SizedBox(width: DsSpacing.sm),
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
                  children: [
                    for (final finding in data.findings)
                      Padding(
                        padding: const EdgeInsets.only(bottom: DsSpacing.sm),
                        child: _FindingRow(finding: finding, palette: palette),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// The panel's plain container, shared by the quiet and unavailable states.
class _Shell extends StatelessWidget {
  const _Shell({required this.palette, required this.child});

  final AdminConsolePalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: DsRadius.borderSm,
        border: Border.all(color: palette.line),
      ),
      child: child,
    );
  }
}

class _FindingRow extends StatelessWidget {
  const _FindingRow({required this.finding, required this.palette});

  final AdminFinding finding;
  final AdminConsolePalette palette;

  @override
  Widget build(BuildContext context) {
    final accent = switch (finding.severity) {
      FindingSeverity.critical => palette.critical,
      FindingSeverity.warning => palette.caution,
      FindingSeverity.opportunity => palette.info,
    };
    final destination = _routeFor(finding.href);
    final rtl = Directionality.of(context) == TextDirection.rtl;

    final row = Container(
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: DsRadius.borderSm,
        border: Border.all(color: palette.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A severity bar rather than a coloured card: the console is
          // graphite on purpose, and four red panels in a row would make the
          // fifth finding invisible.
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: accent,
              // Half the bar's own width, which is what `pill` resolves to
              // on a 4px-wide rule: a stadium with semicircular caps.
              borderRadius: BorderRadius.circular(DsRadius.pill),
            ),
          ),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  finding.title,
                  style: context.dsText.bodyStrong.tint(palette.ink),
                ),
                const SizedBox(height: DsSpacing.xs),
                Text(
                  finding.action,
                  style: context.dsText.cardSubtitle.tint(palette.muted),
                ),
              ],
            ),
          ),
          if (destination != null) ...[
            const SizedBox(width: DsSpacing.sm),
            Icon(
              rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              size: 20,
              color: palette.muted,
            ),
          ],
        ],
      ),
    );

    if (destination == null) return row;

    return InkWell(
      borderRadius: DsRadius.borderSm,
      onTap: () => context.go(destination),
      child: row,
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
String? _routeFor(String? href) => switch (href) {
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
