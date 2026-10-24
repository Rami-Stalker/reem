import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/social/domain/entities/content.dart';

/// «أضيفي إلى صفحتي» — confirming, with a note if she wants one.
///
/// Returns her note (possibly empty) on confirm, and null if she backs out.
///
/// The sheet exists rather than a bare toggle because of what it has to show
/// her: **the boutique keeps the credit.** She is adding somebody's post to her
/// page, not making one, and a woman who does not understand that has been
/// misled by the interface rather than by the platform.
Future<String?> showReshareSheet(
  BuildContext context, {
  required Content content,
}) {
  return DsBottomSheet.show<String>(
    context,
    builder: (_) => _ReshareSheet(content: content),
  );
}

class _ReshareSheet extends StatefulWidget {
  const _ReshareSheet({required this.content});

  final Content content;

  @override
  State<_ReshareSheet> createState() => _ReshareSheetState();
}

class _ReshareSheetState extends State<_ReshareSheet> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final content = widget.content;
    final tag = content.primaryTag;

    return DsSheetScaffold(
      title: context.l10n.contentAddToMyPage,
      subtitle: context.l10n.contentAddToMyPageBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The attribution preview. This is the part that matters: she can see
          // exactly what her followers will see, with the boutique's name on it.
          SurfaceCard(
            semanticLabel: context.l10n.contentAddToMyPagePreview,
            child: Row(
              children: [
                DsAvatar(
                  imageUrl: content.author.imageUrl,
                  name: content.author.name,
                  size: DsSizes.avatarSm,
                ),
                DsGaps.hSm,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content.author.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.tileTitle,
                      ),
                      Text(
                        context.l10n.contentAddToMyPageCredit,
                        style: context.dsText.micro.tint(c.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (tag != null) ...[
            DsGaps.vSm,
            Row(
              children: [
                Icon(
                  Icons.local_mall_outlined,
                  size: DsSizes.iconXs,
                  color: c.onSurfaceVariant,
                ),
                DsGaps.hXs,
                Expanded(
                  child: Text(
                    context.l10n.contentAddToMyPageProduct(tag.product.title),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.caption.tint(c.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
          DsGaps.vLg,
          DsInputField(
            controller: _note,
            label: context.l10n.contentAddToMyPageNote,
            hint: context.l10n.contentAddToMyPageNoteHint,
            maxLines: 3,
          ),
          DsGaps.vLg,
          PrimaryButton(
            label: context.l10n.contentAddToMyPageConfirm,
            onPressed: () => Navigator.of(context).pop(_note.text.trim()),
          ),
        ],
      ),
    );
  }
}
