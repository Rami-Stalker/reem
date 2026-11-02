import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/seller_store/domain/entities/seller_store.dart';
import 'package:ohara/features/seller_store/presentation/providers/seller_store_providers.dart';
import 'package:ohara/features/seller_store/presentation/widgets/store_form_parts.dart';
import 'package:ohara/l10n/app_localizations.dart';

/// The words for a team role, and what it lets a member do.
extension StoreTeamRoleLabels on StoreTeamRole {
  String label(AppLocalizations l10n) => switch (this) {
    StoreTeamRole.manager => l10n.teamRoleManager,
    StoreTeamRole.orders => l10n.teamRoleOrders,
    StoreTeamRole.catalog => l10n.teamRoleCatalog,
  };

  String hint(AppLocalizations l10n) => switch (this) {
    StoreTeamRole.manager => l10n.teamRoleManagerHint,
    StoreTeamRole.orders => l10n.teamRoleOrdersHint,
    StoreTeamRole.catalog => l10n.teamRoleCatalogHint,
  };

  IconData get icon => switch (this) {
    StoreTeamRole.manager => Icons.workspace_premium_outlined,
    StoreTeamRole.orders => Icons.receipt_long_outlined,
    StoreTeamRole.catalog => Icons.inventory_2_outlined,
  };
}

