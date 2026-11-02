import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/seller_earnings/domain/entities/seller_earnings.dart';
import 'package:ohara/features/seller_earnings/presentation/providers/seller_earnings_provider.dart';

/// «إعدادات الدفع» — where a boutique is paid.
///
/// Two rails only: a Sham Cash wallet or a Visa card. Whatever is saved here
/// is where every withdrawal request goes; the card number is sealed on the
/// server and only its last four digits ever come back.
class SellerPayoutSettingsScreen extends ConsumerStatefulWidget {
  const SellerPayoutSettingsScreen({super.key});

  @override
  ConsumerState<SellerPayoutSettingsScreen> createState() =>
      _SellerPayoutSettingsScreenState();
}

class _SellerPayoutSettingsScreenState
    extends ConsumerState<SellerPayoutSettingsScreen> {
  /// Showing the form rather than the saved account.
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final account = ref.watch(payoutAccountProvider);

    return OharaScrollPage(
      onRefresh: () async => ref.invalidate(payoutAccountProvider),
      background: const SellerAtelierBackground(),
      backgroundColor: context.atelier.background,
      slivers: [
        AtelierAppBar(
          icon: Icons.credit_card_rounded,
          title: l10n.sellerPaymentSettings,
          subtitle: l10n.payoutSettingsSubtitle,
          showBack: true,
        ),
        DsGaps.sliverMd,
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: atelierGutter(context)),
          sliver: SliverToBoxAdapter(
            child: account.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(DsSpacing.xxl),
                child: Center(child: DsLoadingIndicator()),
              ),
              error: (error, _) => DsErrorState(
                message: '$error',
                onRetry: () => ref.invalidate(payoutAccountProvider),
              ),
              data: (saved) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Intro(),
                  DsGaps.vLg,
                  if (saved != null && !_editing)
                    _SavedAccount(
                      account: saved,
                      onChange: () => setState(() => _editing = true),
                    )
                  else
                    PayoutAccountForm(
                      existing: saved,
                      onSaved: () => setState(() => _editing = false),
                      onCancel: saved == null
                          ? null
                          : () => setState(() => _editing = false),
                    ),
                ],
              ),
            ),
          ),
        ),
        // The box form: the checker reads the Column above as the open list.
        const SliverToBoxAdapter(child: DsGaps.bottomSafe),
      ],
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return SellerPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, size: 20, color: palette.gold),
          DsGaps.hSm,
          Expanded(
            child: Text(
              context.l10n.payoutSettingsIntro,
              style: context.dsText.bodySmall.tint(palette.ink).copyWith(
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The account she saved, masked, with the way to change or remove it.
class _SavedAccount extends ConsumerWidget {
  const _SavedAccount({required this.account, required this.onChange});

  final PayoutAccount account;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.atelier;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AtelierHeading(title: l10n.payoutCurrentTitle),
        DsGaps.vSm,
        PayoutDestinationCard(account: account),
        DsGaps.vMd,
        Row(
          children: [
            Expanded(
              child: DsButton(
                label: l10n.payoutChange,
                icon: Icons.edit_outlined,
                variant: DsButtonVariant.secondary,
                onPressed: onChange,
              ),
            ),
            DsGaps.hSm,
            Expanded(
              child: DsButton(
                label: l10n.payoutRemove,
                icon: Icons.delete_outline_rounded,
                variant: DsButtonVariant.ghost,
                onPressed: () => _remove(context, ref),
              ),
            ),
          ],
        ),
        DsGaps.vMd,
        Text(
          l10n.payoutSecureNote,
          style: context.dsText.caption.tint(palette.muted),
        ),
      ],
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await DsBottomSheet.show<bool>(
      context,
      builder: (sheetContext) => DsSheetScaffold(
        title: l10n.payoutRemoveConfirm,
        subtitle: l10n.payoutRemoveBlurb,
        child: Column(
          children: [
            DsButton(
              label: l10n.payoutRemove,
              variant: DsButtonVariant.danger,
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
            DsGaps.vSm,
            DsButton(
              label: l10n.cancel,
              variant: DsButtonVariant.ghost,
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await ref
        .read(sellerEarningsRepositoryProvider)
        .removePayoutAccount();
    if (!context.mounted) return;
    switch (result) {
      case Success():
        ref
          ..invalidate(payoutAccountProvider)
          ..invalidate(sellerEarningsNotifierProvider);
        DsSnackbar.show(
          context,
          message: l10n.payoutRemoved,
          type: DsSnackbarType.success,
        );
      case Error(:final failure):
        DsSnackbar.error(context, failure.message);
    }
  }
}

/// «شام كاش · •••• 4567» on a card: what she will be paid to.
class PayoutDestinationCard extends StatelessWidget {
  const PayoutDestinationCard({super.key, required this.account, this.onTap});

  final PayoutAccount account;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final isVisa = account.method == PayoutMethod.visa;
    return SellerPanel(
      onTap: onTap,
      child: Row(
        children: [
          _MethodBadge(method: account.method),
          DsGaps.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVisa ? l10n.payoutMethodVisa : l10n.payoutMethodShamCash,
                  style: context.dsText.tileTitle.bold.tint(palette.ink),
                ),
                DsGaps.vXxs,
                Text(
                  '\u2066${account.masked}\u2069',
                  style: context.dsText.body.tint(palette.ink).tabular,
                ),
                Text(
                  account.holderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.caption.tint(palette.muted),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: palette.muted),
        ],
      ),
    );
  }
}

class _MethodBadge extends StatelessWidget {
  const _MethodBadge({required this.method, this.selected = true});

  final PayoutMethod method;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final tint = selected ? palette.gold : palette.muted;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: DsRadius.borderMd,
      ),
      child: Icon(
        method == PayoutMethod.visa
            ? Icons.credit_card_rounded
            : Icons.account_balance_wallet_rounded,
        color: tint,
        size: 22,
      ),
    );
  }
}

/// Choosing Sham Cash or Visa and entering its details.
class PayoutAccountForm extends ConsumerStatefulWidget {
  const PayoutAccountForm({
    super.key,
    this.existing,
    this.onSaved,
    this.onCancel,
  });

  final PayoutAccount? existing;
  final VoidCallback? onSaved;
  final VoidCallback? onCancel;

  @override
  ConsumerState<PayoutAccountForm> createState() => _PayoutAccountFormState();
}

class _PayoutAccountFormState extends ConsumerState<PayoutAccountForm> {
  final _formKey = GlobalKey<FormState>();
  late PayoutMethod _method =
      widget.existing?.method ?? PayoutMethod.shamCash;
  late final _holder = TextEditingController(
    text: widget.existing?.holderName ?? '',
  );
  final _shamCash = TextEditingController();
  final _card = TextEditingController();
  bool _saving = false;

  /// Editing a saved Visa: an empty card field keeps the same card.
  bool get _canKeepCard =>
      widget.existing?.method == PayoutMethod.visa &&
      _method == PayoutMethod.visa;

  @override
  void dispose() {
    _holder.dispose();
    _shamCash.dispose();
    _card.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final l10n = context.l10n;
    final cardDigits = _card.text.replaceAll(RegExp(r'\D'), '');
    final result = await ref
        .read(sellerEarningsRepositoryProvider)
        .savePayoutAccount(
          method: _method,
          holderName: _holder.text.trim(),
          shamCashNumber: _method == PayoutMethod.shamCash
              ? _shamCash.text.trim()
              : null,
          cardNumber: _method == PayoutMethod.visa && cardDigits.isNotEmpty
              ? cardDigits
              : null,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Success():
        ref
          ..invalidate(payoutAccountProvider)
          ..invalidate(sellerEarningsNotifierProvider);
        DsSnackbar.show(
          context,
          message: l10n.payoutSaved,
          type: DsSnackbarType.success,
        );
        widget.onSaved?.call();
      case Error(:final failure):
        DsSnackbar.error(context, failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final method in PayoutMethod.values) ...[
                if (method != PayoutMethod.values.first) DsGaps.hSm,
                Expanded(
                  child: _MethodChoice(
                    method: method,
                    selected: method == _method,
                    onTap: () => setState(() => _method = method),
                  ),
                ),
              ],
            ],
          ),
          DsGaps.vLg,
          DsInputField(
            controller: _holder,
            label: l10n.payoutHolderName,
            hint: l10n.payoutHolderNameHint,
            prefixIcon: const Icon(Icons.person_outline_rounded),
            textInputAction: TextInputAction.next,
            validator: (value) => (value ?? '').trim().length < 3
                ? l10n.payoutErrorHolder
                : null,
          ),
          DsGaps.vMd,
          if (_method == PayoutMethod.shamCash)
            DsInputField(
              key: const ValueKey(PayoutMethod.shamCash),
              controller: _shamCash,
              label: l10n.payoutShamCashNumber,
              hint: l10n.payoutShamCashNumberHint,
              prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
              keyboardType: TextInputType.visiblePassword,
              autocorrect: false,
              validator: (value) => isValidShamCash(value ?? '')
                  ? null
                  : l10n.payoutErrorShamCash,
            )
          else
            DsInputField(
              key: const ValueKey(PayoutMethod.visa),
              controller: _card,
              label: l10n.payoutCardNumber,
              hint: _canKeepCard
                  ? l10n.payoutCardNumberKeep(widget.existing!.masked)
                  : l10n.payoutCardNumberHint,
              prefixIcon: const Icon(Icons.credit_card_rounded),
              keyboardType: TextInputType.number,
              autocorrect: false,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(19),
                const CardNumberFormatter(),
              ],
              validator: (value) {
                final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                if (digits.isEmpty && _canKeepCard) return null;
                return isValidVisa(digits) ? null : l10n.payoutErrorVisa;
              },
            ),
          DsGaps.vSm,
          Text(
            l10n.payoutSecureNote,
            style: context.dsText.caption.tint(palette.muted),
          ),
          DsGaps.vLg,
          DsButton(
            label: l10n.payoutSave,
            icon: Icons.check_rounded,
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
          if (widget.onCancel case final cancel?) ...[
            DsGaps.vSm,
            DsButton(
              label: l10n.cancel,
              variant: DsButtonVariant.ghost,
              onPressed: _saving ? null : cancel,
            ),
          ],
        ],
      ),
    );
  }
}

