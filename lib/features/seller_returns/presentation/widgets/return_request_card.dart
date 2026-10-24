import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/authorized_media_image.dart';
import 'package:ohara/core/media/media_variants.dart';
import 'package:ohara/features/seller_returns/domain/entities/return_request.dart';
import 'package:ohara/features/seller_returns/presentation/return_labels.dart';

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

    final tone = context.returnStatusColor(request.status);

    // A return is a ticket like an order: the job on the body, the refund
    // and the state on the stub.
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.returnReasonLabel(request.reason),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.dsText.tileTitle.bold.tint(palette.ink),
        ),
        DsGaps.vXxxs,
        Text(
          '${request.number} · '
          '${l10n.returnParcelLabel(request.parcel.sellerOrderNumber)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.dsText.caption.tint(palette.muted),
        ),
        DsGaps.vSm,
        _ItemStrip(items: request.items),
        if (primary != null && onPrimaryAction != null) ...[
          DsGaps.vMd,
          if (isActing)
            const Center(child: DsLoadingIndicator.inline())
          else
            DsButton(
              label: context.returnActionLabel(primary),
              icon: context.returnActionIcon(primary),
              variant: DsButtonVariant.secondary,
              size: DsButtonSize.sm,
              onPressed: () => onPrimaryAction!(primary),
            ),
        ],
      ],
    );

    final refund = request.refund;
    final stub = Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          context.returnStatusLabel(request.status),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.dsText.captionStrong.tint(tone),
        ),
        if (refund != null)
          Column(
            children: [
              Text(
                refund.settled
                    ? l10n.returnRefundSettled
                    : l10n.returnRefundQuote,
                textAlign: TextAlign.center,
                style: context.dsText.micro.tint(palette.muted),
              ),
              DsGaps.vXxxs,
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  refund.amount.format(),
                  style: context.dsText.tileTitle.displayFamily.bold.tint(
                    refund.settled ? palette.ink : palette.gold,
                  ),
                ),
              ),
            ],
          ),
        Icon(Icons.chevron_right_rounded, size: DsSizes.iconSm, color: tone),
      ],
    );

    return Semantics(
      button: true,
      label:
          '${context.returnReasonLabel(request.reason)}، '
          '${context.returnStatusLabel(request.status)}',
      child: OrderTicket(
        onTap: onOpen,
        stubColor: tone,
        body: body,
        stub: stub,
      ),
    );
  }
}

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
