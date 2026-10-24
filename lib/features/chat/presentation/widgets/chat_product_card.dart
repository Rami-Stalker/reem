import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/chat/domain/entities/chat_message_entity.dart';

/// The piece a message is about, drawn above the message itself.
///
/// The way a forwarded product looks in WhatsApp: photo, name, price, and a
/// tap that opens it. Both sides see it — the boutique reads which piece is
/// being asked about, and the shopper sees what her question was attached to.
class ChatProductCard extends StatelessWidget {
  const ChatProductCard({super.key, required this.product, required this.isMe});

  final ChatProductRef product;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;

    return Align(
      alignment: isMe
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: DsSizes.maxFormWidth * 0.7),
        child: Semantics(
          button: true,
          label: '${l10n.chatProductInquiry} ${product.title}',
          child: Material(
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: DsRadius.borderLg,
              side: BorderSide(color: colors.primary.withValues(alpha: 0.35)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () =>
                  context.push(RoutePaths.productDetailsOf(product.id)),
              child: Padding(
                padding: const EdgeInsets.all(DsSpacing.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Thumb(url: product.imageUrl, size: DsSizes.avatarLg),
                    DsGaps.hSm,
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.chatProductInquiry,
                            style: context.dsText.caption.tint(colors.primary),
                          ),
                          DsGaps.vXxxs,
                          Text(
                            product.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.dsText.bodySmall.semibold,
                          ),
                          if (product.price case final price?) ...[
                            DsGaps.vXxxs,
                            Text(
                              price.format(),
                              style: context.dsText.priceSmall.tabular,
                            ),
                          ],
                        ],
                      ),
                    ),
                    DsGaps.hXs,
                    Icon(
                      Icons.chevron_right_rounded,
                      size: DsSizes.iconSm,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «تسألين عن» — the piece pinned above the composer until she sends.
///
/// Opened from a product page, the conversation starts already holding the
/// piece, so her first message — typed, or one of the suggested questions —
/// goes out with its card. The cross lets her talk about something else.
class ChatAboutProductBar extends StatelessWidget {
  const ChatAboutProductBar({
    super.key,
    required this.product,
    required this.onClear,
  });

  final ChatProductRef product;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: colors.border.withValues(alpha: 0.6)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DsSpacing.md,
          DsSpacing.xs,
          DsSpacing.xxs,
          DsSpacing.xs,
        ),
        child: Row(
          children: [
            // The accent rule of a quoted message.
            Container(
              width: DsSpacing.xxs,
              height: DsSizes.avatarMd,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: DsRadius.borderXs,
              ),
            ),
            DsGaps.hXs,
            _Thumb(url: product.imageUrl, size: DsSizes.avatarMd),
            DsGaps.hSm,
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.chatAskingAbout,
                    style: context.dsText.caption.tint(colors.primary),
                  ),
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.bodySmall.semibold,
                  ),
                  if (product.price case final price?)
                    Text(
                      price.format(),
                      style: context.dsText.caption.tabular,
                    ),
                ],
              ),
            ),
            DsIconButton(
              icon: Icons.close_rounded,
              tooltip: l10n.chatAskingAboutClear,
              onPressed: onClear,
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final image = url;
    return ClipRRect(
      borderRadius: DsRadius.borderSm,
      child: SizedBox.square(
        dimension: size,
        child: image == null || image.isEmpty
            ? ColoredBox(
                color: colors.surfaceVariant,
                child: Icon(
                  Icons.checkroom_rounded,
                  color: colors.onSurfaceVariant,
                  size: DsSizes.iconSm,
                ),
              )
            : AuthorizedMediaImage(
                url: image,
                variantWidth: MediaVariants.thumbnail,
                fit: BoxFit.cover,
              ),
      ),
    );
  }
}
