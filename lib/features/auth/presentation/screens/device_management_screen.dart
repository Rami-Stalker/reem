import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/design_system/components/snackbars/app_snackbar.dart'
    show DsSnackbar, DsSnackbarType;
import 'package:reem/core/result/result.dart';

import '../providers/auth_account_provider.dart';
import '../providers/auth_provider.dart';

class DeviceManagementScreen extends ConsumerWidget {
  const DeviceManagementScreen({super.key});

  Future<void> _rename(BuildContext context, WidgetRef ref, String id) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename device'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Device name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
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

  Future<void> _trust(BuildContext context, WidgetRef ref, String id) async {
    final result = await ref.read(authRepositoryProvider).trustDevice(id);
    if (!context.mounted) return;
    _handleVoidResult(context, ref, result);
  }

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
          message: 'Device updated.',
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
        PremiumAppBar(title: 'Devices', showBack: true),
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
                return const SliverFillRemaining(
                  child: Center(child: Text('No devices yet.')),
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
                          '${device.platform ?? 'unknown'} • ${device.trustLevel}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'rename') {
                              _rename(context, ref, device.id);
                            } else if (value == 'trust') {
                              _trust(context, ref, device.id);
                            } else if (value == 'revoke') {
                              _revoke(context, ref, device.id);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'rename', child: Text('Rename')),
                            PopupMenuItem(value: 'trust', child: Text('Trust')),
                            PopupMenuItem(value: 'revoke', child: Text('Revoke')),
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
