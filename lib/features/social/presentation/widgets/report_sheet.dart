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
///
/// [submitDetailed], when given, is used for «سبب آخر»: a reason the list
/// does not name is one a moderator can only act on if she says what it is,
/// so the sheet asks — optionally — before sending.
Future<void> showReportSheet(
  BuildContext context, {
  required Future<Result<void>> Function(String reason) submit,
  Future<Result<void>> Function(String reason, String? detail)? submitDetailed,
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

  Future<Result<void>> Function() sender = () => submit(reason.wire);
  if (reason == ReportReason.other && submitDetailed != null) {
    final detail = await DsBottomSheet.show<String>(
      context,
      builder: (_) => const _ReportDetailSheet(),
    );
    if (detail == null || !context.mounted) return;
    sender = () => submitDetailed(reason.wire, detail.isEmpty ? null : detail);
  }

  final result = await sender();
  if (!context.mounted) return;
  switch (result) {
    case Success():
      DsSnackbar.success(context, l10n.reportSent);
    case Error(:final failure):
      DsSnackbar.error(context, failure.message);
  }
}

/// «أخبرينا بالمزيد» — the free-text half of «سبب آخر». Returns her words
/// (possibly empty) on send, null if she backs out.
class _ReportDetailSheet extends StatefulWidget {
  const _ReportDetailSheet();

  @override
  State<_ReportDetailSheet> createState() => _ReportDetailSheetState();
}

class _ReportDetailSheetState extends State<_ReportDetailSheet> {
  final _detail = TextEditingController();

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DsSheetScaffold(
      title: l10n.reportDetailTitle,
      subtitle: l10n.reportSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DsInputField(
            controller: _detail,
            label: l10n.reportDetailLabel,
            hint: l10n.reportDetailHint,
            maxLines: 4,
          ),
          DsGaps.vLg,
          PrimaryButton(
            label: l10n.reportSend,
            icon: Icons.flag_outlined,
            onPressed: () => Navigator.of(context).pop(_detail.text.trim()),
          ),
        ],
      ),
    );
  }
}
