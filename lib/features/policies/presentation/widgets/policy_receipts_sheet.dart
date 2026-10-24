import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/policies/domain/entities/policy_document.dart';
import 'package:ohara/features/policies/presentation/providers/policies_provider.dart';
import 'package:ohara/features/policies/presentation/widgets/policy_pieces.dart';

/// «موافقاتي» — what she agreed to, which version of it, and when.
///
/// This is the client's requirement made visible. The platform stores the
/// version and the moment of every consent; a record only the platform can see
/// is a record she has to take our word for, so it is on her screen too — and
/// each row opens *the text she signed*, not today's, which is what makes it a
/// receipt rather than a claim.
Future<void> showPolicyReceiptsSheet(BuildContext context) {
  final l10n = context.l10n;
  return DsBottomSheet.showTitled(
    context,
    title: l10n.policiesMyConsents,
    subtitle: l10n.policiesMyConsentsSubtitle,
    child: const _PolicyReceipts(),
  );
}

class _PolicyReceipts extends ConsumerWidget {
  const _PolicyReceipts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = policyLocaleOf(context);
    final receipts = ref.watch(policyReceiptsProvider(locale));

    return receipts.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(DsSpacing.xl),
        child: Center(child: DsLoadingIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(DsSpacing.md),
        child: DsInlineError(message: '$error'),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(DsSpacing.lg),
            child: Text(
              l10n.policiesReceiptsEmpty,
              style: context.dsText.body.tint(
                context.dsColors.onSurfaceVariant,
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final row in rows) _ReceiptRow(receipt: row)],
        );
      },
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.receipt});

  final PolicyReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;

    final source = switch (receipt.source) {
      'registration' => l10n.policiesSourceRegistration,
      'seller_application' => l10n.policiesSourceSellerApplication,
      _ => l10n.policiesSourceReconsent,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.sm),
      child: SurfaceCard(
        padding: const EdgeInsets.all(DsSpacing.md),
        // Opens the version she signed, by id — which for an older signature
        // is an archived text the policy centre no longer lists. That is the
        // whole point: a receipt that showed today's terms would prove nothing.
        onTap: () => context.push(
          '${RoutePaths.policyDetailOf(receipt.slug)}?version=${receipt.versionId}',
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              receipt.isCurrent
                  ? Icons.check_circle_rounded
                  : Icons.history_rounded,
              size: 18,
              color: receipt.isCurrent
                  ? colors.success
                  : colors.onSurfaceVariant,
            ),
            const SizedBox(width: DsSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(receipt.title, style: context.dsText.cardTitle.semibold),
                  const SizedBox(height: DsSpacing.xxs),
                  Text(
                    [
                      l10n.policiesVersionLabel('${receipt.version}'),
                      if (receipt.acceptedAt != null)
                        formatPolicyDate(l10n, receipt.acceptedAt!),
                      source,
                    ].join(' · '),
                    style: context.dsText.caption,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
