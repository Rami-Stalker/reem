import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';

/// Who Reem is, and which build she is holding.
///
/// Lifted out of the buyer's profile menu because the seller's menu answered
/// the same row with "coming soon" — as it did for Help. Both already existed;
/// the seller was simply never given them.
void showAboutSheet(BuildContext context) {
  DsBottomSheet.showTitled(
    context,
    title: context.l10n.aboutReem,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DsGradientText('REEM', style: context.dsText.pageTitle.bold),
        const SizedBox(height: DsSpacing.xs),
        Text(context.l10n.aboutReemBlurb, style: context.dsText.body),
        const SizedBox(height: DsSpacing.md),
        Text(
          context.l10n.appVersion('1.0.0'),
          style: context.dsText.label.copyWith(
            color: context.dsColors.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
