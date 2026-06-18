import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/design_system/components/snackbars/app_snackbar.dart'
    show DsSnackbar, DsSnackbarType;
import 'package:reem/core/result/result.dart';

import '../providers/auth_account_provider.dart';
import '../providers/auth_provider.dart';

class SellerVerificationScreen extends ConsumerStatefulWidget {
  const SellerVerificationScreen({super.key});

  @override
  ConsumerState<SellerVerificationScreen> createState() =>
      _SellerVerificationScreenState();
}

class _SellerVerificationScreenState
    extends ConsumerState<SellerVerificationScreen> {
  final _businessController = TextEditingController();
  final _legalController = TextEditingController();
  final _taxController = TextEditingController();
  final _documentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _businessController.dispose();
    _legalController.dispose();
    _taxController.dispose();
    _documentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final docs = _documentController.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (_businessController.text.trim().isEmpty ||
        _legalController.text.trim().isEmpty ||
        docs.isEmpty) {
      DsSnackbar.show(
        context,
        message: 'Business, legal name, and at least one document are required.',
        type: DsSnackbarType.error,
      );
      return;
    }

    setState(() => _submitting = true);
    final result =
        await ref.read(authRepositoryProvider).submitSellerVerification(
              businessName: _businessController.text.trim(),
              legalName: _legalController.text.trim(),
              taxId: _taxController.text.trim().isEmpty
                  ? null
                  : _taxController.text.trim(),
              documentUrls: docs,
            );
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (result) {
      case Success():
        ref.invalidate(sellerVerificationProvider);
        ref.invalidate(authAccountProvider);
        await ref.read(authNotifierProvider.notifier).refreshUser();
        DsSnackbar.show(
          context,
          message: 'Seller verification submitted.',
          type: DsSnackbarType.success,
        );
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
    final verification = ref.watch(sellerVerificationProvider);
    final colors = context.dsColors;

    return ReemScrollPage(
      slivers: [
        PremiumAppBar(title: 'Seller verification', showBack: true),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.huge,
            DsSpacing.lg,
            140,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              verification.when(
                loading: () => const DsLoadingIndicator(),
                error: (error, _) => Text(error.toString()),
                data: (item) => Material(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(DsRadius.md),
                  child: ListTile(
                    leading: Icon(Icons.verified_outlined, color: colors.primary),
                    title: Text(item == null
                        ? 'No verification submitted'
                        : item.status.toUpperCase()),
                    subtitle: Text(
                      item?.rejectionReason ??
                          'Submit business details to unlock seller trust.',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: DsSpacing.xl),
              DsInputField(
                controller: _businessController,
                label: 'Business name',
                prefixIcon: Icon(Icons.storefront_outlined, color: colors.primary),
              ),
              const SizedBox(height: DsSpacing.md),
              DsInputField(
                controller: _legalController,
                label: 'Legal name',
                prefixIcon: Icon(Icons.badge_outlined, color: colors.primary),
              ),
              const SizedBox(height: DsSpacing.md),
              DsInputField(
                controller: _taxController,
                label: 'Tax ID',
                prefixIcon: Icon(Icons.receipt_long_outlined, color: colors.primary),
              ),
              const SizedBox(height: DsSpacing.md),
              DsInputField(
                controller: _documentController,
                label: 'Document URLs',
                hint: 'https://.../license.pdf, https://.../id.pdf',
                maxLines: 3,
                prefixIcon:
                    Icon(Icons.file_present_outlined, color: colors.primary),
              ),
              const SizedBox(height: DsSpacing.lg),
              PrimaryButton(
                label: 'Submit verification',
                icon: Icons.verified_user_outlined,
                onPressed: _submitting ? null : _submit,
                isLoading: _submitting,
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
