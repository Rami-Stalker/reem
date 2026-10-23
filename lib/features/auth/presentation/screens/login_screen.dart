import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/auth/presentation/utils/auth_form_validators.dart';
import 'package:reem/features/auth/presentation/widgets/auth_motion.dart';

/// The front door.
///
/// It asks for one thing: her number. That is the whole of the primary journey
/// — a code arrives, she types it, and she is either signed in or invited to
/// finish signing up. There is no separate "register" path to choose between,
/// because from her side the two are the same first step, and making her pick
/// correctly before she has typed anything is a question she should not have
/// to answer.
///
/// The password field is gone from this screen. A password on Reem is optional,
/// off by default, and — by design — cannot admit a handset the account has not
/// used before, so putting it first would advertise the weaker credential as
/// the main one. It lives behind [_passwordSheet] for the women who set one and
/// are on their own phone.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.from});

  final String? from;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// Where to land after signing in: back where she was blocked, or home.
  String get _postAuthPath => widget.from == null || widget.from!.isEmpty
      ? RoutePaths.home
      : widget.from!;

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _phoneController.text.trim();

    final challenge = await ref
        .read(authNotifierProvider.notifier)
        .startOtpLogin(phone: phone);

    if (!mounted) return;
    if (challenge == null) {
      _showError();
      return;
    }

    unawaited(context.push(_codePath(phone), extra: challenge));
  }

  /// The code route, carrying where she was headed before she was stopped.
  String _codePath(String phone) => Uri(
    path: RoutePaths.signInCode,
    queryParameters: {
      'phone': phone,
      if (widget.from != null && widget.from!.isNotEmpty) 'from': widget.from!,
    },
  ).toString();

  /// The optional-password path, for a woman who set one on a phone she has
  /// used before.
  ///
  /// If the handset turns out to be new to the account, the server does not
  /// fail — it sends a code, and this carries her straight to the code screen.
  /// A correct password on an unknown device is a request to sign in, not a
  /// sign-in.
  Future<void> _passwordSheet() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _phoneController.text.trim();
    final controller = TextEditingController();

    final password = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _PasswordSheet(
        controller: controller,
        onForgot: () {
          Navigator.pop(sheetContext);
          context.push(RoutePaths.forgotPassword);
        },
      ),
    );
    controller.dispose();
    if (password == null || password.isEmpty || !mounted) return;

    final notifier = ref.read(authNotifierProvider.notifier);
    final ok = await notifier.login(
      phone: phone,
      password: password,
      rememberMe: true,
    );
    if (!mounted) return;

    if (ok) {
      context.go(_postAuthPath);
      return;
    }

    // Not a failure: the password was accepted and a code is already on its
    // way, because this handset is new to the account.
    if (ref.read(authNotifierProvider).passwordNeedsCode) {
      DsSnackbar.show(
        context,
        message: context.l10n.newDeviceCodeSent,
        type: DsSnackbarType.info,
      );
      // No `extra`: the challenge was issued by the server as part of the
      // refusal, and the code screen asks for a fresh one if it arrives cold.
      unawaited(context.push(_codePath(phone)));
      return;
    }

    _showError();
  }

  Future<void> _guest() async {
    final ok = await ref.read(authNotifierProvider.notifier).continueAsGuest();
    if (!mounted) return;
    if (ok) context.go(RoutePaths.home);
  }

  void _showError() {
    final error = ref.read(authNotifierProvider).error;
    if (error != null) {
      DsSnackbar.show(context, message: error, type: DsSnackbarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = ref.watch(authNotifierProvider);
    final colors = context.dsColors;
    final busy = auth.isLoading;

    return AuthStage(
      step: 0,
      children: [
        const Spacer(),
        const AuthEmblem(
              // l10n-ignore: the brand monogram, not copy
              monogram: 'R',
            )
            .animate()
            .fadeIn(duration: 600.ms)
            .scale(
              begin: const Offset(0.8, 0.8),
              duration: 900.ms,
              curve: DsMotion.softSpring,
            ),
        DsGaps.vXs,
        AuthHeading(
          eyebrow: l10n.authEyebrow,
          title: l10n.welcomeToReem,
          subtitle: l10n.signInSubtitle,
        ).authEnter(1),
        DsGaps.vXl,
        AuthPanel(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Identity is the phone number, and only the phone number.
                DsInputField(
                  controller: _phoneController,
                  label: l10n.phone,
                  // l10n-ignore: a dialling mask, not language
                  hint: '09XX XXX XXX',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.go,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  prefixIcon: Icon(
                    Icons.phone_iphone_rounded,
                    color: colors.primary,
                  ),
                  validator: (value) =>
                      AuthFormValidators.requiredPhone(l10n, value),
                  onSubmitted: (_) => busy ? null : _sendCode(),
                ),
                DsGaps.vLg,
                PrimaryButton(
                  label: l10n.signInWithCode,
                  icon: Icons.auto_awesome_rounded,
                  onPressed: busy ? null : _sendCode,
                  isLoading: busy,
                ),
              ],
            ),
          ),
        ).authEnter(2),
        DsGaps.vXl,
        AuthDivider(label: l10n.authOr).authEnter(3),
        DsGaps.vLg,
        AuthOptionTile(
          icon: Icons.lock_outline_rounded,
          label: l10n.usePasswordInstead,
          caption: l10n.authPasswordCaption,
          onTap: busy ? null : _passwordSheet,
        ).authEnter(4),
        DsGaps.vSm,
        AuthOptionTile(
          icon: Icons.local_mall_outlined,
          label: l10n.continueAsGuest,
          caption: l10n.authGuestCaption,
          onTap: busy ? null : _guest,
        ).authEnter(5),
        const Spacer(flex: 2),
        DsGaps.vXl,
        AuthTrustNote(text: l10n.authTrustNote).authEnter(6),
        DsGaps.vLg,
      ],
    );
  }
}

/// The password, asked in a sheet that carries the same marks as the stage:
/// a medallion, a title, and the reminder that a password only works on a
/// phone the account already knows.
class _PasswordSheet extends StatelessWidget {
  const _PasswordSheet({required this.controller, required this.onForgot});

  final TextEditingController controller;
  final VoidCallback onForgot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    return Padding(
      padding: EdgeInsets.only(
        left: DsSpacing.xl,
        right: DsSpacing.xl,
        top: DsSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + DsSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: DsSizes.avatarLg,
              height: DsSizes.avatarLg,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: context.primaryGradient,
                boxShadow: context.primaryGlow,
              ),
              child: Icon(
                Icons.lock_rounded,
                color: colors.onPrimary,
                size: DsSizes.iconMd,
              ),
            ),
          ),
          DsGaps.vMd,
          Text(
            l10n.password,
            textAlign: TextAlign.center,
            style: context.dsText.screenTitle.bold,
          ),
          DsGaps.vXxs,
          Text(
            l10n.passwordOnlyOnKnownDevice,
            textAlign: TextAlign.center,
            style: context.dsText.cardSubtitle,
          ),
          DsGaps.vLg,
          DsInputField(
            controller: controller,
            label: l10n.password,
            obscureText: true,
            autofocus: true,
            autofillHints: const [AutofillHints.password],
            prefixIcon: Icon(Icons.key_rounded, color: colors.primary),
            onSubmitted: (value) => Navigator.pop(context, value.trim()),
          ),
          DsGaps.vLg,
          PrimaryButton(
            label: l10n.signIn,
            onPressed: () => Navigator.pop(context, controller.text.trim()),
          ),
          DsGaps.vXs,
          GhostButton(label: l10n.forgetPassword, onPressed: onForgot),
        ],
      ),
    );
  }
}
