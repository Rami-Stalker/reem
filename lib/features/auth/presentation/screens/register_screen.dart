import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/components/snackbars/app_snackbar.dart' show DsSnackbar, DsSnackbarType;
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/shared/entities/user.dart';
import '../../domain/entities/auth_account.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  UserRole _role = UserRole.customer;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref.read(authNotifierProvider.notifier).register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
          role: _role,
        );

    if (!mounted) return;
    if (ok) {
      final phone = Uri.encodeComponent(_phoneController.text.trim());
      context.go(
        '${RoutePaths.otpVerification}?phone=$phone&purpose=${OtpPurpose.phoneVerification.wire}',
      );
    } else {
      final error = ref.read(authNotifierProvider).error;
      if (error != null) {
        DsSnackbar.show(context, message: error, type: DsSnackbarType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = ref.watch(authNotifierProvider);
    final colors = context.dsColors;

    return ReemScrollPage(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: DsSpacing.screenPadding,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Icon(Icons.spa_rounded, size: 48, color: colors.primary)
                      .animate()
                      .scale(duration: 600.ms),
                  const SizedBox(height: DsSpacing.xl),
                  DsGradientText(
                    l10n.signup,
                    style: TextStyle(
                      fontFamily: DsTypography.fontFamily,
                      fontSize: 32,
                      fontWeight: DsTypography.bold,
                    ),
                  ),
                  const SizedBox(height: DsSpacing.sm),
                  Text(
                    l10n.loginSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: DsSpacing.xxxl),
                  DsInputField(
                    controller: _nameController,
                    label: l10n.fullName,
                    hint: 'Reem Al-Mansouri',
                    prefixIcon: Icon(Icons.person_outline, color: colors.primary),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? l10n.emailRequired : null,
                  ),
                  const SizedBox(height: DsSpacing.md),
                  DsInputField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'reem@example.com',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icon(Icons.mail_outline, color: colors.primary),
                  ),
                  const SizedBox(height: DsSpacing.md),
                  DsInputField(
                    controller: _phoneController,
                    label: 'Phone number',
                    hint: '+9665XXXXXXXX',
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icon(Icons.phone_outlined, color: colors.primary),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Phone number is required';
                      if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(value)) {
                        return 'Enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: DsSpacing.md),
                  _RoleSelector(
                    value: _role,
                    onChanged: (r) => setState(() => _role = r),
                  ),
                  const SizedBox(height: DsSpacing.md),
                  DsInputField(
                    controller: _passwordController,
                    label: l10n.password,
                    obscureText: true,
                    prefixIcon: Icon(Icons.lock_outline, color: colors.primary),
                    validator: (v) {
                      if (v == null || v.length < 6) return l10n.passwordMinLength;
                      return null;
                    },
                  ),
                  const SizedBox(height: DsSpacing.md),
                  DsInputField(
                    controller: _confirmPasswordController,
                    label: l10n.confirmPassword,
                    obscureText: true,
                    prefixIcon: Icon(Icons.lock_outline, color: colors.primary),
                    validator: (v) {
                      if (v != _passwordController.text) {
                        return l10n.confirmPasswordMismatch;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: DsSpacing.lg),
                  PrimaryButton(
                    label: l10n.signup,
                    onPressed: auth.isLoading ? null : _submit,
                    isLoading: auth.isLoading,
                  ),
                  const SizedBox(height: DsSpacing.md),
                  SecondaryButton(
                    label: l10n.signIn,
                    onPressed: () => context.go(RoutePaths.login),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Lets a new user choose how they want to join: shop as a Customer or sell on
/// Reem as a Seller. Admins are provisioned separately (never self-registered).
class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.value, required this.onChanged});

  final UserRole value;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoleChip(
            label: 'Shop as Customer',
            icon: Icons.shopping_bag_outlined,
            selected: value == UserRole.customer,
            onTap: () => onChanged(UserRole.customer),
          ),
        ),
        const SizedBox(width: DsSpacing.sm),
        Expanded(
          child: _RoleChip(
            label: 'Sell on Reem',
            icon: Icons.storefront_outlined,
            selected: value == UserRole.seller,
            onTap: () => onChanged(UserRole.seller),
          ),
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return InkWell(
      borderRadius: BorderRadius.circular(DsRadius.lg),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          vertical: DsSpacing.md,
          horizontal: DsSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.12)
              : colors.surfaceVariant,
          borderRadius: BorderRadius.circular(DsRadius.lg),
          border: Border.all(
            color: selected ? colors.primary : colors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(height: DsSpacing.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                    fontWeight:
                        selected ? DsTypography.bold : DsTypography.regular,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
