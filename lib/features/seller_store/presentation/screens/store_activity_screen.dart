import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/utils/relative_time.dart';
import 'package:ohara/features/seller_store/domain/entities/seller_store.dart';
import 'package:ohara/features/seller_store/presentation/providers/seller_store_providers.dart';
import 'package:ohara/features/seller_store/presentation/widgets/store_form_parts.dart';
import 'package:ohara/l10n/app_localizations.dart';

/// «سجل النشاط» — what happened on the shop, who did it, from which device.
class StoreActivityScreen extends ConsumerStatefulWidget {
  const StoreActivityScreen({super.key});

  @override
  ConsumerState<StoreActivityScreen> createState() =>
      _StoreActivityScreenState();
}

class _StoreActivityScreenState extends ConsumerState<StoreActivityScreen> {
  final _entries = <ActivityEntry>[];
  String? _next;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
      }
    });
    try {
      final page = await storeCall(
        () => ref
            .read(sellerStoreApiProvider)
            .activity(before: more ? _next : null),
      );
      if (!mounted) return;
      setState(() {
        if (!more) _entries.clear();
        _entries.addAll(page.entries);
        _next = page.nextBefore;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StoreSettingsPage(
      icon: Icons.history_rounded,
      title: l10n.sellerActivityLog,
      subtitle: l10n.activitySubtitle,
      onRefresh: _load,
      child: _loading
          ? const StoreLoading()
          : _error != null && _entries.isEmpty
          ? DsErrorState(message: _error, onRetry: _load)
          : _entries.isEmpty
          ? DsEmptyState(
              icon: Icons.history_toggle_off_rounded,
              title: l10n.activityEmpty,
              message: l10n.activityEmptyBody,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, entry) in _entries.indexed) ...[
                  if (index == 0 ||
                      !_sameDay(_entries[index - 1].createdAt, entry.createdAt))
                    Padding(
                      padding: EdgeInsets.only(
                        top: index == 0 ? 0 : DsSpacing.md,
                        bottom: DsSpacing.xs,
                      ),
                      child: AtelierHeading(
                        title: formatChatDay(l10n, entry.createdAt),
                      ),
                    ),
                  _EntryTile(entry: entry),
                  DsGaps.vXs,
                ],
                if (_next != null) ...[
                  DsGaps.vSm,
                  DsButton(
                    label: l10n.activityLoadMore,
                    variant: DsButtonVariant.ghost,
                    isLoading: _loadingMore,
                    onPressed: _loadingMore ? null : () => _load(more: true),
                  ),
                ],
              ],
            ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final (label, icon) = describeActivity(l10n, entry.action);
    final who = entry.byOwner
        ? l10n.activityByYou
        : (entry.actorName ?? l10n.activityByYou);
    final device = switch (entry.device) {
      'ios' => l10n.activityDeviceIos,
      'android' => l10n.activityDeviceAndroid,
      'app' => l10n.activityDeviceApp,
      'web' => l10n.activityDeviceWeb,
      _ => null,
    };
    return SellerPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.md,
        vertical: DsSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (entry.succeeded ? palette.gold : palette.critical)
                  .withValues(alpha: 0.12),
              borderRadius: DsRadius.borderMd,
            ),
            child: Icon(
              entry.succeeded ? icon : Icons.block_rounded,
              size: 18,
              color: entry.succeeded ? palette.gold : palette.critical,
            ),
          ),
          DsGaps.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.succeeded ? label : '$label · ${l10n.activityRefused}',
                  style: context.dsText.body.tint(palette.ink),
                ),
                Text(
                  [
                    who,
                    formatMessageTime(l10n, entry.createdAt),
                    ?device,
                  ].join(' · '),
                  style: context.dsText.caption.tint(palette.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What a recorded action was, in her words, with an icon. Routes are
/// matched by their shape; anything unknown reads as a store change.
(String, IconData) describeActivity(AppLocalizations l10n, String action) {
  final verb = action.split(' ').first;
  final path = action.contains(' ') ? action.substring(action.indexOf(' ') + 1) : action;
  bool has(String part) => path.contains(part);

  if (action == 'login') return (l10n.actLogin, Icons.login_rounded);
  if (action.startsWith('phone_change')) {
    return (l10n.actPhoneChange, Icons.phone_iphone_rounded);
  }
  if (has('/seller/orders')) {
    if (has('/confirm')) return (l10n.actOrderConfirm, Icons.check_rounded);
    if (has('/ready')) return (l10n.actOrderReady, Icons.inventory_2_outlined);
    if (has('/hand-over')) {
      return (l10n.actOrderHandOver, Icons.local_shipping_outlined);
    }
    if (has('/deliver')) return (l10n.actOrderDeliver, Icons.home_outlined);
    if (has('/cancel')) return (l10n.actOrderCancel, Icons.cancel_outlined);
  }
  if (has('/seller/products')) {
    if (has('/variants')) return (l10n.actVariant, Icons.palette_outlined);
    return verb == 'POST'
        ? (l10n.actProductAdd, Icons.add_box_outlined)
        : (l10n.actProductEdit, Icons.edit_outlined);
  }
  if (has('/seller/offers')) {
    if (has('/stock')) return (l10n.actStock, Icons.inventory_outlined);
    return switch (verb) {
      'POST' => (l10n.actOfferAdd, Icons.sell_outlined),
      'DELETE' => (l10n.actOfferRemove, Icons.remove_shopping_cart_outlined),
      _ => (l10n.actOfferEdit, Icons.price_change_outlined),
    };
  }
  if (has('/store-settings/policies')) {
    return (l10n.actPolicies, Icons.policy_outlined);
  }
  if (has('/store-settings/shipping')) {
    return (l10n.actShipping, Icons.local_shipping_outlined);
  }
  if (has('/seller/team')) {
    return switch (verb) {
      'POST' => (l10n.actTeamInvite, Icons.person_add_alt_1_outlined),
      'DELETE' => (l10n.actTeamRemove, Icons.person_remove_outlined),
      _ => (l10n.actTeamRole, Icons.manage_accounts_outlined),
    };
  }
  if (has('/payout-account')) {
    return (l10n.actPayoutAccount, Icons.credit_card_outlined);
  }
  if (has('/seller/payouts')) {
    return has('/cancel')
        ? (l10n.actPayoutCancel, Icons.undo_rounded)
        : (l10n.actPayoutRequest, Icons.account_balance_wallet_outlined);
  }
  if (has('/seller/coupons')) {
    return (l10n.actCoupon, Icons.confirmation_number_outlined);
  }
  if (has('/seller/posts') || has('/seller/content') || has('/content')) {
    return (l10n.actPost, Icons.photo_library_outlined);
  }
  if (has('/seller/stories')) return (l10n.actStory, Icons.amp_stories_outlined);
  if (has('/returns')) {
    return (l10n.actReturn, Icons.assignment_return_outlined);
  }
  if (has('/reputation/seller')) {
    return (l10n.actReviewReply, Icons.reviews_outlined);
  }
  if (has('/ads') || has('/promotions')) {
    return (l10n.actAds, Icons.campaign_outlined);
  }
  if (action.startsWith('payout.')) {
    return (l10n.actPayoutRequest, Icons.account_balance_wallet_outlined);
  }
  return (l10n.actGeneric, Icons.storefront_outlined);
}
