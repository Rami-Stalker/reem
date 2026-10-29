import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/errors/failure_exception.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/auth/presentation/providers/auth_account_provider.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';

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
    final palette = context.boutique;
    final gutter = vanityGutter(context);
    const fields = EdgeInsets.fromLTRB(
      DsSpacing.md,
      DsSpacing.lg,
      DsSpacing.md,
      DsSpacing.xs,
    );

    return OharaScrollPage(
      slivers: [
        VanityAppBar(
          title: context.l10n.account,
          subtitle: context.l10n.profileIdentity,
          icon: Icons.person_outline_rounded,
          showBack: true,
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter, DsSpacing.xl, gutter, 120),
          sliver: account.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: DsLoadingIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              child: DsErrorState(message: messageOf(error)),
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
                  VanityTray(
                    padding: fields,
                    children: [
                      DsInputField(
                        controller: _nameController,
                        label: context.l10n.fullName,
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: palette.primary,
                        ),
                      ),
                      DsInputField(
                        controller: _emailController,
                        label: context.l10n.email,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icon(
                          Icons.mail_outline,
                          color: palette.primary,
                        ),
                      ),
                      DsInputField(
                        controller: _locationController,
                        label: context.l10n.addresses,
                        prefixIcon: Icon(
                          Icons.location_on_outlined,
                          color: palette.primary,
                        ),
                      ),
                    ],
                  ),
                  DsGaps.vXl,
                  // Read-only, and it leads somewhere else.
                  //
                  // The number IS the account: it is the login, the recovery
                  // channel and the second factor at once. Editing it beside a
                  // name and a city framed a transfer of the account as a
                  // profile tweak — and it used to behave like one, taking a
                  // single code on the incoming number, which is precisely the
                  // proof a SIM swapper has. It now runs through its own
                  // two-sided flow.
                  VanityTray(
                    children: [
                      VanityRow(
                        icon: Icons.phone_iphone_rounded,
                        title: context.l10n.phone,
                        subtitle: '\u2066${data.user.phone}\u2069',
                        trailing: TextButton(
                          onPressed: () => context.push(RoutePaths.phoneChange),
                          child: Text(context.l10n.changeAccountNumber),
                        ),
                      ),
                    ],
                  ),
                  DsGaps.vXxl,
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
