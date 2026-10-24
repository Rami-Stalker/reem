import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/location/picked_place.dart';
import 'package:ohara/core/location/presentation/map_location_field.dart';
import 'package:ohara/features/salons/data/datasources/salons_remote_datasource.dart';
import 'package:ohara/features/salons/domain/entities/salon.dart';
import 'package:ohara/features/salons/presentation/providers/salons_providers.dart';

/// «بيانات الصالون» — the same form whether she is opening a salon or fixing
/// a typo in its address.
///
/// One screen rather than a create/edit pair, because the server's endpoint is
/// one upsert: a second form would be the same twenty fields with a different
/// button, and the two would drift.
class SalonEditorScreen extends ConsumerStatefulWidget {
  const SalonEditorScreen({super.key});

  @override
  ConsumerState<SalonEditorScreen> createState() => _SalonEditorScreenState();
}

class _SalonEditorScreenState extends ConsumerState<SalonEditorScreen> {
  final _form = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _tagline = TextEditingController();
  final _about = TextEditingController();
  final _governorate = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _address = TextEditingController();
  final _landmark = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _homeFee = TextEditingController();

  int _slotMinutes = 30;
  int _leadMinutes = 120;
  int _horizonDays = 30;
  int _capacity = 1;
  int _cancellationHours = 4;
  bool _homeService = false;

  /// The salon's pin. Replaces the two coordinate boxes she was asked to
  /// type — nobody knows their own latitude, but everybody knows their door.
  PickedPlace? _pin;

