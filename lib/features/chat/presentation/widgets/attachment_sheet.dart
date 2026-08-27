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
abstract final class ChatAttachmentSheet {
  static Future<ChatAttachmentSource?> show(BuildContext context) {
    final l10n = context.l10n;
    return DsBottomSheet.showTitled<ChatAttachmentSource>(
      context,
      title: l10n.chatAttachTitle,
      scrollable: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Option(
            icon: Icons.photo_camera_outlined,
            label: l10n.mediaFromCamera,
            onTap: () =>
                Navigator.of(context).pop(ChatAttachmentSource.camera),
          ),
          _Option(
            icon: Icons.photo_library_outlined,
            label: l10n.mediaFromGallery,
            onTap: () =>
                Navigator.of(context).pop(ChatAttachmentSource.gallery),
          ),
          _Option(
            icon: Icons.attach_file_rounded,
            label: l10n.chatFromFiles,
            onTap: () => Navigator.of(context).pop(ChatAttachmentSource.files),
          ),
          const SizedBox(height: DsSpacing.sm),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: c.primary.withValues(alpha: 0.12),
        child: Icon(icon, color: c.primary, size: 20),
      ),
      title: Text(label),
      trailing: Icon(Icons.chevron_right_rounded, color: c.onSurfaceVariant),
    );
  }
}