/// «إدارة الفريق» — the people who work the shop with her. Each works from
/// her own account, within the role given here; money stays with the owner.
class StoreTeamScreen extends ConsumerWidget {
  const StoreTeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final team = ref.watch(storeTeamProvider);
    return StoreSettingsPage(
      icon: Icons.group_rounded,
      title: l10n.sellerTeamManagement,
      subtitle: l10n.teamSubtitle,
      onRefresh: () async => ref.invalidate(storeTeamProvider),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StoreNotice(icon: Icons.lock_outline_rounded, text: l10n.teamMoneyNote),
          DsGaps.vLg,
          DsButton(
            label: l10n.teamInvite,
            icon: Icons.person_add_alt_1_rounded,
            onPressed: () => _InviteSheet.show(context),
          ),
          DsGaps.vLg,
          team.when(
            loading: () => const StoreLoading(),
            error: (error, _) => DsErrorState(
              message: '$error',
              onRetry: () => ref.invalidate(storeTeamProvider),
            ),
            data: (members) => members.isEmpty
                ? DsEmptyState(
                    icon: Icons.groups_2_outlined,
                    title: l10n.teamEmpty,
                    message: l10n.teamEmptyBody,
                  )
                : Column(
                    children: [
                      for (final member in members) ...[
                        _MemberTile(member: member),
                        DsGaps.vXs,
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.member});

  final StoreTeamMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.atelier;
    return SellerPanel(
      onTap: () => _actions(context, ref),
      child: Row(
        children: [
          DsAvatar(imageUrl: member.imageUrl, name: member.name, size: 44),
          DsGaps.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.tileTitle.bold.tint(palette.ink),
                ),
                Row(
                  children: [
                    Icon(member.role.icon, size: 14, color: palette.muted),
                    DsGaps.hXxs,
                    Flexible(
                      child: Text(
                        member.role.label(l10n),
                        style: context.dsText.caption.tint(palette.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!member.isActive)
            DsBadge(label: l10n.teamPending, tone: DsBadgeTone.warning),
          Icon(Icons.more_vert_rounded, color: palette.muted),
        ],
      ),
    );
  }

  Future<void> _actions(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final choice = await DsBottomSheet.show<String>(
      context,
      builder: (sheet) => DsSheetScaffold(
        title: member.name,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: Text(l10n.teamChangeRole),
              onTap: () => Navigator.of(sheet).pop('role'),
            ),
            ListTile(
              leading: Icon(
                Icons.person_remove_outlined,
                color: context.dsColors.error,
              ),
              title: Text(
                l10n.teamRemove,
                style: context.dsText.body.tint(context.dsColors.error),
              ),
              onTap: () => Navigator.of(sheet).pop('remove'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    final api = ref.read(sellerStoreApiProvider);
    try {
      if (choice == 'role') {
        final role = await _RolePicker.show(context, current: member.role);
        if (role == null || role == member.role || !context.mounted) return;
        await storeCall(() => api.changeRole(member.id, role));
        if (context.mounted) DsSnackbar.success(context, l10n.teamRoleChanged);
      } else {
        final confirmed = await DsBottomSheet.show<bool>(
          context,
          builder: (sheet) => DsSheetScaffold(
            title: l10n.teamRemoveConfirm(member.name),
            subtitle: l10n.teamRemoveBlurb,
            child: Column(
              children: [
                DsButton(
                  label: l10n.teamRemove,
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
        if (confirmed != true) return;
        await storeCall(() => api.removeMember(member.id));
        if (context.mounted) DsSnackbar.success(context, l10n.teamRemoved);
      }
      ref.invalidate(storeTeamProvider);
    } catch (error) {
      if (context.mounted) DsSnackbar.error(context, '$error');
    }
  }
}

/// The three roles as cards, each saying what it allows.
class _RolePicker extends StatelessWidget {
  const _RolePicker({required this.selected, required this.onSelect});

  final StoreTeamRole selected;
  final ValueChanged<StoreTeamRole> onSelect;

  static Future<StoreTeamRole?> show(
    BuildContext context, {
    required StoreTeamRole current,
  }) {
    return DsBottomSheet.show<StoreTeamRole>(
      context,
      builder: (sheet) => DsSheetScaffold(
        title: context.l10n.teamChangeRole,
        child: _RolePicker(
          selected: current,
          onSelect: (role) => Navigator.of(sheet).pop(role),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final role in StoreTeamRole.values)
          Padding(
            padding: const EdgeInsets.only(bottom: DsSpacing.xs),
            child: Semantics(
              selected: role == selected,
              button: true,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: DsRadius.borderLg,
                  onTap: () => onSelect(role),
                  child: AnimatedContainer(
                    duration: DsMotion.normal,
                    padding: DsSpacing.paddingMd,
                    decoration: BoxDecoration(
                      borderRadius: DsRadius.borderLg,
                      color: role == selected
                          ? palette.gold.withValues(alpha: 0.08)
                          : palette.surface,
                      border: Border.all(
                        color: role == selected ? palette.gold : palette.line,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(role.icon, color: palette.gold),
                        DsGaps.hMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                role.label(l10n),
                                style: context.dsText.tileTitle.bold.tint(
                                  palette.ink,
                                ),
                              ),
                              Text(
                                role.hint(l10n),
                                style: context.dsText.caption.tint(
                                  palette.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (role == selected)
                          Icon(Icons.check_circle_rounded, color: palette.gold),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet();

  static Future<void> show(BuildContext context) => DsBottomSheet.show<void>(
    context,
    builder: (_) => DsSheetScaffold(
      title: context.l10n.teamInvite,
      child: const _InviteSheet(),
    ),
  );

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  final _phone = TextEditingController();
  StoreTeamRole _role = StoreTeamRole.orders;
  bool _sending = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_phone.text.trim().length < 9) return;
    setState(() => _sending = true);
    final l10n = context.l10n;
    try {
      await storeCall(
        () => ref.read(sellerStoreApiProvider).invite(_phone.text.trim(), _role),
      );
      if (!mounted) return;
      ref.invalidate(storeTeamProvider);
      Navigator.of(context).pop();
      DsSnackbar.success(context, l10n.teamInvited);
    } catch (error) {
      if (mounted) DsSnackbar.error(context, '$error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsInputField(
          controller: _phone,
          label: l10n.teamInvitePhone,
          hint: l10n.teamInvitePhoneHint,
          prefixIcon: const Icon(Icons.phone_iphone_rounded),
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
        ),
        DsGaps.vMd,
        Text(
          l10n.teamInviteRole,
          style: context.dsText.labelStrong.tint(palette.ink),
        ),
        DsGaps.vXs,
        _RolePicker(
          selected: _role,
          onSelect: (role) => setState(() => _role = role),
        ),
        DsGaps.vMd,
        DsButton(
          label: l10n.teamInviteSend,
          icon: Icons.send_rounded,
          isLoading: _sending,
          onPressed: _sending ? null : _send,
        ),
      ],
    );
  }
}
