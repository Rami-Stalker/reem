import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/l10n/app_localizations.dart';

/// The reasons a woman can give, in the order she is most likely to need
/// them. The keys are the server's `CONTENT_REPORT_REASONS`, shared by posts
/// and products, so a reason picked here is never refused as unknown.
enum ReportReason {
  immodest('immodest'),
  spam('spam'),
  harassment('harassment'),
  notTheProduct('not_the_product'),
  stolenPhoto('stolen_photo'),
  counterfeit('counterfeit'),
  other('other');

  const ReportReason(this.wire);

  final String wire;

  String label(AppLocalizations l10n) => switch (this) {
    ReportReason.immodest => l10n.reportReasonImmodest,
    ReportReason.spam => l10n.reportReasonSpam,
    ReportReason.harassment => l10n.reportReasonHarassment,
    ReportReason.notTheProduct => l10n.reportReasonNotTheProduct,
    ReportReason.stolenPhoto => l10n.reportReasonStolenPhoto,
    ReportReason.counterfeit => l10n.reportReasonCounterfeit,
    ReportReason.other => l10n.reportReasonOther,
  };

  IconData get icon => switch (this) {
    ReportReason.immodest => Icons.visibility_off_outlined,
    ReportReason.spam => Icons.do_not_disturb_on_outlined,
    ReportReason.harassment => Icons.front_hand_outlined,
    ReportReason.notTheProduct => Icons.image_not_supported_outlined,
    ReportReason.stolenPhoto => Icons.copyright_rounded,
    ReportReason.counterfeit => Icons.new_releases_outlined,
    ReportReason.other => Icons.more_horiz_rounded,
  };
}

/// Asks why, sends the report, and thanks her.
///
/// [submit] is the only thing that differs between a post and a product; the
/// sheet, the reasons and the confirmation are the same so a report reads the
/// same wherever she makes it.
Future<void> showReportSheet(
  BuildContext context, {
  required Future<Result<void>> Function(String reason) submit,
}) async {
  final l10n = context.l10n;
  final reason = await DsBottomSheet.choose<ReportReason>(
    context,
    title: l10n.reportTitle,
    message: l10n.reportSubtitle,
    choices: [
      for (final reason in ReportReason.values)
        DsSheetChoice(
          value: reason,
          label: reason.label(l10n),
          icon: reason.icon,
        ),
    ],
  );
  if (reason == null || !context.mounted) return;

  final result = await submit(reason.wire);
  if (!context.mounted) return;
  switch (result) {
    case Success():
      DsSnackbar.success(context, l10n.reportSent);
    case Error(:final failure):
      DsSnackbar.error(context, failure.message);
  }
}
