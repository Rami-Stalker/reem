import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/components/snackbars/app_snackbar.dart' show DsSnackbar, DsSnackbarType;
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/router/route_paths.dart';
import '../../domain/entities/auth_account.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref.read(authNotifierProvider.notifier).login(
          phone: _phoneController.text.trim(),
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

  Future<void> _social(SocialAuthProvider provider) async {
    final ok = await ref.read(authNotifierProvider.notifier).socialSignIn(provider);
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

  Future<void> _guest() async {
    final ok = await ref.read(authNotifierProvider.notifier).continueAsGuest();
    if (!mounted) return;
    if (ok) context.go(RoutePaths.home);
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
                  Icon(Icons.favorite_rounded, size: 48, color: colors.primary)
                      .animate()
                      .scale(duration: 600.ms),
                  const SizedBox(height: DsSpacing.xl),
                  DsGradientText(
                    l10n.welcomeToReem,
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
                  DsInputField(
                    controller: _passwordController,
                    label: l10n.password,
                    obscureText: true,
                    prefixIcon: Icon(Icons.lock_outline, color: colors.primary),
                    validator: (v) {
                      if (v == null || v.length < 6) {
                        return l10n.passwordMinLength;
                      }
                      return null;
                    },
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: GhostButton(
                      label: l10n.forgetPassword,
                      onPressed: () => context.push(RoutePaths.forgotPassword),
                    ),
                  ),
                  const SizedBox(height: DsSpacing.lg),
                  PrimaryButton(
                    label: l10n.signIn,
                    onPressed: auth.isLoading ? null : _submit,
                    isLoading: auth.isLoading,
                  ),
                  const SizedBox(height: DsSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'Google',
                          icon: Icons.g_mobiledata_rounded,
                          onPressed: auth.isLoading
                              ? null
                              : () => _social(SocialAuthProvider.google),
                        ),
                      ),
                      const SizedBox(width: DsSpacing.sm),
                      Expanded(
                        child: SecondaryButton(
                          label: 'Apple',
                          icon: Icons.apple,
                          onPressed: auth.isLoading
                              ? null
                              : () => _social(SocialAuthProvider.apple),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DsSpacing.md),
                  SecondaryButton(
                    label: l10n.createAccount,
                    onPressed: () => context.push(RoutePaths.register),
                  ),
                  const SizedBox(height: DsSpacing.sm),
                  GhostButton(
                    label: 'Continue as guest',
                    onPressed: auth.isLoading ? null : _guest,
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
