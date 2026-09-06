import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/auth/presentation/providers/auth_account_provider.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _locationController = TextEditingController();
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await ref
        .read(authRepositoryProvider)
        .updateAccount(
          name: _nameController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          location: _locationController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Success():
        ref.invalidate(authAccountProvider);
        await ref.read(authNotifierProvider.notifier).refreshUser();
        if (!mounted) return;
        DsSnackbar.show(
          context,
          message: context.l10n.accountUpdated,
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
  Widget build(BuildContext context) {
    final account = ref.watch(authAccountProvider);
    final colors = context.dsColors;

    return ReemScrollPage(
      slivers: [
        PremiumAppBar(title: context.l10n.account, showBack: true),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.huge,
            DsSpacing.lg,
            120,
          ),
          sliver: account.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: DsLoadingIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              child: Center(child: Text(error.toString())),
            ),
            data: (data) {
              if (!_seeded) {
                _nameController.text = data.user.name;
                _emailController.text = data.user.email ?? '';
                _locationController.text = data.user.location ?? '';
                _seeded = true;
              }
              return SliverList(
                delegate: SliverChildListDelegate([
                  Text(
                    context.l10n.profileIdentity,
                    style: context.dsText.screenTitle.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: DsSpacing.md),
                  DsInputField(
                    controller: _nameController,
                    label: context.l10n.fullName,
                    prefixIcon: Icon(
                      Icons.person_outline,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: DsSpacing.md),
                  DsInputField(
                    controller: _emailController,
                    label: context.l10n.email,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icon(Icons.mail_outline, color: colors.primary),
                  ),
                  const SizedBox(height: DsSpacing.md),
                  // Read-only, and it leads somewhere else.
                  //
                  // The number IS the account: it is the login, the recovery
                  // channel and the second factor at once. Editing it beside a
                  // name and a city framed a transfer of the account as a
                  // profile tweak — and it used to behave like one, taking a
                  // single code on the incoming number, which is precisely the
                  // proof a SIM swapper has. It now runs through its own
                  // two-sided flow.
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.phone_iphone_rounded,
                      color: colors.primary,
                    ),
                    title: Text(context.l10n.phone),
                    subtitle: Text(
                      data.user.phone,
                      textDirection: TextDirection.ltr,
                      style: context.dsText.bodyLarge,
                    ),
                    trailing: TextButton(
                      onPressed: () => context.push(RoutePaths.phoneChange),
                      child: Text(context.l10n.changeAccountNumber),
                    ),
                  ),
                  const SizedBox(height: DsSpacing.md),
                  DsInputField(
                    controller: _locationController,
                    label: context.l10n.addresses,
                    prefixIcon: Icon(
                      Icons.location_on_outlined,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: DsSpacing.lg),
                  PrimaryButton(
                    label: context.l10n.saveChanges,
                    icon: Icons.save_outlined,
                    onPressed: _saving ? null : _save,
                    isLoading: _saving,
                  ),
                ]),
              );
            },
          ),
        ),
      ],
    );
  }
}
