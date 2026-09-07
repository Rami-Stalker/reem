import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';

/// Where a chat attachment comes from.
enum ChatAttachmentSource { camera, gallery, files }

/// Asks what she wants to attach and where it comes from.
///
/// Three sources. The mock this replaced offered location as well, backed by
/// nothing — and a button that does nothing is worse than one that is not
/// there. Voice lives on the composer's own row, where holding a recording is
/// its own state rather than a menu choice.
///
/// Presented through [DsBottomSheet.choose], so it arrives as an iOS action
/// sheet on an iPhone and a Material list on Android.
abstract final class ChatAttachmentSheet {
  static Future<ChatAttachmentSource?> show(BuildContext context) {
    final l10n = context.l10n;
    return DsBottomSheet.choose<ChatAttachmentSource>(
      context,
      title: l10n.chatAttachTitle,
      choices: [
        DsSheetChoice(
          value: ChatAttachmentSource.camera,
          label: l10n.mediaFromCamera,
          icon: Icons.photo_camera_outlined,
        ),
        DsSheetChoice(
          value: ChatAttachmentSource.gallery,
          label: l10n.mediaFromGallery,
          icon: Icons.photo_library_outlined,
        ),
        DsSheetChoice(
          value: ChatAttachmentSource.files,
          label: l10n.chatFromFiles,
          icon: Icons.attach_file_rounded,
        ),
      ],
    );
  }
}
