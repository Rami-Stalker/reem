import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/shared/entities/media.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/features/chat/domain/entities/chat_message_entity.dart';
import 'package:ohara/features/chat/presentation/providers/chat_provider.dart';
import 'package:ohara/features/checkout/domain/entities/order.dart';
import 'package:ohara/features/checkout/presentation/order_labels.dart';
import 'package:ohara/features/discovery/presentation/providers/discovery_providers.dart';

/// «أرسلي قطعة» — the boutique's pieces, to send one as a card.
///
/// The boutique's own shelf whichever side opens it: a shopper sends the piece
/// she is asking about, a boutique sends a piece she suggests.
abstract final class ChatProductPicker {
  static Future<Product?> show(
    BuildContext context, {
    required String sellerId,
  }) {
    return DsBottomSheet.show<Product>(
      context,
      builder: (_) => DsSheetScaffold(
        title: context.l10n.chatPickProductTitle,
        scrollable: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: _ProductList(sellerId: sellerId),
        ),
      ),
    );
  }
}

class _ProductList extends ConsumerWidget {
  const _ProductList({required this.sellerId});

  final String sellerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerProductsProvider(sellerId));
    final notifier = ref.read(sellerProductsProvider(sellerId).notifier);
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: DsLoadingIndicator());
    }
    if (state.hasError) {
      return DsErrorState(message: state.error, onRetry: notifier.load);
    }
    if (state.items.isEmpty) {
      return DsEmptyState(
        icon: Icons.shopping_bag_outlined,
        title: context.l10n.chatNoProductsToSend,
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 300 &&
            state.hasNextPage &&
            !state.isLoadingMore) {
          notifier.loadMore();
        }
        return false;
      },
      child: ListView.separated(
        itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
        separatorBuilder: (_, _) => DsGaps.vSm,
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
            return const Center(child: DsLoadingIndicator.inline());
          }
          final product = state.items[index];
          return _PickRow(
            imageUrl: product.coverUrl,
            title: product.title,
            subtitle: product.price?.format(),
            onTap: () => Navigator.of(context).pop(product),
          );
        },
      ),
    );
  }
}

/// «أرسلي طلب» — the orders between the two of them, to send one as a card.
abstract final class ChatOrderPicker {
  static Future<ChatOrderRef?> show(
    BuildContext context, {
    required String chatId,
  }) {
    return DsBottomSheet.show<ChatOrderRef>(
      context,
      builder: (_) => DsSheetScaffold(
        title: context.l10n.chatPickOrderTitle,
        scrollable: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.5,
          child: _OrderList(chatId: chatId),
        ),
      ),
    );
  }
}

final _chatOrdersProvider = FutureProvider.autoDispose
    .family<List<ChatOrderRef>, String>((ref, chatId) async {
      final result = await ref.watch(chatRepositoryProvider).orders(chatId);
      return switch (result) {
        Success(:final data) => data,
        Error(:final failure) => throw failure.message,
      };
    });

class _OrderList extends ConsumerWidget {
  const _OrderList({required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(_chatOrdersProvider(chatId));
    return orders.when(
      loading: () => const Center(child: DsLoadingIndicator()),
      error: (error, _) => DsErrorState(
        message: '$error',
        onRetry: () => ref.invalidate(_chatOrdersProvider(chatId)),
      ),
      data: (list) => list.isEmpty
          ? DsEmptyState(
              icon: Icons.receipt_long_outlined,
              title: context.l10n.chatNoOrdersToSend,
            )
          : ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => DsGaps.vSm,
              itemBuilder: (context, index) {
                final order = list[index];
                return _PickRow(
                  imageUrl: order.imageUrl,
                  title: '\u2066${order.number}\u2069',
                  subtitle: [
                    context.l10n.customerParcelStatus(
                      SellerOrderStatus.fromWire(order.status),
                    ),
                    ?order.total?.format(),
                  ].join(' · '),
                  onTap: () => Navigator.of(context).pop(order),
                );
              },
            ),
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.title,
    required this.onTap,
    this.imageUrl,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Material(
      color: colors.surface,
      borderRadius: DsRadius.borderLg,
      child: InkWell(
        borderRadius: DsRadius.borderLg,
        onTap: onTap,
        child: Padding(
          padding: DsSpacing.paddingSm,
          child: Row(
            children: [
              _Thumb(url: imageUrl),
              DsGaps.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.bodyStrong,
                    ),
                    if (subtitle case final s? when s.isNotEmpty) ...[
                      DsGaps.vXxs,
                      Text(
                        s,
                        style: context.dsText.bodySmall.tint(
                          colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.send_rounded,
                size: DsSizes.iconSm,
                color: colors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final image = url;
    return ClipRRect(
      borderRadius: DsRadius.borderMd,
      child: SizedBox.square(
        dimension: DsSizes.thumbMd,
        child: image == null || image.isEmpty
            ? const DsMediaFallback()
            : DsMediaFrame(
                item: MediaItem(url: image, type: MediaType.image),
              ),
      ),
    );
  }
}

/// An order in a conversation: its photo, number, state and total. A tap
/// opens it — her order for the shopper, the parcel for the boutique.
class ChatOrderCard extends StatelessWidget {
  const ChatOrderCard({
    super.key,
    required this.order,
    required this.isMe,
    required this.forSeller,
  });

  final ChatOrderRef order;
  final bool isMe;

  /// The boutique's side opens her parcel screen rather than the shopper's.
  final bool forSeller;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: l10n.chatOpenOrder,
      child: GestureDetector(
        onTap: () => context.push(
          forSeller
              ? RoutePaths.sellerOrderDetailFor(order.sellerOrderId)
              : RoutePaths.orderDetailOf(order.id),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: DsSpacing.paddingSm,
          decoration: BoxDecoration(
            color: isMe ? colors.primaryContainer : colors.surface,
            borderRadius: DsRadius.borderLg,
            border: Border.all(color: colors.border.withValues(alpha: 0.7)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Thumb(url: order.imageUrl),
              DsGaps.hSm,
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: DsSizes.iconXs,
                          color: colors.primary,
                        ),
                        DsGaps.hXxs,
                        Flexible(
                          child: Text(
                            '\u2066${order.number}\u2069',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.dsText.labelStrong,
                          ),
                        ),
                      ],
                    ),
                    DsGaps.vXxs,
                    Text(
                      l10n.customerParcelStatus(
                        SellerOrderStatus.fromWire(order.status),
                      ),
                      style: context.dsText.caption.tint(colors.primary),
                    ),
                    if (order.total case final total?)
                      Text(
                        [
                          total.format(),
                          if (order.itemsCount > 1)
                            l10n.chatOrderItems(order.itemsCount),
                        ].join(' · '),
                        style: context.dsText.caption.tint(
                          colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
