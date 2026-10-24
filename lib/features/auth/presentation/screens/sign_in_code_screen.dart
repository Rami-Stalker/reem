import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/auth/domain/entities/auth_account.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/auth/presentation/widgets/auth_motion.dart';
import 'package:url_launcher/url_launcher.dart';

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

  /// Bumped on every refused code: replays the shake and tints the cells.
  int _rejections = 0;

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
    if (result == null) {
      // Clear the cells so the next attempt starts from the first one.
      setState(() => _rejections++);
      _codeController.clear();
    }
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
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
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
    final auth = ref.watch(authNotifierProvider);

    return [
      _SmsInstructionCard(
        sendTo: challenge.sendTo!,
        body: challenge.smsBody!,
      ).authEnter(2),
      DsGaps.vLg,
      PrimaryButton(
        label: l10n.reverseSmsOpenMessages,
        icon: Icons.send_rounded,
        onPressed: auth.isLoading ? null : _openMessages,
      ).authEnter(3),
      DsGaps.vSm,
      SecondaryButton(
        label: l10n.reverseSmsIveSent,
        onPressed: auth.isLoading ? null : _submitReverse,
        isLoading: auth.isLoading,
      ).authEnter(3),
      DsGaps.vMd,
      const _WaitingPulse().authEnter(4),
      DsGaps.vXs,
      Text(
        l10n.reverseSmsCost,
        textAlign: TextAlign.center,
        style: context.dsText.caption,
      ).authEnter(4),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = ref.watch(authNotifierProvider);
    final destination = _challenge?.maskedDestination ?? widget.phone;
    final challenge = _challenge;
    final reverse = challenge?.isReverse ?? false;

    return AuthStage(
      showBack: true,
      step: 1,
      children: [
        const Spacer(),
        AuthEmblem(
              icon: reverse
                  ? Icons.outgoing_mail
                  : Icons.mark_chat_unread_rounded,
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
          title: reverse ? l10n.reverseSmsTitle : l10n.verifyCode,
          subtitle: reverse
              ? l10n.reverseSmsExplainer
              : l10n.codeSentToMasked(destination),
        ).authEnter(1),
        DsGaps.vXl,
        if (reverse)
          ..._reverseBody(challenge!)
        else ...[
          if (challenge?.matchCode != null) ...[
            _MatchCodeCard(code: challenge!.matchCode!).authEnter(2),
            DsGaps.vLg,
          ],
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
                      hasError: _rejections > 0 && _codeController.text.isEmpty,
                      semanticsLabel: l10n.verificationCode,
                      onCompleted: (_) => auth.isLoading ? null : _submit(),
                    )
                    .animate(
                      key: ValueKey(_rejections),
                      autoPlay: _rejections > 0,
                    )
                    .shake(hz: 6, offset: const Offset(8, 0)),
                DsGaps.vLg,
                PrimaryButton(
                  label: l10n.continueLabel,
                  onPressed: auth.isLoading ? null : _submit,
                  isLoading: auth.isLoading,
                ),
              ],
            ),
          ).authEnter(3),
        ],
        DsGaps.vMd,
        Center(
          child: GhostButton(
            label: _resendIn > 0
                ? l10n.resendInSeconds(_resendIn)
                : l10n.resendCode,
            icon: _resendIn > 0
                ? Icons.schedule_rounded
                : Icons.refresh_rounded,
            onPressed: auth.isLoading || _resendIn > 0 ? null : _resend,
          ),
        ).authEnter(5),
        DsGaps.vSm,
        AuthOptionTile(
          icon: Icons.sim_card_alert_outlined,
          label: l10n.lostYourSim,
          caption: l10n.authLostSimCaption,
          onTap: () => context.push(RoutePaths.accountRecovery),
        ).authEnter(6),
        const Spacer(flex: 2),
        DsGaps.vLg,
      ],
    );
  }
}

