import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';

/// The proof step of the main sign-in journey.
///
/// It is one screen for two outcomes, because from her side it is one moment:
/// she proves she holds the number, and either she is in, or she is asked for
/// her name because the number is new. The app deliberately cannot tell which
/// it will be before the challenge is spent — the server answers a known and an
/// unknown number identically until then, so that this route cannot be used to
/// find out whether a particular woman has an account here.
///
/// There are two ways to prove it, and the server says which one this
/// challenge is. On the reverse rail she sends a message instead of receiving
/// one: nothing is delivered to her, so the delivery failure that dominates
/// this market cannot happen, and a code that travels away from her handset
/// cannot be talked out of her. On the code rail she types the six digits, as
/// before. The screen draws whichever the challenge asks for, so a deployment
/// with no reverse provider — or one whose provider is down, where the server
/// falls back mid-journey — is unaffected.
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
  Timer? _poller;
  int _resendIn = 0;
  bool _settling = false;

  @override
  void initState() {
    super.initState();
    _challenge = widget.challenge;
    if (_challenge == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resend());
    } else {
      _startResendCountdown();
      _startPollingIfReverse();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _poller?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  /// Watches for her message so she does not have to come back and tap.
  ///
  /// She is in another app while this runs, so the poll is quiet by design:
  /// it never shows a spinner, and a failed poll is indistinguishable from
  /// "not yet". The "I have sent it" button stays, because a poll can be
  /// stopped by a backgrounded app and she should never be stuck waiting on
  /// something she cannot retry herself.
  void _startPollingIfReverse() {
    _poller?.cancel();
    if (!(_challenge?.isReverse ?? false)) return;
    _poller = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || _settling) return;
      final status = await ref
          .read(authNotifierProvider.notifier)
          .reverseOtpStatus(phone: widget.phone);
      if (!mounted) return;
      if (status == 'verified') {
        timer.cancel();
        await _submitReverse();
      } else if (status == 'expired') {
        timer.cancel();
      }
    });
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
    // The new challenge may be on the other rail: a reverse provider that has
    // just come back, or one that has just gone down and fallen through to a
    // code. Re-reading it is how the screen follows that without being told.
    _startPollingIfReverse();
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
    _handleResult(result);
  }

  /// Settles the reverse challenge: she says she has sent the message, or the
  /// poll noticed it arriving.
  ///
  /// `_settling` guards the one race this screen has: the poll firing while
  /// her own tap is already in flight, which would spend the challenge twice
  /// and answer the second attempt `INVALID_OTP` on a sign-in that worked.
  Future<void> _submitReverse() async {
    if (_settling) return;
    _settling = true;
    try {
      final result = await ref
          .read(authNotifierProvider.notifier)
          .verifyReverseOtpLogin(phone: widget.phone);
      if (!mounted) return;
      if (result == null) {
        // `OTP_PENDING` is the ordinary answer when she taps before her
        // message has been forwarded, so it is phrased as "not yet" rather
        // than as a failure. The poll keeps running underneath.
        final error = ref.read(authNotifierProvider).error;
        DsSnackbar.show(
          context,
          message: error ?? context.l10n.reverseSmsNotYet,
          type: DsSnackbarType.error,
        );
        return;
      }
      _handleResult(result);
    } finally {
      _settling = false;
    }
  }

  /// Opens her messaging app with the number and body already filled in.
  ///
  /// The two platforms disagree on the separator — Android wants `?body=`,
  /// iOS wants `&body=` — and getting it wrong silently drops the body, which
  /// would leave her composing `VERIFY 763PM5` by hand from a screen she can
  /// no longer see. If the launch fails she is told to send it manually; the
  /// message and the number stay on screen for exactly that reason.
  Future<void> _openMessages() async {
    final challenge = _challenge;
    if (challenge == null || !challenge.isReverse) return;
    final separator = defaultTargetPlatform == TargetPlatform.iOS ? '&' : '?';
    final uri = Uri.parse(
      'sms:${challenge.sendTo}'
      '${separator}body=${Uri.encodeComponent(challenge.smsBody!)}',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication)
        .catchError((_) => false);
    if (!mounted || opened) return;
    DsSnackbar.show(
      context,
      message: context.l10n.reverseSmsCouldNotOpen,
      type: DsSnackbarType.error,
    );
  }

  void _handleResult(OtpLoginResult? result) {
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

  /// The reverse rail: what to send, where, and a way to say she has.
  ///
  /// Everything she needs stays on screen while she is in her messaging app,
  /// because she will come back to this screen and may need to read the body
  /// again — and because if the composer failed to open, this is the only
  /// place the message exists.
  List<Widget> _reverseBody(OtpChallenge challenge) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final auth = ref.watch(authNotifierProvider);

    return [
      const SizedBox(height: DsSpacing.sm),
      Text(
        l10n.reverseSmsExplainer,
        textAlign: TextAlign.center,
        style: context.dsText.cardSubtitle.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: DsSpacing.lg),
      _SmsInstructionCard(
        sendTo: challenge.sendTo!,
        body: challenge.smsBody!,
      ),
      const SizedBox(height: DsSpacing.lg),
      PrimaryButton(
        label: l10n.reverseSmsOpenMessages,
        onPressed: auth.isLoading ? null : _openMessages,
      ),
      const SizedBox(height: DsSpacing.sm),
      SecondaryButton(
        label: l10n.reverseSmsIveSent,
        onPressed: auth.isLoading ? null : _submitReverse,
        isLoading: auth.isLoading,
      ),
      const SizedBox(height: DsSpacing.sm),
      Text(
        l10n.reverseSmsWaiting,
        textAlign: TextAlign.center,
        style: context.dsText.label.copyWith(color: colors.onSurfaceVariant),
      ),
      const SizedBox(height: DsSpacing.xs),
      Text(
        l10n.reverseSmsCost,
        textAlign: TextAlign.center,
        style: context.dsText.label.copyWith(color: colors.onSurfaceVariant),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = ref.watch(authNotifierProvider);
    final colors = context.dsColors;
    final destination = _challenge?.maskedDestination ?? widget.phone;
    final challenge = _challenge;
    final reverse = challenge?.isReverse ?? false;

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
                  reverse ? Icons.outgoing_mail : Icons.sms_outlined,
                  size: 48,
                  color: colors.primary,
                ),
                const SizedBox(height: DsSpacing.lg),
                Text(
                  reverse ? l10n.reverseSmsTitle : l10n.codeSentToMasked(destination),
                  textAlign: TextAlign.center,
                  style: context.dsText.cardTitle,
                ),
                if (reverse)
                  ..._reverseBody(challenge!)
                else ...[
                  if (challenge?.matchCode != null) ...[
                    const SizedBox(height: DsSpacing.lg),
                    _MatchCodeCard(code: challenge!.matchCode!),
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
                ],
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

/// The message, the address, and a way to copy either.
///
/// Matching is whitespace-trimmed and case-insensitive on the provider's side,
/// but she should not have to rely on that: the body is shown exactly as it
/// must be sent, in a monospaced-feeling block, with copy buttons so she never
/// has to retype it.
class _SmsInstructionCard extends StatelessWidget {
  const _SmsInstructionCard({required this.sendTo, required this.body});

  final String sendTo;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(DsRadius.md),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.reverseSmsSendTo(sendTo),
            textAlign: TextAlign.center,
            style: context.dsText.cardTitle,
            // The number is data, not prose: in an RTL layout a bare `+963…`
            // would otherwise be reordered on screen and read back wrong.
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: DsSpacing.md),
          Text(
            l10n.reverseSmsBodyLabel,
            style: context.dsText.label.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: DsSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  body,
                  style: context.dsText.cardTitle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                    letterSpacing: 2,
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_outlined),
                tooltip: l10n.copy,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: body));
                  if (!context.mounted) return;
                  DsSnackbar.show(context, message: l10n.copy);
                },
              ),
            ],
          ),
        ],
      ),
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
