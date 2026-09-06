import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';

/// The answers to the questions she actually arrives with.
///
/// Extracted from the profile menu so Settings can open the same thing: its
/// «مركز المساعدة» row was an empty `onTap: () {}`, and two separate help
/// surfaces would only have drifted apart.
///
/// Deliberately answers rather than links out: there is no help site to link
/// to, and a row that opens a browser to nothing is the same dead end in a
/// different costume.
Future<void> showHelpSheet(BuildContext context) {
  final l10n = context.l10n;
  return DsBottomSheet.showTitled(
    context,
    title: l10n.helpAndFaq,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FaqEntry(question: l10n.faqTracking, answer: l10n.faqTrackingAnswer),
        FaqEntry(question: l10n.faqReturns, answer: l10n.faqReturnsAnswer),
        FaqEntry(question: l10n.faqPayment, answer: l10n.faqPaymentAnswer),
        FaqEntry(
          question: l10n.faqContactSeller,
          answer: l10n.faqContactSellerAnswer,
        ),
        FaqEntry(question: l10n.faqPoints, answer: l10n.rewardsPointsBlurb),
      ],
    ),
  );
}

/// One question and its answer.
class FaqEntry extends StatelessWidget {
  const FaqEntry({super.key, required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: context.dsText.tileTitle
                .copyWith(fontWeight: DsTypography.bold),
          ),
          const SizedBox(height: DsSpacing.xxs),
          Text(
            answer,
            style: context.dsText.body
                .copyWith(color: context.dsColors.onSurfaceVariant, height: 1.5),
          ),
        ],
      ),
    );
  }
}