/// The message to send, drawn as the message itself: an outgoing chat bubble
/// addressed to the platform's number, with a way to copy either.
///
/// Matching is whitespace-trimmed and case-insensitive on the provider's side,
/// but she should not have to rely on that: the body is shown exactly as it
/// must be sent, with copy buttons so she never has to retype it.
class _SmsInstructionCard extends StatelessWidget {
  const _SmsInstructionCard({required this.sendTo, required this.body});

  final String sendTo;
  final String body;

  Future<void> _copy(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    DsSnackbar.show(context, message: context.l10n.copy);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;
    return AuthPanel(
      padding: const EdgeInsets.all(DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The "to" line of a message composer.
          Row(
            children: [
              Container(
                width: DsSizes.avatarSm,
                height: DsSizes.avatarSm,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primaryContainer,
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  size: DsSizes.iconXs,
                  color: colors.primary,
                ),
              ),
              DsGaps.hSm,
              Expanded(
                child: Text(
                  l10n.reverseSmsSendTo(sendTo),
                  style: context.dsText.bodyStrong,
                  // The number is data, not prose: in an RTL layout a bare
                  // `+963…` would otherwise be reordered on screen and read
                  // back wrong.
                  textDirection: TextDirection.ltr,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: DsSizes.iconXs),
                color: colors.onSurfaceVariant,
                tooltip: l10n.copy,
                onPressed: () => _copy(context, sendTo),
              ),
            ],
          ),
          Divider(color: colors.divider, height: DsSpacing.lg),
          Text(l10n.reverseSmsBodyLabel, style: context.dsText.caption),
          DsGaps.vXs,
          // The outgoing bubble, its tail on the sending side.
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(
                DsSpacing.lg,
                DsSpacing.xs,
                DsSpacing.xxs,
                DsSpacing.xs,
              ),
              decoration: BoxDecoration(
                gradient: context.primaryGradient,
                borderRadius: const BorderRadiusDirectional.only(
                  topStart: DsRadius.circularXl,
                  topEnd: DsRadius.circularXl,
                  bottomStart: DsRadius.circularXl,
                  bottomEnd: DsRadius.circularXs,
                ),
                boxShadow: context.primaryGlow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SelectableText(
                      body,
                      style: context.dsText.cardTitle.bold.copyWith(
                        color: DsColors.onMedia,
                        letterSpacing: 2,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: DsSizes.iconXs),
                    color: DsColors.onMediaMuted,
                    tooltip: l10n.copy,
                    onPressed: () => _copy(context, body),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Waiting for your message…", with three dots breathing in turn.
class _WaitingPulse extends StatelessWidget {
  const _WaitingPulse();

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: DsSpacing.xxxs),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary,
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fade(begin: 0.25, end: 1, delay: (160 * i).ms, duration: 600.ms),
        DsGaps.hXs,
        Flexible(
          child: Text(
            context.l10n.reverseSmsWaiting,
            style: context.dsText.label,
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
      child: ExcludeSemantics(
        child: AuthPanel(
          padding: const EdgeInsets.all(DsSpacing.lg),
          child: Row(
            children: [
              // Each digit on its own tile, like a boarding pass.
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final digit in code.characters)
                      Container(
                        width: DsSizes.avatarMd,
                        height: DsSizes.avatarLg,
                        margin: const EdgeInsets.symmetric(
                          horizontal: DsSpacing.xxxs,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: context.primaryGradient,
                          borderRadius: DsRadius.borderMd,
                          boxShadow: context.primaryGlow,
                        ),
                        child: Text(
                          digit,
                          style: context.dsText.screenTitle.uiFamily.bold
                              .copyWith(color: DsColors.onMedia, height: 1),
                        ),
                      ),
                  ],
                ),
              ),
              DsGaps.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.shield_rounded,
                          size: DsSizes.iconXs,
                          color: colors.primary,
                        ),
                        DsGaps.hXxs,
                        Flexible(
                          child: Text(
                            context.l10n.matchCodeLabel,
                            style: context.dsText.labelStrong.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    DsGaps.vXxs,
                    Text(
                      context.l10n.matchCodeHint,
                      style: context.dsText.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
