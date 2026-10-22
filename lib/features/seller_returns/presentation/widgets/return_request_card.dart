import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/features/seller_returns/domain/entities/return_request.dart';
import 'package:reem/features/seller_returns/presentation/return_labels.dart';

/// One return in the queue.
///
/// The card leads with the *reason* rather than the return number, because
/// that is what decides what she does next: «القطعة معطوبة» and «غيّرت رأيها»
/// are the same request to the database and two different conversations.
class ReturnRequestCard extends StatelessWidget {
  const ReturnRequestCard({
    super.key,
    required this.request,
    required this.isActing,
    required this.onOpen,
    this.onPrimaryAction,
  });

  final ReturnRequest request;
  final bool isActing;
  final VoidCallback onOpen;

  /// The single most likely next move, offered inline so a routine acceptance
  /// does not need a trip through the detail screen.
  final void Function(ReturnAction action)? onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;
    final primary = request.availableActions.firstOrNull;

    return SellerPanel(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.returnReasonLabel(request.reason),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.tileTitle.bold.tint(palette.ink),
                ),
              ),
              SellerStatusPill(
                label: context.returnStatusLabel(request.status),
                icon: Icons.circle,
                color: context.returnStatusColor(request.status),
              ),
            ],
          ),
          DsGaps.vXxxs,
          Text(
            '${request.number} · '
            '${l10n.returnParcelLabel(request.parcel.sellerOrderNumber)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.caption.tint(palette.muted),
          ),

          const SizedBox(height: DsSpacing.sm),
          _ItemStrip(items: request.items),

          if (request.refund case final RefundQuote refund) ...[
            const SizedBox(height: DsSpacing.sm),
            Row(
              children: [
                Text(
                  refund.settled
                      ? l10n.returnRefundSettled
                      : l10n.returnRefundQuote,
                  style: context.dsText.caption.tint(palette.muted),
                ),
                const SizedBox(width: DsSpacing.xs),
                Text(
                  refund.amount.format(),
                  style: context.dsText.labelMedium.bold.tint(refund.settled ? palette.ink : palette.muted),
                ),
              ],
            ),
          ],

          if (primary != null && onPrimaryAction != null) ...[
            const SizedBox(height: DsSpacing.md),
            if (isActing)
              const Center(
                child: DsLoadingIndicator.inline(),
              )
            else
              DsButton(
                label: context.returnActionLabel(primary),
                icon: context.returnActionIcon(primary),
                variant: DsButtonVariant.secondary,
                onPressed: () => onPrimaryAction!(primary),
              ),
          ],
        ],
      ),
    );
  }
}

/// The goods coming back, as thumbnails with a quantity badge. A return of
/// three of one thing and one of another is a different parcel to pack than a
/// single item, and the strip says so at a glance.
class _ItemStrip extends StatelessWidget {
  const _ItemStrip({required this.items});

  final List<ReturnLine> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.xs),
        itemBuilder: (context, index) {
          final line = items[index];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: DsRadius.borderSm,
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: line.image == null
                      ? ColoredBox(
                          color: palette.background,
                          child: Icon(
                            Icons.image_outlined,
                            size: 18,
                            color: palette.muted,
                          ),
                        )
                      : AuthorizedMediaImage(
                          url: line.image!,
                          variantWidth: MediaVariants.thumbnail,
                        ),
                ),
              ),
              if (line.quantity > 1)
                PositionedDirectional(
                  bottom: -4,
                  end: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xxs),
                    decoration: BoxDecoration(
                      color: palette.primary,
                      borderRadius: DsRadius.borderPill,
                      border: Border.all(color: palette.surface, width: 1.5),
                    ),
                    child: Text(
                      '${line.quantity}',
                      style: context.dsText.micro.bold.tint(palette.onPrimary),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
