import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/errors/failure.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/media_asset.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';
import 'package:reem/features/auth/presentation/providers/auth_account_provider.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/auth/presentation/widgets/step_up_sheet.dart';
import 'package:reem/l10n/app_localizations.dart';

/// The seller's application to be verified.
///
/// The form is built only once the existing application has loaded, rather
/// than being seeded into live controllers afterwards. That is not tidiness:
/// the document pickers take their tiles at construction, and a woman told to
/// send more papers must find the ones she already sent still attached — not a
/// blank form that silently replaces them on submit.
class SellerVerificationScreen extends ConsumerWidget {
  const SellerVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verification = ref.watch(sellerVerificationProvider);

    return ReemScrollPage(
      slivers: [
        PremiumAppBar(title: context.l10n.sellerVerification, showBack: true),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.huge,
            DsSpacing.lg,
            140,
          ),
          sliver: SliverToBoxAdapter(
            child: verification.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: DsSpacing.xxxl),
                child: DsLoadingIndicator(),
              ),
              error: (error, _) => DsErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(sellerVerificationProvider),
              ),
              data: (existing) => _ApplicationForm(
                // Rebuild from scratch after a submit returns a new record, so
                // the status banner and the seeded documents agree with it.
                key: ValueKey(existing?.submittedAt.toIso8601String() ?? 'new'),
                existing: existing,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ApplicationForm extends ConsumerStatefulWidget {
  const _ApplicationForm({super.key, required this.existing});

  final SellerVerification? existing;

  @override
  ConsumerState<_ApplicationForm> createState() => _ApplicationFormState();
}

class _ApplicationFormState extends ConsumerState<_ApplicationForm> {
  late final _business = _seed(widget.existing?.businessName);
  late final _legal = _seed(widget.existing?.legalName);
  late final _category = _seed(widget.existing?.businessCategory);
  late final _description = _seed(widget.existing?.storeDescription);
  late final _contactPhone = _seed(widget.existing?.contactPhone);
  late final _contactEmail = _seed(widget.existing?.contactEmail);
  late final _businessAddress = _seed(widget.existing?.businessAddress);
  late final _warehouseAddress = _seed(widget.existing?.warehouseAddress);
  late final _commercialRegistration = _seed(
    widget.existing?.commercialRegistration,
  );
  late final _tax = _seed(widget.existing?.taxId);
  late final _bankName = _seed(widget.existing?.bankName);
  late final _accountHolder = _seed(widget.existing?.accountHolder);
  late final _iban = _seed(widget.existing?.iban);
  late final _shippingMethods = _seed(
    widget.existing?.shippingMethods.join('، '),
  );
  late final _returnPolicy = _seed(widget.existing?.returnPolicy);
  late final _productCategories = _seed(
    widget.existing?.productCategories.join('، '),
  );
  late final _yearsExperience = _seed(
    widget.existing?.yearsExperience?.toString(),
  );
  late final _website = _seed(widget.existing?.website);

  late String? _logoUrl = widget.existing?.storeLogoUrl;
  late String? _governmentIdUrl = widget.existing?.governmentIdUrl;
  late String? _businessLicenseUrl = widget.existing?.businessLicenseUrl;
  late List<String> _documentUrls = List.of(widget.existing?.documentUrls ?? const []);

  /// One flag per picker rather than a shared counter: they settle
  /// independently and a counter would need every callback to be exactly
  /// balanced to ever reach zero again.
  final _uploading = <String, bool>{};

  bool _submitting = false;

  bool get _isUploading => _uploading.values.any((busy) => busy);

  TextEditingController _seed(String? value) =>
      TextEditingController(text: value ?? '');

  @override
  void dispose() {
    for (final controller in [
      _business,
      _legal,
      _category,
      _description,
      _contactPhone,
      _contactEmail,
      _businessAddress,
      _warehouseAddress,
      _commercialRegistration,
      _tax,
      _bankName,
      _accountHolder,
      _iban,
      _shippingMethods,
      _returnPolicy,
      _productCategories,
      _yearsExperience,
      _website,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final l10n = context.l10n;

    if (_isUploading) {
      DsSnackbar.show(
        context,
        message: l10n.verificationUploadPending,
        type: DsSnackbarType.warning,
      );
      return;
    }

    final shipping = _splitList(_shippingMethods.text);
    final categories = _splitList(_productCategories.text);
    final years = int.tryParse(_yearsExperience.text.trim());

    // Named, in the order they appear on screen. The old form answered every
    // omission with "complete all required fields", which on a form this long
    // is a puzzle rather than an error message.
    final missing = <(String, bool)>[
      (l10n.businessName, _business.text.trim().isEmpty),
      (l10n.ownerLegalName, _legal.text.trim().isEmpty),
      (l10n.businessCategory, _category.text.trim().isEmpty),
      (l10n.storeDescription, _description.text.trim().length < 20),
      (l10n.storeLogo, (_logoUrl ?? '').isEmpty),
      (l10n.contactPhone, _contactPhone.text.trim().isEmpty),
      (l10n.contactEmail, _contactEmail.text.trim().isEmpty),
      (l10n.businessAddress, _businessAddress.text.trim().isEmpty),
      (l10n.warehouseAddress, _warehouseAddress.text.trim().isEmpty),
      (l10n.commercialRegistration, _commercialRegistration.text.trim().isEmpty),
      (l10n.governmentIdDocument, (_governmentIdUrl ?? '').isEmpty),
      (l10n.businessLicenseDocument, (_businessLicenseUrl ?? '').isEmpty),
      (l10n.additionalDocuments, _documentUrls.isEmpty),
      (l10n.bankName, _bankName.text.trim().isEmpty),
      (l10n.accountHolder, _accountHolder.text.trim().isEmpty),
      (l10n.iban, _iban.text.trim().isEmpty),
      (l10n.shippingMethods, shipping.isEmpty),
      (l10n.returnPolicy, _returnPolicy.text.trim().length < 10),
      (l10n.productCategories, categories.isEmpty),
      (l10n.yearsOfExperience, years == null),
    ];

    // A list of records, not a map keyed by label: two fields sharing a label
    // would silently collapse into one check, and the order here is the order
    // they appear on screen, so she is sent to the first gap rather than the
    // last.
    final firstMissing = missing
        .where((entry) => entry.$2)
        .map((entry) => entry.$1)
        .firstOrNull;
    if (firstMissing != null) {
      DsSnackbar.show(
        context,
        message: l10n.verificationFieldRequired(firstMissing),
        type: DsSnackbarType.error,
      );
      return;
    }

    setState(() => _submitting = true);

    // The server guards this at AAL3 (`@RequireStepUp(..., 'seller_verification')`)
    // — bank details and a photograph of an ID are worth a second factor. Left
    // unwrapped, submit answers with a bare STEP_UP_REQUIRED snackbar and the
    // application can never be sent from the app at all.
    final stepUp = await runWithStepUp(
      context,
      ref,
      action: _postApplication,
    );

    if (!mounted) return;

    final result = stepUp.shouldRetry
        ? await _postApplication()
        : stepUp.didSucceed
        ? const Success<Object?>(null)
        : Error<Object?>(ServerFailure(stepUp.message ?? ''));

    if (!mounted) return;
    setState(() => _submitting = false);

    switch (result) {
      case Success():
        ref.invalidate(sellerVerificationProvider);
        ref.invalidate(authAccountProvider);
        await ref.read(authNotifierProvider.notifier).refreshUser();
        if (!mounted) return;
        DsSnackbar.show(
          context,
          message: context.l10n.verificationSubmitted,
          type: DsSnackbarType.success,
        );
      case Error(:final failure):
        // A cancelled step-up carries no message: she backed out on purpose
        // and does not need to be told what she just did.
        if (failure.message.isEmpty) return;
        DsSnackbar.show(
          context,
          message: failure.message,
          type: DsSnackbarType.error,
        );
    }
  }

  Future<Result<Object?>> _postApplication() {
    final shipping = _splitList(_shippingMethods.text);
    final categories = _splitList(_productCategories.text);
    return ref
        .read(authRepositoryProvider)
        .submitSellerVerification(
          businessName: _business.text.trim(),
          legalName: _legal.text.trim(),
          businessCategory: _category.text.trim(),
          storeDescription: _description.text.trim(),
          storeLogoUrl: _logoUrl!,
          contactPhone: _contactPhone.text.trim(),
          contactEmail: _contactEmail.text.trim(),
          businessAddress: _businessAddress.text.trim(),
          warehouseAddress: _warehouseAddress.text.trim(),
          commercialRegistration: _commercialRegistration.text.trim(),
          governmentIdUrl: _governmentIdUrl!,
          businessLicenseUrl: _businessLicenseUrl!,
          taxId: _nullIfEmpty(_tax.text),
          bankName: _bankName.text.trim(),
          accountHolder: _accountHolder.text.trim(),
          iban: _iban.text.trim(),
          shippingMethods: shipping,
          returnPolicy: _returnPolicy.text.trim(),
          productCategories: categories,
          yearsExperience: int.parse(_yearsExperience.text.trim()),
          website: _nullIfEmpty(_website.text),
          documentUrls: _documentUrls,
        );
  }

  /// Accepts both the Arabic comma and the Latin one — the keyboard she is
  /// typing on decides which she gets, and neither should be a validation
  /// failure she has to work out for herself.
  List<String> _splitList(String value) => value
      .split(RegExp('[،,]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  String? _nullIfEmpty(String value) =>
      value.trim().isEmpty ? null : value.trim();

  void _setUploading(String slot, bool busy) =>
      setState(() => _uploading[slot] = busy);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = !_submitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusBanner(existing: widget.existing),
        const SizedBox(height: DsSpacing.xl),

        _Section(
          title: l10n.verificationSectionStore,
          children: [
            _input(_business, l10n.businessName, Icons.storefront_outlined),
            _input(_legal, l10n.ownerLegalName, Icons.badge_outlined),
            _input(_category, l10n.businessCategory, Icons.category_outlined),
            _input(
              _description,
              l10n.storeDescription,
              Icons.notes_outlined,
              maxLines: 4,
            ),
            DsMediaField(
              label: l10n.storeLogo,
              purpose: MediaPurpose.storeLogo,
              maxItems: 1,
              enabled: enabled,
              initialUrls: [?_logoUrl],
              onChanged: (urls) => _logoUrl = urls.firstOrNull,
              onUploadingChanged: (busy) => _setUploading('logo', busy),
            ),
          ],
        ),

        _Section(
          title: l10n.verificationSectionContact,
          children: [
            _input(
              _contactPhone,
              l10n.contactPhone,
              Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            _input(
              _contactEmail,
              l10n.contactEmail,
              Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
            ),
            _input(
              _businessAddress,
              l10n.businessAddress,
              Icons.location_on_outlined,
              maxLines: 2,
            ),
            _input(
              _warehouseAddress,
              l10n.warehouseAddress,
              Icons.warehouse_outlined,
              maxLines: 2,
            ),
          ],
        ),

        _Section(
          title: l10n.verificationSectionDocuments,
          // Said once, above the three private pickers rather than on each:
          // she is about to photograph her national ID, and the question of
          // who will see it deserves an answer before the first tap.
          note: l10n.verificationDocumentsPrivate,
          children: [
            _input(
              _commercialRegistration,
              l10n.commercialRegistration,
              Icons.verified_outlined,
            ),
            _input(_tax, l10n.taxNumber, Icons.receipt_long_outlined),
            const SizedBox(height: DsSpacing.xs),
            DsMediaField(
              label: l10n.governmentIdDocument,
              helperText: l10n.verificationDocumentsHint,
              purpose: MediaPurpose.verification,
              documents: true,
              maxItems: 1,
              enabled: enabled,
              initialUrls: [?_governmentIdUrl],
              onChanged: (urls) => _governmentIdUrl = urls.firstOrNull,
              onUploadingChanged: (busy) => _setUploading('id', busy),
            ),
            const SizedBox(height: DsSpacing.lg),
            DsMediaField(
              label: l10n.businessLicenseDocument,
              helperText: l10n.mediaDocumentsHint,
              purpose: MediaPurpose.verification,
              documents: true,
              maxItems: 1,
              enabled: enabled,
              initialUrls: [?_businessLicenseUrl],
              onChanged: (urls) => _businessLicenseUrl = urls.firstOrNull,
              onUploadingChanged: (busy) => _setUploading('licence', busy),
            ),
            const SizedBox(height: DsSpacing.lg),
            DsMediaField(
              label: l10n.additionalDocuments,
              helperText: l10n.mediaDocumentsHint,
              purpose: MediaPurpose.verification,
              documents: true,
              maxItems: 6,
              enabled: enabled,
              initialUrls: _documentUrls,
              onChanged: (urls) => _documentUrls = urls,
              onUploadingChanged: (busy) => _setUploading('extra', busy),
            ),
          ],
        ),

        _Section(
          title: l10n.verificationSectionPayout,
          children: [
            _input(_bankName, l10n.bankName, Icons.account_balance_outlined),
            _input(
              _accountHolder,
              l10n.accountHolder,
              Icons.person_pin_outlined,
            ),
            _input(_iban, l10n.iban, Icons.credit_card_outlined),
          ],
        ),

        _Section(
          title: l10n.verificationSectionOperations,
          children: [
            _input(
              _shippingMethods,
              l10n.shippingMethods,
              Icons.local_shipping_outlined,
              hint: l10n.shippingMethodsHint,
            ),
            _input(
              _returnPolicy,
              l10n.returnPolicy,
              Icons.assignment_return_outlined,
              maxLines: 4,
            ),
            _input(
              _productCategories,
              l10n.productCategories,
              Icons.inventory_2_outlined,
              hint: l10n.productCategoriesHint,
            ),
            _input(
              _yearsExperience,
              l10n.yearsOfExperience,
              Icons.timeline_outlined,
              keyboardType: TextInputType.number,
            ),
            _input(
              _website,
              l10n.website,
              Icons.language_outlined,
              keyboardType: TextInputType.url,
            ),
          ],
        ),

        const SizedBox(height: DsSpacing.lg),
        PrimaryButton(
          label: l10n.submitVerification,
          icon: Icons.verified_user_outlined,
          onPressed: _submitting ? null : _submit,
          isLoading: _submitting,
        ),
      ],
    );
  }

  Widget _input(
    TextEditingController controller,
    String label,
    IconData icon, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.md),
      child: DsInputField(
        controller: controller,
        label: label,
        hint: hint,
        maxLines: maxLines,
        keyboardType: keyboardType,
        enabled: !_submitting,
        prefixIcon: Icon(icon, color: context.dsColors.primary),
      ),
    );
  }
}

// ── Pieces ──────────────────────────────────────────────────────────────────

/// Groups the application's twenty-odd fields into five readable passes. The
/// form used to be one unbroken column, which reads as a wall rather than a
/// task with an end to it.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.note});

  final String title;
  final String? note;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.lg),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: context.dsText.cardTitle.copyWith(
                color: c.onSurface,
                fontWeight: DsTypography.bold,
              ),
            ),
            if (note != null) ...[
              const SizedBox(height: DsSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 16, color: c.success),
                  const SizedBox(width: DsSpacing.xxs),
                  Expanded(
                    child: Text(
                      note!,
                      style: context.dsText.cardSubtitle.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: DsSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.existing});

  final SellerVerification? existing;

  /// The API sends the enum lowercased. Showing it raw — `NEEDS_MORE_DOCUMENTS`
  /// in Latin capitals on an Arabic screen — is what this used to do, and it
  /// reads as a leaked implementation detail to the one person who most needs
  /// to understand where her application stands.
  String _label(AppLocalizations l10n, String? status) => switch (status) {
    null || 'not_submitted' => l10n.noVerificationSubmitted,
    'pending' => l10n.verificationStatusPending,
    'under_review' => l10n.verificationStatusUnderReview,
    'needs_more_documents' => l10n.verificationStatusNeedsMoreDocuments,
    'needs_more_info' => l10n.verificationStatusNeedsMoreInfo,
    'approved' => l10n.verificationStatusApproved,
    'rejected' => l10n.verificationStatusRejected,
    'suspended' => l10n.verificationStatusSuspended,
    // A status this build has not heard of. Better the server's word than a
    // blank where the state should be.
    _ => status,
  };

  IconData _iconFor(String? status) => switch (status) {
    'approved' => Icons.verified_rounded,
    'rejected' || 'suspended' => Icons.report_gmailerrorred_rounded,
    null || 'not_submitted' => Icons.verified_outlined,
    _ => Icons.hourglass_bottom_rounded,
  };

  Color _tintFor(BuildContext context, String? status) => switch (status) {
    'approved' => context.dsColors.success,
    'rejected' || 'suspended' => context.dsColors.error,
    _ => context.dsColors.primary,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;
    final item = existing;

    return SurfaceCard(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconFor(item?.status), color: _tintFor(context, item?.status)),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label(l10n, item?.status),
                  style: context.dsText.tileTitle.copyWith(
                    fontWeight: DsTypography.bold,
                  ),
                ),
                const SizedBox(height: DsSpacing.xxxs),
                Text(
                  // A reviewer's note is the whole reason she is back on this
                  // screen, so it outranks the generic prompt.
                  item?.reviewReason ??
                      item?.rejectionReason ??
                      (item == null
                          ? l10n.submitBusinessDetails
                          : l10n.verificationResubmitNotice),
                  style: context.dsText.cardSubtitle.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
