import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/auth/domain/entities/auth_account.dart';
import 'package:ohara/features/auth/presentation/providers/auth_account_provider.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';

/// Setting up an authenticator app.
///
/// `POST /auth/totp/enroll` and `/auth/totp/confirm` have existed since
/// Identity v2, and the client parsed `totp_enabled` and `totp_required` off
/// every account payload — but nothing ever called either route. An account
/// the server marked as *requiring* an authenticator therefore could not get
/// one, from inside the app, at all.
///
/// The secret is shown as text rather than a QR code: rendering one would mean
/// taking a new dependency, and every authenticator accepts a typed key. The
/// `otpauth://` URI is offered too, for the apps that can open it directly.
///
/// It is shown exactly once — the server does not return it again after
/// confirmation — so the sheet says so plainly instead of letting her assume
/// she can come back for it.
Future<bool> showTotpEnrolment(BuildContext context, WidgetRef ref) async {
  final started = await ref.read(authRepositoryProvider).enrolTotp();

  if (!context.mounted) return false;

  switch (started) {
    case Error(:final failure):
      DsSnackbar.show(
        context,
        message: failure.message,
        type: DsSnackbarType.error,
      );
      return false;
    case Success(:final data):
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => _EnrolmentBody(enrolment: data),
      );
      if (confirmed == true) {
        ref.invalidate(authAccountProvider);
        return true;
      }
      return false;
  }
}

class _EnrolmentBody extends ConsumerStatefulWidget {
  const _EnrolmentBody({required this.enrolment});

  final TotpEnrolment enrolment;

  @override
  ConsumerState<_EnrolmentBody> createState() => _EnrolmentBodyState();
}

class _EnrolmentBodyState extends ConsumerState<_EnrolmentBody> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;

    setState(() => _busy = true);
    final result = await ref.read(authRepositoryProvider).confirmTotp(code);
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case Success():
        Navigator.of(context).pop(true);
      case Error(:final failure):
        DsSnackbar.show(
          context,
          message: failure.message,
          type: DsSnackbarType.error,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.sm,
        DsSpacing.lg,
        bottom + DsSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.totpSetupTitle, style: context.dsText.sectionTitle.bold),
          const SizedBox(height: DsSpacing.md),

          Text(
            l10n.totpSecretLabel,
            style: context.dsText.label.tint(colors.onSurfaceVariant),
          ),
          const SizedBox(height: DsSpacing.xxs),
          SelectableText(
            widget.enrolment.secret,
            style: context.dsText.body.bold.tint(colors.onSurface),
          ),
          const SizedBox(height: DsSpacing.xxs),
          Text(
            l10n.totpSecretHint,
            style: context.dsText.caption.tint(colors.onSurfaceVariant),
          ),
          const SizedBox(height: DsSpacing.sm),
          DsButton(
            label: l10n.totpCopySecret,
            variant: DsButtonVariant.tonal,
            size: DsButtonSize.sm,
            icon: Icons.copy_rounded,
            isExpanded: false,
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: widget.enrolment.secret),
              );
              if (!context.mounted) return;
              DsSnackbar.show(
                context,
                message: l10n.totpCopied,
                type: DsSnackbarType.success,
              );
            },
          ),

          const SizedBox(height: DsSpacing.lg),
          TextField(
            controller: _code,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            maxLength: widget.enrolment.digits,
            decoration: InputDecoration(
              labelText: l10n.totpCodeLabel,
              prefixIcon: const Icon(Icons.lock_clock_outlined),
            ),
            onSubmitted: (_) => _busy ? null : _confirm(),
          ),
          const SizedBox(height: DsSpacing.sm),
          DsButton(
            label: l10n.totpConfirm,
            isLoading: _busy,
            onPressed: _busy ? null : _confirm,
          ),
        ],
      ),
    );
  }
}
