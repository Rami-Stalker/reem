import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/errors/failure_exception.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/media_asset.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/utils/relative_time.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/verification/domain/entities/account_verification.dart';
import 'package:reem/features/verification/presentation/providers/account_verification_provider.dart';

/// «توثيق الحساب» — asking for the badge, and reading the answer.
///
/// The badge used to appear the moment an account received a sign-in code, so
/// this screen had nothing to do and did not exist. It exists now because the
/// badge does: papers she sends, a person who reads them, and an answer she
/// can act on rather than a colour that changed by itself.
class AccountVerificationScreen extends ConsumerWidget {
  const AccountVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final claim = ref.watch(accountVerificationProvider);

    return ReemScrollPage(
      onRefresh: () async => ref.invalidate(accountVerificationProvider),
      slivers: [
        PremiumAppBar(title: l10n.accountVerification, showBack: true),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.md,
            DsSpacing.lg,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: claim.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: DsSpacing.xxxl),
                child: DsLoadingIndicator(),
              ),
              error: (error, _) => DsErrorState(
                message: messageOf(error),
                onRetry: () => ref.invalidate(accountVerificationProvider),
              ),
              data: (record) => _Body(record: record),
            ),
          ),
        ),
        DsGaps.sliverBottomSafe,
      ],
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.record});

  final AccountVerification? record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // «هل أثبتت رقمها» — a different question from the badge, and the one
    // this screen depends on. The server refuses a claim without it.
    final phoneVerified = ref.watch(
      authNotifierProvider.select((s) => s.user?.phoneVerifiedAt != null),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (record != null) ...[
          _StatusCard(record: record!),
          DsGaps.vLg,
        ] else ...[
          Text(l10n.accountVerificationBlurb, style: context.dsText.body),
          DsGaps.vLg,
        ],

        if (!phoneVerified)
          _NeedsPhone(
            onOpen: () => context.push(RoutePaths.securitySettings),
          )
        else if (record == null ||
            (record!.canResubmit &&
                record!.status != AccountVerificationStatus.approved))
          _ClaimForm(existing: record)
        else if (record!.status.isOpen)
          _WithdrawRow(onDone: () => ref.invalidate(accountVerificationProvider)),

        if (record != null && record!.history.isNotEmpty) ...[
          DsGaps.vXl,
          _History(events: record!.history),
        ],
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.record});

  final AccountVerification record;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.dsColors;
    final (label, tone, icon) = switch (record.status) {
      AccountVerificationStatus.approved => (
        l10n.accountVerificationStatusApproved,
        c.success,
        Icons.verified_rounded,
      ),
      AccountVerificationStatus.needsMoreInfo => (
        l10n.accountVerificationStatusNeedsInfo,
        c.warning,
        Icons.help_outline_rounded,
      ),
      AccountVerificationStatus.rejected => (
        l10n.accountVerificationStatusRejected,
        c.error,
        Icons.cancel_outlined,
      ),
      AccountVerificationStatus.revoked => (
        l10n.accountVerificationStatusRevoked,
        c.error,
        Icons.remove_moderator_outlined,
      ),
      AccountVerificationStatus.underReview => (
        l10n.accountVerificationStatusUnderReview,
        c.info,
        Icons.hourglass_top_rounded,
      ),
      AccountVerificationStatus.pending => (
        l10n.accountVerificationStatusPending,
        c.info,
        Icons.schedule_rounded,
      ),
    };

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: tone),
              DsGaps.hSm,
              Expanded(
                child: Text(label, style: context.dsText.cardTitle.bold),
              ),
            ],
          ),
          DsGaps.vXs,
          Text(
            record.isApproved
                ? l10n.accountVerificationApprovedBlurb
                // The reviewer's own words, which is the difference between a
                // refusal she can answer and one she can only stare at.
                : record.reviewNote ?? l10n.accountVerificationBlurb,
            style: context.dsText.body.tint(c.onSurfaceVariant),
          ),
          DsGaps.vXs,
          Text(
            formatRelativeTime(l10n, record.reviewedAt ?? record.submittedAt),
            style: context.dsText.caption.tint(c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _NeedsPhone extends StatelessWidget {
  const _NeedsPhone({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.accountVerificationNeedsPhone,
            style: context.dsText.body.semibold,
          ),
          DsGaps.vSm,
          SecondaryButton(
            label: context.l10n.securityTitle,
            icon: Icons.phone_iphone_rounded,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}

class _ClaimForm extends ConsumerStatefulWidget {
  const _ClaimForm({this.existing});

  final AccountVerification? existing;

  @override
  ConsumerState<_ClaimForm> createState() => _ClaimFormState();
}

class _ClaimFormState extends ConsumerState<_ClaimForm> {
  final _formKey = GlobalKey<FormState>();
  late final _legalName = TextEditingController(
    text: widget.existing?.legalName ?? '',
  );
  late final _documentType = TextEditingController(
    text: widget.existing?.documentType ?? '',
  );
  late final _note = TextEditingController(text: widget.existing?.note ?? '');

  late String? _front = widget.existing?.documentFrontUrl;
  late String? _back = widget.existing?.documentBackUrl;
  late String? _selfie = widget.existing?.selfieUrl;

  bool _uploading = false;
  bool _submitting = false;

  @override
  void dispose() {
    _legalName.dispose();
    _documentType.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_front == null) {
      DsSnackbar.show(
        context,
        message: context.l10n.accountVerificationFront,
        type: DsSnackbarType.warning,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref
          .read(accountVerificationDataSourceProvider)
          .submit(
            legalName: _legalName.text.trim(),
            documentType: _documentType.text.trim().isEmpty
                ? null
                : _documentType.text.trim(),
            documentFrontUrl: _front,
            documentBackUrl: _back,
            selfieUrl: _selfie,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      if (!mounted) return;
      ref.invalidate(accountVerificationProvider);
      DsSnackbar.success(context, context.l10n.accountVerificationSent);
    } on Object catch (error) {
      if (mounted) DsSnackbar.error(context, messageOf(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsInputField(
            controller: _legalName,
            label: l10n.accountVerificationLegalName,
            maxLength: 120,
            prefixIcon: const Icon(Icons.badge_outlined),
            validator: (value) => (value ?? '').trim().length < 2
                ? l10n.fieldRequired
                : null,
          ),
          DsGaps.vMd,
          DsInputField(
            controller: _documentType,
            label: l10n.accountVerificationDocType,
            hint: l10n.accountVerificationDocTypeHint,
            maxLength: 60,
            prefixIcon: const Icon(Icons.description_outlined),
          ),
          DsGaps.vLg,

          // Private by construction: `MediaPurpose.verification` is stored
          // behind the server's authorisation, readable by her and by a
          // reviewer and by nobody else on Reem.
          DsMediaField(
            label: l10n.accountVerificationFront,
            purpose: MediaPurpose.verification,
            maxItems: 1,
            initialUrls: [?_front],
            enabled: !_submitting,
            onUploadingChanged: (busy) => setState(() => _uploading = busy),
            onChanged: (urls) => setState(() => _front = urls.firstOrNull),
          ),
          DsGaps.vMd,
          DsMediaField(
            label: l10n.accountVerificationBack,
            purpose: MediaPurpose.verification,
            maxItems: 1,
            initialUrls: [?_back],
            enabled: !_submitting,
            onUploadingChanged: (busy) => setState(() => _uploading = busy),
            onChanged: (urls) => setState(() => _back = urls.firstOrNull),
          ),
          DsGaps.vMd,
          DsMediaField(
            label: l10n.accountVerificationSelfie,
            purpose: MediaPurpose.verification,
            maxItems: 1,
            initialUrls: [?_selfie],
            enabled: !_submitting,
            onUploadingChanged: (busy) => setState(() => _uploading = busy),
            onChanged: (urls) => setState(() => _selfie = urls.firstOrNull),
          ),
          DsGaps.vXs,
          Text(
            l10n.accountVerificationPrivacy,
            style: context.dsText.caption.tint(
              context.dsColors.onSurfaceVariant,
            ),
          ),

          DsGaps.vLg,
          DsInputField(
            controller: _note,
            label: l10n.accountVerificationNote,
            maxLines: 4,
            minLines: 3,
            maxLength: 1000,
          ),
          DsGaps.vLg,
          PrimaryButton(
            label: widget.existing == null
                ? l10n.accountVerificationSubmit
                : l10n.accountVerificationResubmit,
            icon: Icons.verified_user_outlined,
            isLoading: _submitting,
            onPressed: _submitting || _uploading ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _WithdrawRow extends ConsumerStatefulWidget {
  const _WithdrawRow({required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<_WithdrawRow> createState() => _WithdrawRowState();
}

class _WithdrawRowState extends ConsumerState<_WithdrawRow> {
  bool _busy = false;

  Future<void> _withdraw() async {
    setState(() => _busy = true);
    try {
      await ref.read(accountVerificationDataSourceProvider).withdraw();
      if (!mounted) return;
      widget.onDone();
      DsSnackbar.success(context, context.l10n.accountVerificationWithdrawn);
    } on Object catch (error) {
      if (mounted) DsSnackbar.error(context, messageOf(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GhostButton(
      label: context.l10n.accountVerificationWithdraw,
      onPressed: _busy ? null : _withdraw,
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.events});

  final List<AccountVerificationEvent> events;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final event in events) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: c.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                DsGaps.hSm,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.reason,
                        style: context.dsText.bodySmall.tint(c.onSurface),
                      ),
                      Text(
                        formatRelativeTime(context.l10n, event.at),
                        style: context.dsText.caption.tint(c.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (event != events.last) DsGaps.vSm,
          ],
        ],
      ),
    );
  }
}
