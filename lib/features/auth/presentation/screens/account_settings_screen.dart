import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/design_system/components/snackbars/app_snackbar.dart'
    show DsSnackbar, DsSnackbarType;
import 'package:reem/core/result/result.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';

import '../providers/auth_account_provider.dart';
import '../providers/auth_provider.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await ref.read(authRepositoryProvider).updateAccount(
          name: _nameController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          location: _locationController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Success():
        ref.invalidate(authAccountProvider);
        await ref.read(authNotifierProvider.notifier).refreshUser();
        DsSnackbar.show(
          context,
          message: 'Account updated.',
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

  Future<void> _link(SocialAuthProvider provider) async {
    final result = await ref.read(authRepositoryProvider).linkAccount(provider);
    if (!mounted) return;
    _handleAccountResult(result, '${provider.label} linked.');
  }

  Future<void> _unlink(SocialAuthProvider provider) async {
    final result = await ref.read(authRepositoryProvider).unlinkAccount(provider);
    if (!mounted) return;
    _handleAccountResult(result, '${provider.label} unlinked.');
  }

  void _handleAccountResult(Result<AuthAccount> result, String message) {
    switch (result) {
      case Success():
        ref.invalidate(authAccountProvider);
        DsSnackbar.show(
          context,
          message: message,
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
        PremiumAppBar(title: 'Account', showBack: true),
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
                _phoneController.text = data.user.phone;
                _locationController.text = data.user.location ?? '';
                _seeded = true;
              }
              return SliverList(
                delegate: SliverChildListDelegate([
                  Text(
                    'Profile identity',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: DsSpacing.md),
                  DsInputField(
                    controller: _nameController,
                    label: 'Full name',
                    prefixIcon: Icon(Icons.person_outline, color: colors.primary),
                  ),
                  const SizedBox(height: DsSpacing.md),
                  DsInputField(
                    controller: _emailController,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icon(Icons.mail_outline, color: colors.primary),
                  ),
                  const SizedBox(height: DsSpacing.md),
                  DsInputField(
                    controller: _phoneController,
                    label: 'Phone',
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icon(Icons.phone_outlined, color: colors.primary),
                  ),
                  const SizedBox(height: DsSpacing.md),
                  DsInputField(
                    controller: _locationController,
                    label: 'Location',
                    prefixIcon:
                        Icon(Icons.location_on_outlined, color: colors.primary),
                  ),
                  const SizedBox(height: DsSpacing.lg),
                  PrimaryButton(
                    label: 'Save changes',
                    icon: Icons.save_outlined,
                    onPressed: _saving ? null : _save,
                    isLoading: _saving,
                  ),
                  const SizedBox(height: DsSpacing.xl),
                  Text(
                    'Linked accounts',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: DsSpacing.sm),
                  for (final provider in SocialAuthProvider.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: DsSpacing.sm),
                      child: Material(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(DsRadius.md),
                        child: ListTile(
                          leading: Icon(
                            provider == SocialAuthProvider.apple
                                ? Icons.apple
                                : Icons.g_mobiledata_rounded,
                            color: colors.primary,
                          ),
                          title: Text(provider.label),
                          subtitle: Text(
                            data.linkedAccounts
                                    .any((item) => item.provider == provider)
                                ? 'Connected'
                                : 'Not connected',
                          ),
                          trailing: TextButton(
                            onPressed: () => data.linkedAccounts
                                    .any((item) => item.provider == provider)
                                ? _unlink(provider)
                                : _link(provider),
                            child: Text(
                              data.linkedAccounts
                                      .any((item) => item.provider == provider)
                                  ? 'Unlink'
                                  : 'Link',
                            ),
                          ),
                        ),
                      ),
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
