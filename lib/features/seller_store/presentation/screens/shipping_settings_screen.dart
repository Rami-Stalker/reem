import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/seller_store/domain/entities/seller_store.dart';
import 'package:ohara/features/seller_store/presentation/providers/seller_store_providers.dart';
import 'package:ohara/features/seller_store/presentation/widgets/store_form_parts.dart';

/// «إعدادات الشحن» — where she ships from, how long she takes to prepare a
/// parcel (the default for every new listing), pickup from her shop, and the
/// platform's own delivery rates for reference.
class ShippingSettingsScreen extends ConsumerWidget {
  const ShippingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(shippingSettingsProvider);
    return StoreSettingsPage(
      icon: Icons.local_shipping_rounded,
      title: l10n.sellerShippingSettings,
      subtitle: l10n.shippingSettingsSubtitle,
      onRefresh: () async => ref.invalidate(shippingSettingsProvider),
      child: settings.when(
        loading: () => const StoreLoading(),
        error: (error, _) => DsErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(shippingSettingsProvider),
        ),
        data: (data) => _ShippingForm(initial: data),
      ),
    );
  }
}

class _ShippingForm extends ConsumerStatefulWidget {
  const _ShippingForm({required this.initial});

  final ShippingSettings initial;

  @override
  ConsumerState<_ShippingForm> createState() => _ShippingFormState();
}

class _ShippingFormState extends ConsumerState<_ShippingForm> {
  final _formKey = GlobalKey<FormState>();
  late String? _governorate = widget.initial.shipsFromGovernorate;
  late final _area = TextEditingController(text: widget.initial.shipsFromArea);
  late int _days = widget.initial.defaultHandlingDays;
  bool _applyToListings = false;
  late bool _pickup = widget.initial.offersPickup;
  late final _pickupAddress = TextEditingController(
    text: widget.initial.pickupAddress,
  );
  late final _pickupHours = TextEditingController(
    text: widget.initial.pickupHours,
  );
  late final _packaging = TextEditingController(
    text: widget.initial.packagingNote,
  );
  bool _saving = false;

  @override
  void dispose() {
    _area.dispose();
    _pickupAddress.dispose();
    _pickupHours.dispose();
    _packaging.dispose();
    super.dispose();
  }

  List<String> get _governorates {
    final names = {
      for (final rate in widget.initial.rates) rate.governorate,
      ?_governorate,
    };
    return names.toList();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final l10n = context.l10n;
    try {
      final saved = await storeCall(
        () => ref.read(sellerStoreApiProvider).saveShipping({
          'ships_from_governorate': _governorate,
          'ships_from_area': _area.text,
          'default_handling_days': _days,
          'apply_to_listings': _applyToListings,
          'offers_pickup': _pickup,
          'pickup_address': _pickupAddress.text,
          'pickup_hours': _pickupHours.text,
          'packaging_note': _packaging.text,
        }),
      );
      if (!mounted) return;
      ref.invalidate(shippingSettingsProvider);
      DsSnackbar.success(
        context,
        l10n.shippingSavedListings(saved.updatedListings ?? 0),
      );
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
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AtelierHeading(title: l10n.shippingShipsFrom),
          DsGaps.vSm,
          SellerPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _governorate,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.shippingGovernorate,
                    prefixIcon: const Icon(Icons.place_outlined),
                  ),
                  items: [
                    for (final name in _governorates)
                      DropdownMenuItem(value: name, child: Text(name)),
                  ],
                  onChanged: (value) => setState(() => _governorate = value),
                ),
                DsGaps.vMd,
                DsInputField(
                  controller: _area,
                  label: l10n.shippingArea,
                  hint: l10n.shippingAreaHint,
                  maxLength: 80,
                ),
              ],
            ),
          ),
          DsGaps.vLg,
          AtelierHeading(title: l10n.shippingHandlingTitle),
          DsGaps.vSm,
          SellerPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: DsSpacing.xs,
                  runSpacing: DsSpacing.xs,
                  children: [
                    for (final days in const [0, 1, 2, 3, 5, 7, 10, 14])
                      ChoiceChip(
                        label: Text(l10n.shippingHandlingDays(days)),
                        selected: days == _days,
                        onSelected: (_) => setState(() => _days = days),
                      ),
                  ],
                ),
                DsGaps.vSm,
                Text(
                  l10n.shippingHandlingHint,
                  style: context.dsText.caption.tint(palette.muted),
                ),
                if (_days != widget.initial.defaultHandlingDays) ...[
                  DsGaps.vSm,
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _applyToListings,
                    onChanged: (value) =>
                        setState(() => _applyToListings = value ?? false),
                    title: Text(
                      l10n.shippingApplyToListings,
                      style: context.dsText.bodySmall.tint(palette.ink),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ],
            ),
          ),
          DsGaps.vLg,
          AtelierHeading(title: l10n.shippingPickupTitle),
          DsGaps.vSm,
          SellerPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StoreSwitchRow(
                  label: l10n.shippingPickupToggle,
                  value: _pickup,
                  onChanged: (value) => setState(() => _pickup = value),
                ),
                AnimatedSize(
                  duration: DsMotion.normal,
                  curve: DsMotion.standard,
                  child: _pickup
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DsGaps.vMd,
                            DsInputField(
                              controller: _pickupAddress,
                              label: l10n.shippingPickupAddress,
                              prefixIcon: const Icon(Icons.storefront_outlined),
                              maxLength: 200,
                              validator: (value) =>
                                  _pickup && (value ?? '').trim().isEmpty
                                  ? l10n.shippingPickupNeedsAddress
                                  : null,
                            ),
                            DsGaps.vSm,
                            DsInputField(
                              controller: _pickupHours,
                              label: l10n.shippingPickupHours,
                              hint: l10n.shippingPickupHoursHint,
                              prefixIcon: const Icon(Icons.schedule_rounded),
                              maxLength: 120,
                            ),
                          ],
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
          DsGaps.vMd,
          StoreNoteField(
            controller: _packaging,
            label: l10n.shippingPackagingNote,
            hint: l10n.shippingPackagingHint,
            maxLength: 400,
          ),
          DsGaps.vLg,
          DsButton(
            label: l10n.shippingSave,
            icon: Icons.check_rounded,
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
          if (widget.initial.rates.isNotEmpty) ...[
            DsGaps.vXl,
            AtelierHeading(title: l10n.shippingRatesTitle),
            DsGaps.vXs,
            Text(
              l10n.shippingRatesNote,
              style: context.dsText.caption.tint(palette.muted),
            ),
            DsGaps.vSm,
            SellerPanel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (index, rate) in widget.initial.rates.indexed) ...[
                    if (index > 0) Divider(height: 1, color: palette.line),
                    _RateRow(rate: rate),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({required this.rate});

  final ShippingRate rate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final eta = rate.etaHoursMax >= 48
        ? l10n.shippingEtaDays(
            (rate.etaHoursMax / 24).ceil(),
            (rate.etaHoursMin / 24).ceil(),
          )
        : l10n.shippingEtaHours(rate.etaHoursMax, rate.etaHoursMin);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.md,
        vertical: DsSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rate.governorate,
                  style: context.dsText.body.tint(palette.ink),
                ),
                Text(
                  rate.isRural ? '$eta · ${l10n.shippingRural}' : eta,
                  style: context.dsText.caption.tint(palette.muted),
                ),
              ],
            ),
          ),
          Text(
            rate.fee.format(),
            style: context.dsText.body.bold.tint(palette.ink).tabular,
          ),
        ],
      ),
    );
  }
}
