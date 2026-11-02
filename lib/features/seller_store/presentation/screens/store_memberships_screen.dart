import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/network/interceptors/store_context_interceptor.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/seller_store/domain/entities/seller_store.dart';
import 'package:ohara/features/seller_store/presentation/providers/seller_store_providers.dart';
import 'package:ohara/features/seller_store/presentation/screens/store_team_screen.dart';

/// «متاجر بشتغل فيها» — a team member's side: invitations to answer, and
/// the shops she works in, each opened from her own account.
class StoreMembershipsScreen extends ConsumerWidget {
  const StoreMembershipsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final memberships = ref.watch(storeMembershipsProvider);
    return OharaScrollPage(
      onRefresh: () async => ref.invalidate(storeMembershipsProvider),
      slivers: [
        PremiumAppBar(title: l10n.membershipsTitle, showBack: true),
        SliverPadding(
          padding: DsSpacing.paddingLg,
          sliver: SliverToBoxAdapter(
            child: memberships.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(DsSpacing.xxl),
                child: Center(child: DsLoadingIndicator()),
              ),
              error: (error, _) => DsErrorState(
                message: '$error',
                onRetry: () => ref.invalidate(storeMembershipsProvider),
              ),
              data: (list) => list.isEmpty
                  ? DsEmptyState(
                      icon: Icons.storefront_outlined,
                      title: l10n.membershipsEmpty,
                      message: l10n.membershipsEmptyBody,
                    )
                  : Column(
                      children: [
                        for (final membership in list) ...[
                          _MembershipCard(membership: membership),
                          DsGaps.vSm,
                        ],
                      ],
                    ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: DsGaps.bottomSafe),
      ],
    );
  }
}

class _MembershipCard extends ConsumerWidget {
  const _MembershipCard({required this.membership});

