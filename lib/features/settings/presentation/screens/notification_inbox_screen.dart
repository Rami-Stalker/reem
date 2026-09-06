import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/utils/relative_time.dart';
import 'package:reem/features/settings/domain/entities/notification_entity.dart';
import 'package:reem/features/settings/presentation/providers/settings_provider.dart';

/// What the shop has told her, newest first.
///
/// The list was fetched long before this screen existed and then dropped on the
/// floor: `/notifications` opened the preferences page, so the bell, the home
/// summary, the Activity hub and the Settings row all led to a page of toggles
/// and there was no way to read a single notice. Preferences now live at their
/// own path, and this is what those four entrances open.
class NotificationInboxScreen extends ConsumerWidget {
  const NotificationInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(notificationInboxProvider);
    final notifier = ref.read(notificationInboxProvider.notifier);

    return ReemScrollPage(
      onRefresh: notifier.load,
      slivers: [
        PremiumAppBar(
          title: l10n.notificationInboxTitle,
          subtitle: state.unreadCount == 0
              ? null
              : l10n.notificationUnreadCount(state.unreadCount),
          showBack: true,
          actions: [
            IconButton(
              tooltip: l10n.notificationPreferencesTitle,
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => context.push(RoutePaths.notificationPreferences),
            ),
          ],
        ),
        if (state.isLoading && state.items.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: DsLoadingIndicator(),
          )
        else if (state.error != null && state.items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: DsEmptyState(
              icon: Icons.notifications_off_outlined,
              title: l10n.notificationInboxLoadFailed,
              message: state.error,
              actionLabel: l10n.retry,
              onAction: notifier.load,
            ),
          )
        else if (state.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: DsEmptyState(
              icon: Icons.notifications_none_rounded,
              title: l10n.notificationInboxEmptyTitle,
              message: l10n.notificationInboxEmptyBody,
            ),
          )
        else ...[
          if (state.unreadCount > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  DsSpacing.lg,
                  DsSpacing.sm,
                  DsSpacing.lg,
                  0,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: Text(l10n.notificationMarkAllRead),
                    onPressed: () async {
                      final ok = await notifier.markAllRead();
                      if (!context.mounted) return;
                      if (ok) {
                        DsSnackbar.success(context, l10n.notificationAllRead);
                      }
                    },
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.lg,
              DsSpacing.sm,
              DsSpacing.lg,
              DsSizes.bottomSafeGap,
            ),
            sliver: SliverList.separated(
              itemCount: state.items.length,
              separatorBuilder: (_, _) => DsGaps.vSm,
              itemBuilder: (_, i) {
                final notification = state.items[i];
                return _NotificationTile(
                  notification: notification,
                  onTap: () {
                    notifier.markRead(notification);
                    final destination = _destinationOf(notification);
                    if (destination != null) context.push(destination);
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  /// Where a notification points, when it points anywhere.
  ///
  /// Read off the `data` payload the server already attaches. A notice with
  /// nothing to open simply marks itself read.
  static String? _destinationOf(NotificationEntity notification) {
    final data = notification.data;
    String? id(String key) {
      final value = data[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    // A room notice opens the room it folded — which is the whole reason the
    // coalesced line keeps its `room_id` rather than the id of whichever
    // gesture happened to arrive last.
    final roomId = id('room_id');
    if (roomId != null) return RoutePaths.roomOf(roomId);

    final orderId = id('order_id');
    if (orderId != null) return RoutePaths.orderDetailOf(orderId);

    final productId = id('product_id');
    if (productId != null) return RoutePaths.productDetailsOf(productId);

    final userId = id('user_id') ?? id('follower_id');
    if (userId != null) return RoutePaths.userProfileOf(userId);

    if (id('chat_id') != null) return RoutePaths.chats;

    return switch (notification.type) {
      NotificationEntityType.coupon => RoutePaths.coupons,
      NotificationEntityType.promo => RoutePaths.coupons,
      NotificationEntityType.message => RoutePaths.chats,
      _ => null,
    };
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final NotificationEntity notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final text = context.dsText;
    final unread = !notification.isRead;

    return CustomerPanel(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: DsSizes.iconXxl,
            height: DsSizes.iconXxl,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: unread
                  ? colors.primary.withValues(alpha: 0.14)
                  : colors.surfaceVariant,
              borderRadius: DsRadius.borderMd,
            ),
            child: Icon(
              _icon(notification.type),
              size: DsSizes.iconSm,
              color: unread ? colors.primary : colors.onSurfaceVariant,
            ),
          ),
          DsGaps.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  notification.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: unread ? text.cardTitle.bold : text.cardTitle,
                ),
                if (notification.body.isNotEmpty) ...[
                  DsGaps.vXxs,
                  Text(
                    notification.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: text.cardSubtitle,
                  ),
                ],
                DsGaps.vXxs,
                Text(
                  formatRelativeTime(context.l10n, notification.createdAt),
                  style: text.caption,
                ),
              ],
            ),
          ),
          // The unread dot sits beside the row rather than tinting the whole
          // card: a page where most rows are unread should still read as a
          // list, not as a wall of highlight.
          if (unread) ...[
            DsGaps.hSm,
            Container(
              width: DsSpacing.xs,
              height: DsSpacing.xs,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static IconData _icon(NotificationEntityType type) => switch (type) {
    NotificationEntityType.like => Icons.favorite_rounded,
    NotificationEntityType.comment => Icons.mode_comment_outlined,
    NotificationEntityType.follow => Icons.person_add_alt_1_rounded,
    NotificationEntityType.message => Icons.chat_bubble_outline_rounded,
    NotificationEntityType.order => Icons.local_shipping_outlined,
    NotificationEntityType.payment => Icons.payments_outlined,
    NotificationEntityType.post => Icons.photo_outlined,
    NotificationEntityType.story => Icons.auto_stories_outlined,
    NotificationEntityType.promo => Icons.campaign_outlined,
    NotificationEntityType.coupon => Icons.local_offer_outlined,
    NotificationEntityType.room => Icons.meeting_room_outlined,
    NotificationEntityType.system => Icons.info_outline_rounded,
  };
}
