import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';

/// A marketplace safety note above the conversation list.
///
/// This replaced a banner that read "End-to-end encrypted". That was not true:
/// message bodies are stored in plain text and the server searches them, so
/// the claim promised a protection Ohara does not provide. What she actually
/// needs warning about is the scam this surface enables — a "boutique" moving
/// the payment off-platform, where none of the escrow applies.
class EncryptedChatBanner extends StatelessWidget {
  const EncryptedChatBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: c.infoContainer.withValues(alpha: 0.55),
        borderRadius: DsRadius.borderLg,
        border: Border.all(color: c.info.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, size: 20, color: c.info),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.chatSafetyNote,
                  style: context.dsText.labelLarge.copyWith(
                    color: c.info,
                    fontWeight: DsTypography.semiBold,
                  ),
                ),
                DsGaps.vXxxs,
                Text(
                  l10n.chatSafetyNoteBody,
                  style: context.dsText.cardSubtitle.copyWith(
                    color: c.info.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
