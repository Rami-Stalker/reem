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
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: DsSpacing.lg,
          right: DsSpacing.lg,
          top: DsSpacing.lg,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + DsSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              sheetContext.l10n.password,
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: DsSpacing.xs),
            Text(
              sheetContext.l10n.passwordOnlyOnKnownDevice,
              style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                color: sheetContext.dsColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: DsSpacing.lg),
            DsInputField(
              controller: controller,
              label: sheetContext.l10n.password,
              obscureText: true,
              autofocus: true,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (value) => Navigator.pop(sheetContext, value.trim()),
            ),
            const SizedBox(height: DsSpacing.lg),
            PrimaryButton(
              label: sheetContext.l10n.signIn,
              onPressed: () =>
                  Navigator.pop(sheetContext, controller.text.trim()),
            ),
            GhostButton(
              label: sheetContext.l10n.forgetPassword,
              onPressed: () {
                Navigator.pop(sheetContext);
                context.push(RoutePaths.forgotPassword);
              },
            ),
            const SizedBox(height: DsSpacing.sm),
          ],
        ),
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
                  Icon(
                    Icons.favorite_rounded,
                    size: 48,
                    color: colors.primary,
                  ).animate().scale(duration: 600.ms),
                  const SizedBox(height: DsSpacing.xl),
                  DsGradientText(
                    l10n.welcomeToReem,
                    style: context.dsText.pageTitle.bold,
                  ),
                  const SizedBox(height: DsSpacing.sm),
                  Text(
                    l10n.signInSubtitle,
                    textAlign: TextAlign.center,
                    style: context.dsText.body.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: DsSpacing.xxxl),
                  // Identity is the phone number, and only the phone number.
                  DsInputField(
                    controller: _phoneController,
                    label: l10n.phone,
                    // l10n-ignore: a dialling mask, not language
                    hint: '09XX XXX XXX',
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    prefixIcon: Icon(
                      Icons.phone_iphone_rounded,
                      color: colors.primary,
                    ),
                    validator: (value) =>
                        AuthFormValidators.requiredPhone(l10n, value),
                    onSubmitted: (_) => auth.isLoading ? null : _sendCode(),
                  ),
                  const SizedBox(height: DsSpacing.lg),
                  PrimaryButton(
                    label: l10n.signInWithCode,
                    onPressed: auth.isLoading ? null : _sendCode,
                    isLoading: auth.isLoading,
                  ),
                  const SizedBox(height: DsSpacing.sm),
                  GhostButton(
                    label: l10n.usePasswordInstead,
                    onPressed: auth.isLoading ? null : _passwordSheet,
                  ),
                  const SizedBox(height: DsSpacing.sm),
                  GhostButton(
                    label: l10n.continueAsGuest,
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