class _MethodChoice extends StatelessWidget {
  const _MethodChoice({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PayoutMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final isVisa = method == PayoutMethod.visa;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: DsRadius.borderLg,
          child: AnimatedContainer(
            duration: DsMotion.normal,
            curve: DsMotion.standard,
            padding: DsSpacing.paddingMd,
            decoration: BoxDecoration(
              color: selected
                  ? palette.gold.withValues(alpha: 0.08)
                  : palette.surface,
              borderRadius: DsRadius.borderLg,
              border: Border.all(
                color: selected ? palette.gold : palette.line,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _MethodBadge(method: method, selected: selected),
                    const Spacer(),
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      size: 20,
                      color: selected ? palette.gold : palette.muted,
                    ),
                  ],
                ),
                DsGaps.vSm,
                Text(
                  isVisa ? l10n.payoutMethodVisa : l10n.payoutMethodShamCash,
                  style: context.dsText.tileTitle.bold.tint(palette.ink),
                ),
                Text(
                  isVisa
                      ? l10n.payoutMethodVisaHint
                      : l10n.payoutMethodShamCashHint,
                  style: context.dsText.caption.tint(palette.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Groups a card number in fours as she types: «4111 1111 1111 1111».
class CardNumberFormatter extends TextInputFormatter {
  const CardNumberFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// The same rule the server applies: a 09… phone or an account code.
bool isValidShamCash(String raw) {
  final compact = raw.replaceAll(RegExp(r'[\s-]'), '');
  final phone = compact.replaceFirst(RegExp(r'^(\+?963|00963)'), '0');
  if (RegExp(r'^09\d{8}$').hasMatch(phone)) return true;
  return RegExp(r'^[A-Za-z0-9]{6,32}$').hasMatch(compact);
}

/// A Visa number: 13, 16 or 19 digits, starting with 4, passing Luhn.
bool isValidVisa(String digits) {
  if (!RegExp(r'^4\d{12}(\d{3}){0,2}$').hasMatch(digits)) return false;
  var sum = 0;
  var double = false;
  for (var i = digits.length - 1; i >= 0; i--) {
    var d = digits.codeUnitAt(i) - 48;
    if (double) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
    double = !double;
  }
  return sum % 10 == 0;
}
