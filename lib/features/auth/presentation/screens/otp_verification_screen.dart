import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/design_system/components/snackbars/app_snackbar.dart'
    show DsSnackbar, DsSnackbarType;
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';

import '../providers/auth_provider.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.phone,
    required this.purpose,
  });

  final String phone;
  final OtpPurpose purpose;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _debugCode;
  bool _requested = false;

  bool get _isPasswordReset => widget.purpose == OtpPurpose.passwordReset;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestCode());
  }

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final challenge = await ref.read(authNotifierProvider.notifier).requestOtp(
          phone: widget.phone,
          purpose: widget.purpose,
        );
    if (!mounted) return;
    setState(() {
      _requested = challenge != null;
      _debugCode = challenge?.debugCode;
    });
    if (challenge == null) {
      final error = ref.read(authNotifierProvider).error;
      if (error != null) {
        DsSnackbar.show(context, message: error, type: DsSnackbarType.error);
      }
    }
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.length < 4) {
      DsSnackbar.show(
        context,
        message: 'Enter the verification code.',
        type: DsSnackbarType.error,
      );
      return;
    }

    final notifier = ref.read(authNotifierProvider.notifier);
    final ok = _isPasswordReset
        ? await notifier.resetPassword(
            phone: widget.phone,
            code: code,
            newPassword: _passwordController.text,
          )
        : await notifier.verifyOtp(
            phone: widget.phone,
            purpose: widget.purpose,
            code: code,
          );

    if (!mounted) return;
    if (ok) {
      DsSnackbar.show(
        context,
        message: _isPasswordReset
            ? 'Password updated.'
            : 'Phone number verified.',
        type: DsSnackbarType.success,
      );
      context.go(_isPasswordReset ? RoutePaths.login : RoutePaths.home);
    } else {
      final error = ref.read(authNotifierProvider).error;
      if (error != null) {
        DsSnackbar.show(context, message: error, type: DsSnackbarType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final colors = context.dsColors;

    return ReemScrollPage(
      slivers: [
        PremiumAppBar(title: 'Verify code', showBack: true),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: DsSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Icon(Icons.verified_user_outlined, size: 48, color: colors.primary),
                const SizedBox(height: DsSpacing.lg),
                Text(
                  _isPasswordReset ? 'Reset your password' : 'Verify your phone',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: DsSpacing.sm),
                Text(
                  _requested
                      ? 'We sent a one-time code to ${widget.phone}.'
                      : 'Requesting a one-time code...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                if (_debugCode != null) ...[
                  const SizedBox(height: DsSpacing.sm),
                  Text(
                    'Development code: $_debugCode',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: DsSpacing.xl),
                DsInputField(
                  controller: _codeController,
                  label: 'Verification code',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icon(Icons.password_outlined, color: colors.primary),
                ),
                if (_isPasswordReset) ...[
                  const SizedBox(height: DsSpacing.md),
                  DsInputField(
                    controller: _passwordController,
                    label: 'New password',
                    obscureText: true,
                    prefixIcon: Icon(Icons.lock_outline, color: colors.primary),
                  ),
                ],
                const SizedBox(height: DsSpacing.lg),
                PrimaryButton(
                  label: _isPasswordReset ? 'Reset password' : 'Verify',
                  onPressed: auth.isLoading ? null : _submit,
                  isLoading: auth.isLoading,
                ),
                const SizedBox(height: DsSpacing.sm),
                SecondaryButton(
                  label: 'Resend code',
                  onPressed: auth.isLoading ? null : _requestCode,
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
