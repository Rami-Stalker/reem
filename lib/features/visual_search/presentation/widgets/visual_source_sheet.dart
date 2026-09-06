import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/visual_search/domain/entities/visual_search_session.dart';

/// One photograph, picked and already shrunk.
class PickedQueryImage {
  const PickedQueryImage({
    required this.bytes,
    required this.filename,
    required this.source,
  });

  final Uint8List bytes;
  final String filename;
  final VisualSearchSource source;
}

/// "ابحثي بالصورة" — where the picture comes from.
///
/// Two entries rather than six. Instagram, TikTok and Pinterest are not
/// sources in any technical sense: what she has from any of them is a
/// screenshot sitting in her camera roll, and adding buttons that all open the
/// same gallery would be three lies about what the app can reach. The copy
/// names them instead, so she knows a screenshot is exactly what this expects.
///
/// The share sheet is the real second path into this feature and it is an OS
/// integration rather than a button: `Share to Reem` from any of those apps
/// arrives as `VisualSearchSource.shared`.
class VisualSourceSheet extends StatelessWidget {
  const VisualSourceSheet({super.key, required this.maxEdge});

  /// The longest edge the server asks the client to resample to. Served from
  /// `/visual-search/bootstrap`, so a policy change does not need a release.
  final int maxEdge;

  static Future<PickedQueryImage?> show(
    BuildContext context, {
    required int maxEdge,
  }) {
    return DsBottomSheet.showTitled<PickedQueryImage>(
      context,
      title: 'ابحثي بالصورة',
      subtitle:
          'صوّري القطعة، أو اختاري سكرين شوت من إنستغرام أو تيك توك أو بنترست.',
      child: VisualSourceSheet(maxEdge: maxEdge),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Option(
          icon: Icons.photo_camera_rounded,
          title: 'صوّري القطعة',
          subtitle: 'خليها بإضاءة منيحة وخلفية بسيطة',
          onTap: () => _pick(context, ImageSource.camera),
        ),
        const SizedBox(height: DsSpacing.xs),
        _Option(
          icon: Icons.photo_library_rounded,
          title: 'من الاستوديو',
          subtitle: 'سكرين شوت أو صورة محفوظة',
          onTap: () => _pick(context, ImageSource.gallery),
        ),
        const SizedBox(height: DsSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.shield_outlined,
              size: 16,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: DsSpacing.xs),
            Expanded(
              child: Text(
                'صورتك بتنحفظ بشكل خاص وبتنمسح تلقائيًا بعد انتهاء البحث. '
                'ما حدا غيرك بيقدر يشوفها.',
                style: context.dsText.caption.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Picks and resamples on the device before a single byte goes out.
  ///
  /// A modern phone camera produces 4000×3000 at 6 MB and the server resamples
  /// everything to a square canvas anyway, so those pixels buy nothing and
  /// cost minutes on a Syrian mobile connection — on a metered plan, money
  /// too. [maxEdge] is what the server says it wants.
  Future<void> _pick(BuildContext context, ImageSource source) async {
    final navigator = Navigator.of(context);
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: maxEdge.toDouble(),
      maxHeight: maxEdge.toDouble(),
      imageQuality: 85,
      // The photograph is analysed and thrown away; its EXIF — including the
      // GPS tag on a picture taken at her home — has no reason to leave the
      // device at all. The server strips it too, but the safest byte is the
      // one that was never sent.
      requestFullMetadata: false,
    );
    if (picked == null) {
      navigator.pop();
      return;
    }

    final bytes = await picked.readAsBytes();
    navigator.pop(
      PickedQueryImage(
        bytes: bytes,
        filename: picked.name.isEmpty ? 'query.jpg' : picked.name,
        source: source == ImageSource.camera
            ? VisualSearchSource.camera
            : VisualSearchSource.gallery,
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DsRadius.card),
      child: Container(
        padding: const EdgeInsets.all(DsSpacing.md),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(DsRadius.card),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: colors.onPrimaryContainer),
            ),
            const SizedBox(width: DsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.dsText.tileTitle),
                  Text(
                    subtitle,
                    style: context.dsText.cardSubtitle.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
