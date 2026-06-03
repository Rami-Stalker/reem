import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/components/snackbars/app_snackbar.dart' show DsSnackbar, DsSnackbarType;
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/router/route_paths.dart';
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
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref.read(authNotifierProvider.notifier).register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;
    if (ok) {
      context.go(RoutePaths.home);
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
                    label: l10n.email,
                    hint: 'you@example.com',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icon(Icons.email_outlined, color: colors.primary),
                    validator: (v) {
                      if (v == null || v.isEmpty) return l10n.emailRequired;
                      if (!v.contains('@')) return l10n.validEmailRequired;
                      return null;
                    },
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
