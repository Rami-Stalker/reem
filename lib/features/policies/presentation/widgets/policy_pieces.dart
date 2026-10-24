import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/utils/arabic_numerals.dart';
import 'package:ohara/features/policies/domain/entities/policy_document.dart';
import 'package:ohara/l10n/app_localizations.dart';

/// The glyph for a policy.
///
/// Driven by the `icon` string the server sends, with the document kind as a
/// fallback. A string rather than a code point because the console can retire
/// a policy and add another without the app shipping a build — and an unknown
/// name has to land on something rather than on a crash.
IconData policyIcon(PolicySummary policy) {
  return switch (policy.icon) {
    'terms' => Icons.description_outlined,
    'storefront' => Icons.storefront_outlined,
    'privacy' => Icons.lock_outline_rounded,
    'returns' => Icons.assignment_return_outlined,
    'commission' => Icons.percent_rounded,
    'dispute' => Icons.gavel_outlined,
    'liability' => Icons.balance_outlined,
    'content' => Icons.photo_library_outlined,
    _ => switch (policy.kind) {
      PolicyKind.customerTerms ||
      PolicyKind.sellerTerms => Icons.description_outlined,
      PolicyKind.privacy => Icons.lock_outline_rounded,
      PolicyKind.returns => Icons.assignment_return_outlined,
      PolicyKind.commissions => Icons.percent_rounded,
      PolicyKind.disputes => Icons.gavel_outlined,
      PolicyKind.liability => Icons.balance_outlined,
      PolicyKind.content => Icons.photo_library_outlined,
      PolicyKind.other => Icons.article_outlined,
    },
  };
}

/// A date, in the reader's language and always in Western digits — the same
/// rule the rest of the app follows. See `arabic_numerals.dart`.
String formatPolicyDate(AppLocalizations l10n, DateTime moment) =>
    // l10n-ignore: an intl date pattern, not copy.
    toWesternDigits(DateFormat('d MMMM yyyy', l10n.localeName).format(moment));

/// One policy, as a row in the policy centre.
class PolicyCard extends StatelessWidget {
  const PolicyCard({super.key, required this.policy, required this.onTap});

  final PolicySummary policy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final acceptance = policy.acceptance;

    // Three states, and they are not the same sentence. "Accepted on the 3rd"
    // is a receipt; "you accepted version 1" is a receipt *and* a warning that
    // the text has moved on; "not accepted" is neither, and only worth saying
    // at all for a document that asks for a signature.
    final (String? stamp, Color stampColor) = switch (acceptance) {
      null when policy.requiredForConsent => (
        l10n.policiesNotAccepted,
        colors.onSurfaceVariant,
      ),
      null => (null, colors.onSurfaceVariant),
      final a when a.isCurrent => (
        a.acceptedAt == null
            ? null
            : l10n.policiesAcceptedOn(formatPolicyDate(l10n, a.acceptedAt!)),
        colors.success,
      ),
      final a => (
        a.acceptedAt == null
            ? null
            : l10n.policiesAcceptedOlderVersion(
                '${a.version}',
                formatPolicyDate(l10n, a.acceptedAt!),
              ),
        colors.warning,
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.sm),
      child: SurfaceCard(
        onTap: onTap,
        semanticLabel: policy.title,
        padding: const EdgeInsets.all(DsSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(DsRadius.md),
              ),
              child: Icon(policyIcon(policy), color: colors.primary, size: 22),
            ),
            const SizedBox(width: DsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          policy.title,
                          style: context.dsText.cardTitle.semibold,
                        ),
                      ),
                      if (policy.requiredForConsent)
                        _Tag(
                          label: l10n.policiesRequiredBadge,
                          color: colors.primary,
                        ),
                    ],
                  ),
                  if (policy.summary.isNotEmpty) ...[
                    const SizedBox(height: DsSpacing.xxs),
                    Text(
                      policy.summary,
                      style: context.dsText.cardSubtitle.copyWith(height: 1.5),
                    ),
                  ],
                  const SizedBox(height: DsSpacing.xs),
                  Wrap(
                    spacing: DsSpacing.sm,
                    runSpacing: DsSpacing.xxs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        l10n.policiesVersionLabel('${policy.version}'),
                        style: context.dsText.caption,
                      ),
                      if (policy.effectiveAt != null)
                        Text(
                          l10n.policiesEffectiveFrom(
                            formatPolicyDate(l10n, policy.effectiveAt!),
                          ),
                          style: context.dsText.caption,
                        ),
                    ],
                  ),
                  if (stamp != null) ...[
                    const SizedBox(height: DsSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          acceptance == null
                              ? Icons.radio_button_unchecked
                              : acceptance.isCurrent
                              ? Icons.check_circle_rounded
                              : Icons.info_outline_rounded,
                          size: 15,
                          color: stampColor,
                        ),
                        const SizedBox(width: DsSpacing.xxs),
                        Expanded(
                          child: Text(
                            stamp,
                            style: context.dsText.caption.tint(stampColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DsRadius.xs),
      ),
      child: Text(label, style: context.dsText.micro.tint(color)),
    );
  }
}
