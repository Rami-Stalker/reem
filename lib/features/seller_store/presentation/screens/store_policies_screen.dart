import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/utils/relative_time.dart';
import 'package:ohara/features/seller_store/domain/entities/seller_store.dart';
import 'package:ohara/features/seller_store/presentation/providers/seller_store_providers.dart';
import 'package:ohara/features/seller_store/presentation/widgets/store_form_parts.dart';

/// «سياسات المتجر» — returns, exchanges and care, in her words, on top of
/// the platform's guarantee. Shoppers read them on her store page.
class StorePoliciesScreen extends ConsumerWidget {
  const StorePoliciesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final policies = ref.watch(storePoliciesProvider);
    return StoreSettingsPage(
      icon: Icons.policy_rounded,
      title: l10n.sellerStorePolicies,
      subtitle: l10n.storePoliciesSubtitle,
      onRefresh: () async => ref.invalidate(storePoliciesProvider),
      child: policies.when(
        loading: () => const StoreLoading(),
        error: (error, _) => DsErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(storePoliciesProvider),
        ),
        data: (data) => _PoliciesForm(initial: data),
      ),
    );
  }
}

class _PoliciesForm extends ConsumerStatefulWidget {
  const _PoliciesForm({required this.initial});

  final StorePolicies initial;

  @override
  ConsumerState<_PoliciesForm> createState() => _PoliciesFormState();
}

class _PoliciesFormState extends ConsumerState<_PoliciesForm> {
  late bool _exchanges = widget.initial.acceptsExchanges;
  late final _exchange = TextEditingController(
    text: widget.initial.exchangeNote,
  );
  late final _returns = TextEditingController(text: widget.initial.returnNote);
  late final _care = TextEditingController(text: widget.initial.careNote);
  late final _custom = TextEditingController(
    text: widget.initial.customOrderNote,
  );
  bool _saving = false;

  @override
  void dispose() {
    _exchange.dispose();
    _returns.dispose();
    _care.dispose();
    _custom.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final l10n = context.l10n;
    try {
      await storeCall(
        () => ref.read(sellerStoreApiProvider).savePolicies({
          'accepts_exchanges': _exchanges,
          'exchange_note': _exchange.text,
          'return_note': _returns.text,
          'care_note': _care.text,
          'custom_order_note': _custom.text,
        }),
      );
      if (!mounted) return;
      ref.invalidate(storePoliciesProvider);
      DsSnackbar.success(context, l10n.storePoliciesSaved);
    } catch (error) {
      if (mounted) DsSnackbar.error(context, '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StoreNotice(
          icon: Icons.verified_user_outlined,
          text: l10n.storePoliciesGuarantee(widget.initial.platformReturnDays),
        ),
        DsGaps.vLg,
        SellerPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StoreSwitchRow(
                label: l10n.storePoliciesAcceptsExchanges,
                value: _exchanges,
                onChanged: (value) => setState(() => _exchanges = value),
              ),
              AnimatedSize(
                duration: DsMotion.normal,
                curve: DsMotion.standard,
                child: _exchanges
                    ? Padding(
                        padding: const EdgeInsets.only(top: DsSpacing.md),
                        child: StoreNoteField(
                          controller: _exchange,
                          label: l10n.storePoliciesExchangeNote,
                          hint: l10n.storePoliciesExchangeHint,
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
        DsGaps.vMd,
        StoreNoteField(
          controller: _returns,
          label: l10n.storePoliciesReturnNote,
          hint: l10n.storePoliciesReturnHint,
        ),
        DsGaps.vMd,
        StoreNoteField(
          controller: _care,
          label: l10n.storePoliciesCareNote,
          hint: l10n.storePoliciesCareHint,
        ),
        DsGaps.vMd,
        StoreNoteField(
          controller: _custom,
          label: l10n.storePoliciesCustomNote,
          hint: l10n.storePoliciesCustomHint,
        ),
        DsGaps.vSm,
        Text(
          l10n.storePoliciesShownTo,
          style: context.dsText.caption.tint(palette.muted),
        ),
        if (widget.initial.updatedAt case final at?)
          Text(
            l10n.storeSettingsUpdatedAt(formatCalendarDate(l10n, at)),
            style: context.dsText.caption.tint(palette.muted),
          ),
        DsGaps.vLg,
        DsButton(
          label: l10n.storePoliciesSave,
          icon: Icons.check_rounded,
          isLoading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
