import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/errors/app_exception.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/location/syria_governorates.dart';
import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/core/presentation/providers/core_providers.dart';

/// Q57 — how her boutique delivers.
///
/// Off: every parcel goes to the delivery company the platform contracts.
/// On: she carries the parcels addressed inside her area herself — usually her
/// own city — and the company takes the rest. Checkout decides per parcel, so
/// a change here never moves an order that is already placed.
class SellerDeliverySettingsScreen extends ConsumerStatefulWidget {
  const SellerDeliverySettingsScreen({super.key});

  @override
  ConsumerState<SellerDeliverySettingsScreen> createState() =>
      _SellerDeliverySettingsScreenState();
}

final class _DeliverySettingsApi extends BaseRemoteDataSource {
  const _DeliverySettingsApi(super.dio);

  Future<Map<String, dynamic>> load() =>
      getJson(ApiEndpoints.sellerDeliverySettings);

  Future<Map<String, dynamic>> save(Map<String, dynamic> body) =>
      putJson(ApiEndpoints.sellerDeliverySettings, body: body);
}

class _SellerDeliverySettingsScreenState
    extends ConsumerState<SellerDeliverySettingsScreen> {
  late final _api = _DeliverySettingsApi(ref.read(dioProvider));
  final _cities = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _enabled = false;
  final Set<String> _governorates = {};
  String? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cities.dispose();
    super.dispose();
  }

  void _apply(Map<String, dynamic> json) {
    _enabled = json['self_delivery_enabled'] == true;
    _governorates
      ..clear()
      ..addAll(
        (json['self_delivery_governorates'] as List<dynamic>? ?? const [])
            .whereType<String>(),
      );
    _cities.text =
        (json['self_delivery_cities'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .join('، ');
    _summary = json['summary'] as String?;
  }

  Future<void> _load() async {
    try {
      final json = await _api.load();
      if (!mounted) return;
      setState(() {
        _apply(json);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      DsSnackbar.error(
        context,
        error is AppException ? error.message : error.toString(),
      );
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final cities = _cities.text
        .split(RegExp('[,،\n]'))
        .map((city) => city.trim())
        .where((city) => city.isNotEmpty)
        .toList();
    try {
      final json = await _api.save({
        'self_delivery_enabled': _enabled,
        'self_delivery_governorates': _governorates.toList(),
        'self_delivery_cities': cities,
      });
      if (!mounted) return;
      setState(() {
        _apply(json);
        _saving = false;
      });
      DsSnackbar.success(context, context.l10n.deliverySettingsSaved);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      DsSnackbar.error(
        context,
        error is AppException ? error.message : error.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final atelier = context.atelier;
    final l10n = context.l10n;

    return OharaScrollPage(
      background: const SellerAtelierBackground(),
      backgroundColor: atelier.background,
      slivers: [
        AtelierAppBar(
          icon: Icons.local_shipping_rounded,
          title: l10n.deliverySettingsTitle,
          showBack: true,
        ),
        DsGaps.sliverMd,
        if (_loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(DsSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              atelierGutter(context),
              0,
              atelierGutter(context),
              DsSizes.bottomSafeGap + DsSpacing.huge,
            ),
            sliver: SliverList.list(
              children: [
                if (_summary != null) ...[
                  Text(
                    _summary!,
                    style: context.dsText.body.semibold.tint(atelier.ink),
                  ),
                  DsGaps.vMd,
                ],
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _enabled,
                  onChanged: (value) => setState(() => _enabled = value),
                  title: Text(
                    l10n.deliverySettingsSelfLabel,
                    style: context.dsText.body.semibold.tint(atelier.ink),
                  ),
                  subtitle: Text(
                    _enabled
                        ? l10n.deliverySettingsSelfBody
                        : l10n.deliverySettingsOffBody,
                    style: context.dsText.bodySmall.tint(atelier.muted),
                  ),
                ),
                if (_enabled) ...[
                  DsGaps.vMd,
                  Text(
                    l10n.deliverySettingsGovernorates,
                    style: context.dsText.body.semibold.tint(atelier.ink),
                  ),
                  Text(
                    l10n.deliverySettingsGovernoratesHint,
                    style: context.dsText.caption.tint(atelier.muted),
                  ),
                  DsGaps.vSm,
                  Wrap(
                    spacing: DsSpacing.xs,
                    runSpacing: DsSpacing.xs,
                    children: [
                      for (final governorate in SyriaGovernorates.all)
                        DsChip(
                          label: governorate.name,
                          selected: _governorates.contains(governorate.name),
                          onTap: () => setState(() {
                            if (!_governorates.remove(governorate.name)) {
                              _governorates.add(governorate.name);
                            }
                          }),
                        ),
                    ],
                  ),
                  DsGaps.vLg,
                  DsInputField(
                    controller: _cities,
                    label: l10n.deliverySettingsCities,
                    hint: l10n.deliverySettingsCitiesHint,
                  ),
                ],
                DsGaps.vLg,
                DsButton(
                  label: l10n.deliverySettingsSave,
                  isLoading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
