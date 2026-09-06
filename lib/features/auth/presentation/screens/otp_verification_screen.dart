import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/auth/presentation/utils/auth_form_validators.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.phone,
    required this.purpose,
    this.from,
  });

  final String phone;
  final OtpPurpose purpose;
  final String? from;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
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
    final challenge = await ref
        .read(authNotifierProvider.notifier)
        .requestOtp(phone: widget.phone, purpose: widget.purpose);
    if (!mounted) return;
    setState(() {
      _requested = challenge != null;
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
        message: context.l10n.enterVerificationCode,
        type: DsSnackbarType.error,
      );
      return;
    }
    if (_isPasswordReset) {
      final passwordError = AuthFormValidators.strongPassword(context.l10n, 
        _passwordController.text,
      );
      if (passwordError != null) {
        DsSnackbar.show(
          context,
          message: passwordError,
          type: DsSnackbarType.error,
        );
        return;
      }
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
            ? context.l10n.passwordChanged
            : context.l10n.phoneVerified,
        type: DsSnackbarType.success,
      );
      context.go(_postVerificationPath);
    } else {
      final error = ref.read(authNotifierProvider).error;
      if (error != null) {
        DsSnackbar.show(context, message: error, type: DsSnackbarType.error);
      }
    }
  }

  String get _postVerificationPath {
    if (_isPasswordReset) return RoutePaths.login;
    final target = widget.from;
    if (target == null ||
        target.isEmpty ||
        target == RoutePaths.login ||
        target == RoutePaths.register ||
        target == RoutePaths.authRequired) {
      return RoutePaths.home;
    }
    return target;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final colors = context.dsColors;

    return ReemScrollPage(
      slivers: [
        PremiumAppBar(title: context.l10n.verifyCode, showBack: true),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: DsSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Icon(
                  Icons.verified_user_outlined,
                  size: 48,
                  color: colors.primary,
                ),
                const SizedBox(height: DsSpacing.lg),
                Text(
                  _isPasswordReset
                      ? context.l10n.resetYourPassword
                      : context.l10n.verifyYourPhone,
                  textAlign: TextAlign.center,
                  style: context.dsText.screenTitle.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: DsSpacing.sm),
                Text(
                  _requested
                      ? context.l10n.codeSentTo(widget.phone)
                      : context.l10n.requestingCode,
                  textAlign: TextAlign.center,
                  style: context.dsText.body.tint(colors.onSurfaceVariant),
                ),
                const SizedBox(height: DsSpacing.xl),
                DsInputField(
                  controller: _codeController,
                  label: context.l10n.verificationCode,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icon(
                    Icons.password_outlined,
                    color: colors.primary,
                  ),
                ),
                if (_isPasswordReset) ...[
                  const SizedBox(height: DsSpacing.md),
                  DsInputField(
                    controller: _passwordController,
                    label: context.l10n.newPassword,
                    obscureText: true,
                    prefixIcon: Icon(Icons.lock_outline, color: colors.primary),
                  ),
                ],
                const SizedBox(height: DsSpacing.lg),
                PrimaryButton(
                  label: _isPasswordReset ? context.l10n.resetPassword : context.l10n.verify,
                  onPressed: auth.isLoading ? null : _submit,
                  isLoading: auth.isLoading,
                ),
                const SizedBox(height: DsSpacing.sm),
                SecondaryButton(
                  label: context.l10n.resendCode,
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
