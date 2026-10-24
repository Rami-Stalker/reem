import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/auth/domain/entities/auth_account.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/auth/presentation/utils/auth_form_validators.dart';
import 'package:ohara/features/auth/presentation/widgets/auth_motion.dart';

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
      final passwordError = AuthFormValidators.strongPassword(
        context.l10n,
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
    final l10n = context.l10n;

    return AuthStage(
      showBack: true,
      children: [
        const Spacer(),
        AuthEmblem(
              icon: _isPasswordReset
                  ? Icons.lock_reset_rounded
                  : Icons.verified_user_rounded,
              size: 92,
            )
            .animate()
            .fadeIn(duration: 500.ms)
            .scale(
              begin: const Offset(0.85, 0.85),
              duration: 800.ms,
              curve: DsMotion.softSpring,
            ),
        AuthHeading(
          title: _isPasswordReset
              ? l10n.resetYourPassword
              : l10n.verifyYourPhone,
          subtitle: _requested
              ? l10n.codeSentTo(widget.phone)
              : l10n.requestingCode,
        ).authEnter(1),
        DsGaps.vXl,
        AuthPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.authCodeHint,
                textAlign: TextAlign.center,
                style: context.dsText.label,
              ),
              DsGaps.vMd,
              AuthCodeField(
                controller: _codeController,
                enabled: !auth.isLoading,
                semanticsLabel: l10n.verificationCode,
                // A reset still needs the new password, so only a plain
                // verification can go as soon as the last digit lands.
                onCompleted: _isPasswordReset || auth.isLoading
                    ? null
                    : (_) => _submit(),
              ),
              if (_isPasswordReset) ...[
                DsGaps.vLg,
                DsInputField(
                  controller: _passwordController,
                  label: l10n.newPassword,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  prefixIcon: Icon(
                    Icons.lock_outline_rounded,
                    color: colors.primary,
                  ),
                ),
              ],
              DsGaps.vLg,
              PrimaryButton(
                label: _isPasswordReset ? l10n.resetPassword : l10n.verify,
                onPressed: auth.isLoading ? null : _submit,
                isLoading: auth.isLoading,
              ),
            ],
          ),
        ).authEnter(2),
        DsGaps.vMd,
        Center(
          child: GhostButton(
            label: l10n.resendCode,
            icon: Icons.refresh_rounded,
            onPressed: auth.isLoading ? null : _requestCode,
          ),
        ).authEnter(3),
        const Spacer(flex: 2),
        DsGaps.vLg,
      ],
    );
  }
}
