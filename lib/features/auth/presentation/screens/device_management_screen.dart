import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/design_system/components/snackbars/app_snackbar.dart'
    show DsSnackbar, DsSnackbarType;
import 'package:reem/core/result/result.dart';

import '../providers/auth_account_provider.dart';
import '../providers/auth_provider.dart';
import '../../../../core/localization/l10n_extension.dart';

class DeviceManagementScreen extends ConsumerWidget {
  const DeviceManagementScreen({super.key});

  Future<void> _rename(BuildContext context, WidgetRef ref, String id) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.renameDevice),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: context.l10n.deviceName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    final result = await ref
        .read(authRepositoryProvider)
        .renameDevice(id: id, name: name);
    if (!context.mounted) return;
    _handleVoidResult(context, ref, result);
  }

  // `_trust` is gone with the endpoint behind it. Declaring a device trusted
  // took nothing but a live session and a device id, which made "trusted
  // device" a claim the client could simply assert — and one an attacker
  // holding a stolen token could assert about their own handset. Trust is now
  // conferred by completing a code on the device itself, and by nothing else,
  // so there is no button for it.

  Future<void> _revoke(BuildContext context, WidgetRef ref, String id) async {
    final result = await ref.read(authRepositoryProvider).revokeDevice(id);
    if (!context.mounted) return;
    _handleVoidResult(context, ref, result);
  }

  void _handleVoidResult<T>(
    BuildContext context,
    WidgetRef ref,
    Result<T> result,
  ) {
    switch (result) {
      case Success():
        ref.invalidate(accountDevicesProvider);
        DsSnackbar.show(
          context,
          message: context.l10n.deviceUpdated,
          type: DsSnackbarType.success,
        );
      case Error(:final failure):
        DsSnackbar.show(
          context,
          message: failure.message,
          type: DsSnackbarType.error,
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(accountDevicesProvider);
    final colors = context.dsColors;

    return ReemScrollPage(
      slivers: [
        PremiumAppBar(title: context.l10n.devices, showBack: true),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.huge,
            DsSpacing.lg,
            120,
          ),
          sliver: devices.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: DsLoadingIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              child: Center(child: Text(error.toString())),
            ),
            data: (items) {
              if (items.isEmpty) {
                return SliverFillRemaining(
                  child: Center(child: Text(context.l10n.noDevicesYet)),
                );
              }
              return SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.sm),
                itemBuilder: (context, index) {
                  final device = items[index];
                  return Semantics(
                    button: false,
                    label: '${device.name}, ${device.trustLevel}',
                    child: Material(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(DsRadius.md),
                      child: ListTile(
                        leading: Icon(Icons.devices_outlined, color: colors.primary),
                        title: Text(device.name),
                        subtitle: Text(
                          device.isTrusted
                              ? context.l10n.deviceTrusted
                              : context.l10n.deviceNotVerified,
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'rename') {
                              _rename(context, ref, device.id);
                            } else if (value == 'revoke') {
                              _revoke(context, ref, device.id);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'rename', child: Text(context.l10n.rename)),
                            PopupMenuItem(value: 'revoke', child: Text(context.l10n.revoke)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