  final StoreMembership membership;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DsAvatar(
                imageUrl: membership.storeImageUrl,
                name: membership.storeName,
                size: 48,
              ),
              DsGaps.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      membership.isActive
                          ? membership.storeName
                          : l10n.membershipInviteFrom(membership.storeName),
                      style: context.dsText.tileTitle.bold.tint(
                        colors.onSurface,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          membership.role.icon,
                          size: 14,
                          color: colors.onSurfaceVariant,
                        ),
                        DsGaps.hXxs,
                        Flexible(
                          child: Text(
                            '${membership.role.label(l10n)} · ${membership.role.hint(l10n)}',
                            style: context.dsText.caption.tint(
                              colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          DsGaps.vMd,
          if (membership.isActive)
            Row(
              children: [
                Expanded(
                  child: DsButton(
                    label: l10n.membershipOpen,
                    icon: Icons.storefront_rounded,
                    onPressed: () => context.push(
                      RoutePaths.storeWorkspace,
                      extra: membership,
                    ),
                  ),
                ),
                DsGaps.hSm,
                IconButton(
                  tooltip: l10n.membershipLeave,
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: () => _leave(context, ref),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: DsButton(
                    label: l10n.membershipAccept,
                    icon: Icons.check_rounded,
                    onPressed: () => _respond(context, ref, 'accept'),
                  ),
                ),
                DsGaps.hSm,
                Expanded(
                  child: DsButton(
                    label: l10n.membershipDecline,
                    variant: DsButtonVariant.ghost,
                    onPressed: () => _respond(context, ref, 'decline'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    String verb,
  ) async {
    final l10n = context.l10n;
    try {
      await storeCall(
        () => ref.read(sellerStoreApiProvider).respond(membership.id, verb),
      );
      ref.invalidate(storeMembershipsProvider);
      if (context.mounted) {
        DsSnackbar.success(
          context,
          verb == 'accept' ? l10n.membershipAccepted : l10n.membershipDeclined,
        );
      }
    } catch (error) {
      if (context.mounted) DsSnackbar.error(context, '$error');
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await DsBottomSheet.show<bool>(
      context,
      builder: (sheet) => DsSheetScaffold(
        title: l10n.membershipLeaveConfirm(membership.storeName),
        child: Column(
          children: [
            DsButton(
              label: l10n.membershipLeave,
              variant: DsButtonVariant.danger,
              onPressed: () => Navigator.of(sheet).pop(true),
            ),
            DsGaps.vSm,
            DsButton(
              label: l10n.cancel,
              variant: DsButtonVariant.ghost,
              onPressed: () => Navigator.of(sheet).pop(false),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await storeCall(
        () => ref.read(sellerStoreApiProvider).respond(membership.id, 'leave'),
      );
      ref.invalidate(storeMembershipsProvider);
      if (context.mounted) DsSnackbar.success(context, l10n.membershipLeft);
    } catch (error) {
      if (context.mounted) DsSnackbar.error(context, '$error');
    }
  }
}

/// A shop she works for, open: every request from here runs as the shop,
/// within her role, until she leaves this page.
class StoreWorkspaceScreen extends StatefulWidget {
  const StoreWorkspaceScreen({super.key, required this.membership});

  final StoreMembership membership;

  @override
  State<StoreWorkspaceScreen> createState() => _StoreWorkspaceScreenState();
}

class _StoreWorkspaceScreenState extends State<StoreWorkspaceScreen> {
  @override
  void initState() {
    super.initState();
    StoreActingContext.enter(widget.membership.storeId);
  }

  @override
  void dispose() {
    StoreActingContext.leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final role = widget.membership.role;
    final canOrders = role != StoreTeamRole.catalog;
    final canProducts = role != StoreTeamRole.orders;
    return OharaScrollPage(
      background: const SellerAtelierBackground(),
      backgroundColor: context.atelier.background,
      slivers: [
        AtelierAppBar(
          icon: Icons.storefront_rounded,
          title: widget.membership.storeName,
          subtitle: l10n.workspaceActingAs(widget.membership.storeName),
          showBack: true,
        ),
        DsGaps.sliverMd,
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: atelierGutter(context)),
          sliver: SliverList.list(
            children: [
              if (canOrders) ...[
                _WorkspaceTile(
                  icon: Icons.today_rounded,
                  label: l10n.courierDay,
                  onTap: () => context.push(RoutePaths.sellerTodayOrders),
                ),
                DsGaps.vSm,
                _WorkspaceTile(
                  icon: Icons.receipt_long_rounded,
                  label: l10n.workspaceOrders,
                  onTap: () => context.push(RoutePaths.storeWorkspaceOrders),
                ),
                DsGaps.vSm,
              ],
              if (canProducts) ...[
                _WorkspaceTile(
                  icon: Icons.inventory_2_rounded,
                  label: l10n.workspaceProducts,
                  onTap: () => context.push(RoutePaths.storeWorkspaceProducts),
                ),
                DsGaps.vSm,
              ],
              if (role == StoreTeamRole.manager) ...[
                _WorkspaceTile(
                  icon: Icons.local_offer_rounded,
                  label: l10n.myProducts,
                  onTap: () => context.push(RoutePaths.sellerMyOffers),
                ),
                DsGaps.vSm,
                _WorkspaceTile(
                  icon: Icons.policy_rounded,
                  label: l10n.sellerStorePolicies,
                  onTap: () => context.push(RoutePaths.sellerStorePolicies),
                ),
                DsGaps.vSm,
                _WorkspaceTile(
                  icon: Icons.local_shipping_rounded,
                  label: l10n.sellerShippingSettings,
                  onTap: () => context.push(RoutePaths.sellerShippingSettings),
                ),
              ],
            ],
          ),
        ),
        const SliverToBoxAdapter(child: DsGaps.bottomSafe),
      ],
    );
  }
}

class _WorkspaceTile extends StatelessWidget {
  const _WorkspaceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return SellerPanel(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: palette.gold),
          DsGaps.hMd,
          Expanded(
            child: Text(
              label,
              style: context.dsText.tileTitle.bold.tint(palette.ink),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: palette.muted),
        ],
      ),
    );
  }
}
