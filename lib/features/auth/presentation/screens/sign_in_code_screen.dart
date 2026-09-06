import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';

/// The code step of the main sign-in journey.
///
/// It is one screen for two outcomes, because from her side it is one moment:
/// she types the six digits she was sent, and either she is in, or she is asked
/// for her name because the number is new. The app deliberately cannot tell
/// which it will be before the code is spent — the server answers a known and
/// an unknown number identically until then, so that this route cannot be used
/// to find out whether a particular woman has an account here.
class SignInCodeScreen extends ConsumerStatefulWidget {
  const SignInCodeScreen({
    super.key,
    required this.phone,
    this.challenge,
    this.from,
  });

  final String phone;

  /// The challenge already issued by the phone step. Null when the screen is
  /// entered cold — e.g. after a password fell through on a new device — in
  /// which case it asks for one itself.
  final OtpChallenge? challenge;
  final String? from;

  @override
  ConsumerState<SignInCodeScreen> createState() => _SignInCodeScreenState();
}

class _SignInCodeScreenState extends ConsumerState<SignInCodeScreen> {
  final _codeController = TextEditingController();
  OtpChallenge? _challenge;
  Timer? _ticker;
  int _resendIn = 0;

  @override
  void initState() {
    super.initState();
    _challenge = widget.challenge;
    if (_challenge == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resend());
    } else {
      _startResendCountdown();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    final until = _challenge?.resendAfter;
    if (until == null) return;
    _ticker?.cancel();
    void tick() {
      final left = until.difference(DateTime.now()).inSeconds;
      if (!mounted) return;
      setState(() => _resendIn = left > 0 ? left : 0);
      if (left <= 0) _ticker?.cancel();
    }

    tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<void> _resend() async {
    final challenge = await ref
        .read(authNotifierProvider.notifier)
        .startOtpLogin(phone: widget.phone);
    if (!mounted) return;
    if (challenge == null) {
      _showError();
      return;
    }
    setState(() => _challenge = challenge);
    _startResendCountdown();
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

    final result = await ref
        .read(authNotifierProvider.notifier)
        .verifyOtpLogin(phone: widget.phone, code: code);
    if (!mounted) return;

    switch (result) {
      case OtpLoginAuthenticated():
        context.go(_postAuthPath);
      case OtpLoginRegistrationRequired(
        :final phone,
        :final registrationTicket,
      ):
        // The number is free. Carry the proof forward — the signup form cannot
        // create an account without it.
        context.pushReplacement(
          Uri(
            path: RoutePaths.register,
            queryParameters: {
              'phone': phone,
              'ticket': registrationTicket,
              if (widget.from != null && widget.from!.isNotEmpty)
                'from': widget.from!,
            },
          ).toString(),
        );
      case null:
        _showError();
    }
  }

  void _showError() {
    final error = ref.read(authNotifierProvider).error;
    if (error != null) {
      DsSnackbar.show(context, message: error, type: DsSnackbarType.error);
    }
  }

  String get _postAuthPath {
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
    final l10n = context.l10n;
    final auth = ref.watch(authNotifierProvider);
    final colors = context.dsColors;
    final destination = _challenge?.maskedDestination ?? widget.phone;

    return ReemScrollPage(
      slivers: [
        PremiumAppBar(title: l10n.verifyCode, showBack: true),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: DsSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Icon(
                  Icons.sms_outlined,
                  size: 48,
                  color: colors.primary,
                ),
                const SizedBox(height: DsSpacing.lg),
                Text(
                  l10n.codeSentToMasked(destination),
                  textAlign: TextAlign.center,
                  style: context.dsText.cardTitle,
                ),
                if (_challenge?.matchCode != null) ...[
                  const SizedBox(height: DsSpacing.lg),
                  _MatchCodeCard(code: _challenge!.matchCode!),
                ],
                const SizedBox(height: DsSpacing.xl),
                DsInputField(
                  controller: _codeController,
                  label: l10n.verificationCode,
                  keyboardType: TextInputType.number,
                  // `oneTimeCode` is what lets iOS and Android offer the code
                  // straight from the notification, which matters more here
                  // than anywhere else: this is now the primary credential.
                  autofillHints: const [AutofillHints.oneTimeCode],
                  prefixIcon: Icon(
                    Icons.password_outlined,
                    color: colors.primary,
                  ),
                  onSubmitted: (_) => auth.isLoading ? null : _submit(),
                ),
                const SizedBox(height: DsSpacing.lg),
                PrimaryButton(
                  label: l10n.continueLabel,
                  onPressed: auth.isLoading ? null : _submit,
                  isLoading: auth.isLoading,
                ),
                const SizedBox(height: DsSpacing.sm),
                GhostButton(
                  label: _resendIn > 0
                      ? l10n.resendInSeconds(_resendIn)
                      : l10n.resendCode,
                  onPressed: auth.isLoading || _resendIn > 0 ? null : _resend,
                ),
                const SizedBox(height: DsSpacing.md),
                GhostButton(
                  label: l10n.lostYourSim,
                  onPressed: () => context.push(RoutePaths.accountRecovery),
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

/// The two digits, given the weight they deserve.
///
/// This is not decoration. Every OTP market where codes arrive over WhatsApp
/// has the same dominant attack — somebody calls claiming to be support and
/// asks her to read out the code they just triggered — and a match code is the
/// only defence that works on the victim's side, because the code the caller
/// triggered carries different digits from the ones on her screen. It only
/// works if she actually sees it, so it gets a card rather than a caption.
class _MatchCodeCard extends StatelessWidget {
  const _MatchCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Semantics(
      label: '${context.l10n.matchCodeLabel} $code',
      child: Container(
        padding: const EdgeInsets.all(DsSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(DsRadius.md),
          border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              context.l10n.matchCodeLabel,
              style: context.dsText.label.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: DsSpacing.xs),
            Text(
              code,
              style: context.dsText.hero.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.primary,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: DsSpacing.sm),
            Text(
              context.l10n.matchCodeHint,
              textAlign: TextAlign.center,
              style: context.dsText.cardSubtitle.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