  /// Filled once from the loaded salon. Without the latch, every rebuild of a
  /// `FutureProvider` would overwrite what she is in the middle of typing.
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _tagline,
      _about,
      _governorate,
      _city,
      _district,
      _address,
      _landmark,
      _phone,
      _whatsapp,
      _homeFee,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _seed(Salon salon) {
    _seeded = true;
    _name.text = salon.name;
    _tagline.text = salon.tagline ?? '';
    _about.text = salon.about ?? '';
    _governorate.text = salon.governorate;
    _city.text = salon.city;
    _district.text = salon.district ?? '';
    _address.text = salon.addressLine ?? '';
    _landmark.text = salon.landmark ?? '';
    if (salon.hasCoordinates) {
      _pin = PickedPlace(
        point: LatLng(salon.latitude!, salon.longitude!),
        governorate: salon.governorate,
        city: salon.city,
        district: salon.district,
        road: salon.addressLine,
      );
    }
    _phone.text = salon.phone ?? '';
    _whatsapp.text = salon.whatsapp ?? '';
    _homeFee.text = salon.homeServiceFee?.raw ?? '';
    _slotMinutes = salon.slotMinutes;
    _leadMinutes = salon.leadMinutes;
    _horizonDays = salon.horizonDays;
    _capacity = salon.concurrentCapacity;
    _cancellationHours = salon.cancellationHours;
    _homeService = salon.homeService;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final async = ref.watch(mySalonProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: OharaAppBar(title: context.l10n.salonEditorTitle),
      body: async.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: context.l10n.salonEditorLoadError,
          onRetry: () => ref.invalidate(mySalonProvider),
        ),
        data: (salon) {
          if (salon != null && !_seeded) _seed(salon);
          return _body(salon);
        },
      ),
    );
  }

  Widget _body(Salon? salon) {
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(DsSpacing.lg),
        children: [
          _Section(title: context.l10n.salonEditorSectionProfile),
          DsInputField(
            controller: _name,
            label: context.l10n.salonEditorName,
            labelAbove: true,
            validator: _required,
          ),
          DsGaps.vSm,
          DsInputField(
            controller: _tagline,
            label: context.l10n.salonEditorTagline,
            hint: context.l10n.salonEditorTaglineHint,
            labelAbove: true,
            maxLength: 120,
          ),
          DsGaps.vSm,
          DsInputField(
            controller: _about,
            label: context.l10n.salonEditorAbout,
            labelAbove: true,
            maxLines: 5,
            minLines: 3,
            maxLength: 1000,
          ),

          DsGaps.vLg,
          _Section(title: context.l10n.salonEditorSectionLocation),
          // The quick way: drop a pin and the fields below fill themselves.
          MapLocationField(
            value: _pin,
            onChanged: _applyPin,
            title: context.l10n.shopLocationTitle,
            subtitle: context.l10n.shopLocationSubtitle,
            placeLabel: context.l10n.mapPickerShopHere,
            initialGovernorate: _text(_governorate),
          ),
          if (_pin == null) const MapOrTypeDivider() else DsGaps.vMd,
          DsInputField(
            controller: _governorate,
            label: context.l10n.salonEditorGovernorate,
            labelAbove: true,
            validator: _required,
          ),
          DsGaps.vSm,
          DsInputField(
            controller: _city,
            label: context.l10n.salonEditorCity,
            labelAbove: true,
            validator: _required,
          ),
          DsGaps.vSm,
          DsInputField(
            controller: _district,
            label: context.l10n.salonEditorArea,
            labelAbove: true,
          ),
          DsGaps.vSm,
          DsInputField(
            controller: _address,
            label: context.l10n.salonEditorAddress,
            labelAbove: true,
            validator: _required,
          ),
          DsGaps.vSm,
          DsInputField(
            controller: _landmark,
            label: context.l10n.salonEditorLandmark,
            hint: context.l10n.salonEditorLandmarkHint,
            labelAbove: true,
          ),

          DsGaps.vLg,
          _Section(title: context.l10n.salonEditorSectionContact),
          DsInputField(
            controller: _phone,
            label: context.l10n.salonEditorPhone,
            labelAbove: true,
            keyboardType: TextInputType.phone,
          ),
          DsGaps.vSm,
          DsInputField(
            controller: _whatsapp,
            label: context.l10n.salonEditorWhatsapp,
            labelAbove: true,
            keyboardType: TextInputType.phone,
          ),

          DsGaps.vLg,
          _Section(title: context.l10n.salonEditorSectionBooking),
          _Stepper(
            label: context.l10n.salonEditorSlotLength,
            value: _slotMinutes,
            suffix: context.l10n.salonUnitMinute,
            step: 15,
            min: 15,
            max: 120,
            help: context.l10n.salonEditorSlotLengthHelp,
            onChanged: (value) => setState(() => _slotMinutes = value),
          ),
          _Stepper(
            label: context.l10n.salonEditorLeadTime,
            value: _leadMinutes,
            suffix: context.l10n.salonUnitMinute,
            step: 30,
            min: 0,
            max: 1440,
            help: context.l10n.salonEditorLeadTimeHelp,
            onChanged: (value) => setState(() => _leadMinutes = value),
          ),
          _Stepper(
            label: context.l10n.salonEditorHorizon,
            value: _horizonDays,
            suffix: context.l10n.salonUnitDay,
            step: 5,
            min: 1,
            max: 120,
            help: context.l10n.salonEditorHorizonHelp,
            onChanged: (value) => setState(() => _horizonDays = value),
          ),
          _Stepper(
            label: context.l10n.salonEditorCapacity,
            value: _capacity,
            suffix: '',
            step: 1,
            min: 1,
            max: 20,
            help: context.l10n.salonEditorCapacityHelp,
            onChanged: (value) => setState(() => _capacity = value),
          ),
          _Stepper(
            label: context.l10n.salonEditorLateCancel,
            value: _cancellationHours,
            suffix: context.l10n.salonUnitHour,
            step: 1,
            min: 0,
            max: 48,
            help: context.l10n.salonEditorLateCancelHelp,
            onChanged: (value) => setState(() => _cancellationHours = value),
          ),

          DsGaps.vLg,
          _Section(title: context.l10n.salonEditorSectionHome),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(
              horizontal: DsSpacing.md,
              vertical: DsSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.salonEditorHomeVisits,
                    style: context.dsText.body.tint(context.dsColors.onSurface),
                  ),
                ),
                Switch(
                  value: _homeService,
                  onChanged: (value) => setState(() => _homeService = value),
                ),
              ],
            ),
          ),
          if (_homeService) ...[
            DsGaps.vSm,
            DsInputField(
              controller: _homeFee,
              label: context.l10n.salonEditorTravelFee,
              labelAbove: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _optionalNumber,
            ),
          ],

          DsGaps.vXl,
          DsButton(
            label: salon == null
                ? context.l10n.salonEditorCreate
                : context.l10n.salonSave,
            isLoading: _saving,
            onPressed: () => unawaited(_save(publish: null)),
          ),
          if (salon != null && !salon.status.isLive) ...[
            DsGaps.vSm,
            DsButton(
              label: context.l10n.salonEditorSavePublish,
              variant: DsButtonVariant.tonal,
              isLoading: _saving,
              onPressed: () => unawaited(_save(publish: true)),
            ),
          ],
          if (salon != null && salon.status.isLive) ...[
            DsGaps.vSm,
            DsButton(
              label: context.l10n.salonEditorHide,
              variant: DsButtonVariant.ghost,
              isLoading: _saving,
              onPressed: () => unawaited(_save(publish: false)),
            ),
          ],
          DsGaps.vXl,
        ],
      ),
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? context.l10n.salonFieldRequired
      : null;

  String? _optionalNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return double.tryParse(value.trim()) == null
        ? context.l10n.salonInvalidNumber
        : null;
  }

  /// Fills the address fields from the pin, keeping whatever she typed where
  /// the map has nothing better to say.
  void _applyPin(PickedPlace? place) {
    setState(() {
      _pin = place;
      if (place == null) return;
      void fill(TextEditingController controller, String? value) {
        if (value != null && value.trim().isNotEmpty) controller.text = value;
      }

      fill(_governorate, place.governorate);
      fill(_city, place.city ?? place.governorate);
      fill(_district, place.district ?? place.neighbourhood);
      // The area has its own field here, so the street stands alone.
      final road = place.road;
      fill(
        _address,
        road == null
            ? place.addressLine
            : (place.houseNumber == null ? road : '$road ${place.houseNumber}'),
      );
    });
  }

  String? _text(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _save({required bool? publish}) async {
    if (_saving) return;
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(salonOwnerActionsProvider)
          .save(
            SalonDraft(
              name: _name.text.trim(),
              governorate: _governorate.text.trim(),
              city: _city.text.trim(),
              addressLine: _address.text.trim(),
              tagline: _text(_tagline),
              about: _text(_about),
              district: _text(_district),
              landmark: _text(_landmark),
              latitude: _pin?.latitude,
              longitude: _pin?.longitude,
              phone: _text(_phone),
              whatsapp: _text(_whatsapp),
              slotMinutes: _slotMinutes,
              leadMinutes: _leadMinutes,
              horizonDays: _horizonDays,
              concurrentCapacity: _capacity,
              cancellationHours: _cancellationHours,
              homeService: _homeService,
              // Cleared rather than kept when she turns the service off, so a
              // fee cannot survive on a salon that no longer travels.
              homeServiceFee: _homeService
                  ? double.tryParse(_homeFee.text.trim()) ?? 0
                  : 0,
              publish: publish,
            ),
          );
      if (!mounted) return;
      DsSnackbar.success(context, context.l10n.salonEditorSaved);
      if (context.canPop()) context.pop();
    } catch (_) {
      if (!mounted) return;
      DsSnackbar.error(context, context.l10n.salonSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.sm),
      child: Text(
        title,
        style: context.dsText.sectionTitle.tint(context.dsColors.onSurface),
      ),
    );
  }
}

/// A number she nudges rather than types.
///
/// Slot length and lead time are the two settings most likely to be mistyped
/// into nonsense — «١٥٠» minutes of lead time is plausible, «١٥٠٠» is a typo
/// that quietly closes her calendar — so the control refuses to leave range.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.suffix,
    required this.step,
    required this.min,
    required this.max,
    required this.help,
    required this.onChanged,
  });

  final String label;
  final int value;
  final String suffix;
  final int step;
  final int min;
  final int max;
  final String help;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.sm),
      child: SurfaceCard(
        padding: const EdgeInsets.all(DsSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: context.dsText.body.semibold.tint(c.onSurface),
                  ),
                ),
                IconButton(
                  onPressed: value <= min
                      ? null
                      : () => onChanged((value - step).clamp(min, max)),
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  color: c.primary,
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    suffix.isEmpty ? '$value' : '$value $suffix',
                    textAlign: TextAlign.center,
                    style: context.dsText.body.semibold.tint(c.onSurface),
                  ),
                ),
                IconButton(
                  onPressed: value >= max
                      ? null
                      : () => onChanged((value + step).clamp(min, max)),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  color: c.primary,
                ),
              ],
            ),
            Text(help, style: context.dsText.caption.tint(c.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
