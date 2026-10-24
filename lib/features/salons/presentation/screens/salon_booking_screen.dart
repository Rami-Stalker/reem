import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/platform/app_haptics.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/auth/presentation/widgets/auth_prompt_sheet.dart';
import 'package:ohara/features/salons/data/datasources/salons_remote_datasource.dart';
import 'package:ohara/features/salons/domain/entities/salon.dart';
import 'package:ohara/features/salons/presentation/providers/salons_providers.dart';
import 'package:ohara/features/salons/presentation/widgets/salon_labels.dart';
import 'package:ohara/features/settings/domain/entities/address_entity.dart';
import 'package:ohara/features/settings/presentation/providers/address_book_provider.dart';

/// Choosing a day and an hour.
///
/// ## The one rule this screen must not break
///
/// **It never computes availability.** The free times come from the server —
/// its hours, its closures, its capacity, its lead time — and the instant the
/// server offered is sent back untouched when she books. A client that
/// re-derived the grid would eventually offer a slot the booking then refuses,
/// which reads as a broken app rather than as a busy salon.
///
/// Refusal is still handled, because between showing her a time and her
/// tapping it somebody else may have taken it. That is not a bug; it is a busy
/// salon, and the screen says so and reloads the day.
class SalonBookingScreen extends ConsumerStatefulWidget {
  const SalonBookingScreen({
    super.key,
    required this.salonId,
    required this.serviceId,
  });

  final String salonId;
  final String serviceId;

  @override
  ConsumerState<SalonBookingScreen> createState() => _SalonBookingScreenState();
}

class _SalonBookingScreenState extends ConsumerState<SalonBookingScreen> {
  String? _date;
  SalonSlot? _slot;
  bool _atHome = false;
  String? _addressId;
  final _note = TextEditingController();
  bool _submitting = false;

  // Named intentions rather than a handle on `setState`. Children take values
  // and callbacks; reaching into another widget's state is how a screen ends
  // up with two places that decide the same thing.
  void _selectDate(String date) => setState(() {
    _date = date;
    // A time chosen on another day is not a time on this one.
    _slot = null;
  });

  void _selectSlot(SalonSlot slot) => setState(() => _slot = slot);

  void _setAtHome(bool value) => setState(() {
    _atHome = value;
    if (!value) _addressId = null;
  });

  void _selectAddress(String id) => setState(() => _addressId = id);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final salonAsync = ref.watch(salonProvider(widget.salonId));

    return Scaffold(
      backgroundColor: c.background,
      appBar: OharaAppBar(title: context.l10n.salonBookYourAppointment),
      body: salonAsync.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: context.l10n.salonCalendarLoadError,
          onRetry: () => ref.invalidate(salonProvider(widget.salonId)),
        ),
        data: (salon) {
          final service = salon.services
              .where((s) => s.id == widget.serviceId)
              .firstOrNull;
          if (service == null) {
            return DsEmptyState(
              icon: Icons.event_busy_outlined,
              title: context.l10n.salonServiceUnavailable,
              message: context.l10n.salonPickAnotherService,
            );
          }
          return _Form(
            salon: salon,
            service: service,
            date: _date,
            slot: _slot,
            atHome: _atHome,
            addressId: _addressId,
            note: _note,
            submitting: _submitting,
            onSelectDate: _selectDate,
            onSelectSlot: _selectSlot,
            onSetAtHome: _setAtHome,
            onSelectAddress: _selectAddress,
            onBook: () => unawaited(_book(salon, service)),
          );
        },
      ),
    );
  }

  Future<void> _book(Salon salon, SalonService service) async {
    final slot = _slot;
    if (slot == null || _submitting) return;

    // Asked for at the moment it starts to mean something, rather than at the
    // door of the directory: an appointment is a promise between two named
    // people, and browsing is not.
    final signedIn = await requireAuthenticatedUser(
      context,
      ref,
      title: context.l10n.salonSignInToBook,
      message: context.l10n.salonSignInToBookBody,
      from: RoutePaths.salonBookingOf(salon.id, service.id),
    );
    if (!signedIn || !mounted) return;

    if (_atHome && _addressId == null) {
      DsSnackbar.error(context, context.l10n.salonPickAddress);
      return;
    }

    setState(() => _submitting = true);
    try {
      final appointment = await ref
          .read(appointmentActionsProvider)
          .book(
            salon.id,
            BookingRequest(
              serviceId: service.id,
              startsAt: slot.startsAt,
              atHome: _atHome,
              addressId: _atHome ? _addressId : null,
              note: _note.text,
            ),
          );
      if (!mounted) return;
      AppHaptics.confirm();
      // Replaced rather than pushed: going "back" from a booking she has just
      // made should not return her to a slot picker showing a time that is now
      // hers.
      context.pushReplacement(RoutePaths.appointmentOf(appointment.id));
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      // Somebody took it between the day view and her tap. A busy salon, not a
      // broken app — so the day is reloaded and she picks again.
      DsSnackbar.error(context, context.l10n.salonBookingFailed);
      setState(() => _slot = null);
      if (_date != null) {
        ref.invalidate(
          salonAvailabilityProvider(
            AvailabilityQuery(
              salonId: salon.id,
              serviceId: service.id,
              date: _date!,
            ),
          ),
        );
      }
    }
  }
}

class _Form extends ConsumerWidget {
  const _Form({
    required this.salon,
    required this.service,
    required this.date,
    required this.slot,
    required this.atHome,
    required this.addressId,
    required this.note,
    required this.submitting,
    required this.onSelectDate,
    required this.onSelectSlot,
    required this.onSetAtHome,
    required this.onSelectAddress,
    required this.onBook,
  });

  final Salon salon;
  final SalonService service;
  final String? date;
  final SalonSlot? slot;
  final bool atHome;
  final String? addressId;
  final TextEditingController note;
  final bool submitting;
  final ValueChanged<String> onSelectDate;
  final ValueChanged<SalonSlot> onSelectSlot;
  final ValueChanged<bool> onSetAtHome;
  final ValueChanged<String> onSelectAddress;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.dsColors;
    final days = ref.watch(
      salonOpenDaysProvider(
        OpenDaysQuery(salonId: salon.id, serviceId: service.id),
      ),
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.lg,
              DsSpacing.md,
              DsSpacing.lg,
              DsSpacing.lg,
            ),
            children: [
              _Summary(salon: salon, service: service),
              DsGaps.vLg,

              Text(
                context.l10n.salonPickDay,
                style: context.dsText.sectionTitle.tint(c.onSurface),
              ),
              DsGaps.vXs,
              days.when(
                loading: () => const SizedBox(
                  height: 76,
                  child: Center(child: DsLoadingIndicator()),
                ),
                error: (_, _) => DsErrorState(
                  message: context.l10n.salonDaysLoadError,
                  onRetry: () => ref.invalidate(
                    salonOpenDaysProvider(
                      OpenDaysQuery(salonId: salon.id, serviceId: service.id),
                    ),
                  ),
                ),
                data: (list) => _DayStrip(
                  days: list,
                  selected: date,
                  onSelect: onSelectDate,
                ),
              ),

              if (date != null) ...[
                DsGaps.vLg,
                Text(
                  context.l10n.salonPickTime,
                  style: context.dsText.sectionTitle.tint(c.onSurface),
                ),
                DsGaps.vXs,
                _Slots(
                  salon: salon,
                  service: service,
                  date: date!,
                  selected: slot,
                  onSelect: onSelectSlot,
                ),
              ],

              // «دعم الخدمات المنزلية» — offered only where both the salon and
              // the service allow it, so she is never shown a choice that the
              // booking would refuse.
              if (salon.homeService && service.location.travels) ...[
                DsGaps.vLg,
                _HomeServiceSection(
                  salon: salon,
                  atHome: atHome,
                  addressId: addressId,
                  onSetAtHome: onSetAtHome,
                  onSelectAddress: onSelectAddress,
                ),
              ],

              DsGaps.vLg,
              DsInputField(
                controller: note,
                label: context.l10n.salonNoteForSalon,
                hint: context.l10n.salonNoteForSalonHint,
                maxLines: 3,
                minLines: 2,
              ),
            ],
          ),
        ),
        _BookBar(
          salon: salon,
          slot: slot,
          submitting: submitting,
          onBook: onBook,
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.salon, required this.service});

  final Salon salon;
  final SalonService service;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return SurfaceCard(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            service.name,
            style: context.dsText.tileTitle.semibold.tint(c.onSurface),
          ),
          DsGaps.vXxxs,
          Text(
            salon.name,
            style: context.dsText.cardSubtitle.tint(c.onSurfaceVariant),
          ),
          DsGaps.vXs,
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 15, color: c.onSurfaceVariant),
              DsGaps.hXxs,
              Text(
                SalonLabels.duration(context.l10n, service.durationMinutes),
                style: context.dsText.caption.tint(c.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                service.price.format(),
                style: DsTypography.price(
                  c.price,
                  size: DsTypography.bodyMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.days,
    required this.selected,
    required this.onSelect,
  });

  final List<SalonOpenDay> days;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    if (days.every((day) => !day.isOpen)) {
      return Text(
        context.l10n.salonNoSlotsWeek,
        style: context.dsText.cardSubtitle.tint(c.onSurfaceVariant),
      );
    }

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.xs),
        itemBuilder: (context, index) {
          final day = days[index];
          final date = DateTime.tryParse(day.date) ?? DateTime.now();
          final isSelected = day.date == selected;
          // A closed day is shown and disabled rather than hidden: a gap in a
          // strip of dates reads as a loading bug.
          return Opacity(
            opacity: day.isOpen ? 1 : 0.4,
            child: GestureDetector(
              onTap: day.isOpen
                  ? () {
                      AppHaptics.selection();
                      onSelect(day.date);
                    }
                  : null,
              child: Container(
                width: 76,
                padding: const EdgeInsets.symmetric(vertical: DsSpacing.sm),
                decoration: BoxDecoration(
                  color: isSelected ? c.primary : c.card,
                  borderRadius: DsRadius.borderLg,
                  border: Border.all(color: isSelected ? c.primary : c.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      SalonLabels.weekday(context.l10n, date.weekday % 7),
                      style: context.dsText.caption.tint(
                        isSelected ? c.onPrimary : c.onSurfaceVariant,
                      ),
                    ),
                    DsGaps.vXxxs,
                    Text(
                      '${date.day}',
                      style: context.dsText.tileTitle.semibold.tint(
                        isSelected ? c.onPrimary : c.onSurface,
                      ),
                    ),
                    DsGaps.vXxxs,
                    Text(
                      day.isOpen
                          ? context.l10n.salonSlotsCount(day.slots)
                          : context.l10n.salonClosed,
                      style: context.dsText.micro.tint(
                        isSelected ? c.onPrimary : c.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Slots extends ConsumerWidget {
  const _Slots({
    required this.salon,
    required this.service,
    required this.date,
    required this.selected,
    required this.onSelect,
  });

  final Salon salon;
  final SalonService service;
  final String date;
  final SalonSlot? selected;
  final ValueChanged<SalonSlot> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.dsColors;
    final query = AvailabilityQuery(
      salonId: salon.id,
      serviceId: service.id,
      date: date,
    );
    final slots = ref.watch(salonAvailabilityProvider(query));

    return slots.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: DsSpacing.md),
        child: DsLoadingIndicator(),
      ),
      error: (_, _) => DsErrorState(
        message: context.l10n.salonSlotsLoadError,
        onRetry: () => ref.invalidate(salonAvailabilityProvider(query)),
      ),
      data: (list) => list.isEmpty
          ? Text(
              context.l10n.salonNoSlotsDay,
              style: context.dsText.cardSubtitle.tint(c.onSurfaceVariant),
            )
          : Wrap(
              spacing: DsSpacing.xs,
              runSpacing: DsSpacing.xs,
              children: [
                for (final slot in list)
                  DsChip(
                    label: SalonLabels.time(
                      context.l10n,
                      slot.startsAt.toLocal(),
                    ),
                    selected: selected?.startsAt == slot.startsAt,
                    onTap: () {
                      AppHaptics.selection();
                      onSelect(slot);
                    },
                  ),
              ],
            ),
    );
  }
}

class _HomeServiceSection extends ConsumerWidget {
  const _HomeServiceSection({
    required this.salon,
    required this.atHome,
    required this.addressId,
    required this.onSetAtHome,
    required this.onSelectAddress,
  });

  final Salon salon;
  final bool atHome;
  final String? addressId;
  final ValueChanged<bool> onSetAtHome;
  final ValueChanged<String> onSelectAddress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.dsColors;
    // Her existing address book, exactly as checkout reads it.
    final addresses = ref.watch(addressBookProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.salonWantHomeService,
                    style: context.dsText.tileTitle.semibold.tint(c.onSurface),
                  ),
                  if (salon.homeServiceFee != null) ...[
                    DsGaps.vXxxs,
                    Text(
                      context.l10n.salonTravelFeeValue(
                        salon.homeServiceFee!.format(),
                      ),
                      style: context.dsText.cardSubtitle.tint(
                        c.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Switch(
              value: atHome,
              onChanged: onSetAtHome,
              activeThumbColor: c.onPrimary,
              activeTrackColor: c.primary,
              inactiveThumbColor: c.surface,
              inactiveTrackColor: c.surfaceVariant,
              trackOutlineColor: WidgetStatePropertyAll(c.border),
            ),
          ],
        ),
        if (atHome) ...[
          DsGaps.vSm,
          // Her existing address book. She types her address once, for parcels
          // and for hands.
          if (addresses.isLoading && addresses.addresses.isEmpty)
            const DsLoadingIndicator()
          else if (addresses.addresses.isEmpty)
            DsButton(
              label: context.l10n.salonAddAddress,
              icon: Icons.add_location_alt_outlined,
              variant: DsButtonVariant.tonal,
              onPressed: () => unawaited(context.push(RoutePaths.addresses)),
            )
          else
            Column(
              children: [
                for (final address in addresses.addresses)
                  _AddressChoice(
                    address: address,
                    selected: addressId == address.id,
                    onSelect: () => onSelectAddress(address.id),
                  ),
              ],
            ),
        ],
      ],
    );
  }
}

class _BookBar extends StatelessWidget {
  const _BookBar({
    required this.salon,
    required this.slot,
    required this.submitting,
    required this.onBook,
  });

  final Salon salon;
  final SalonSlot? slot;
  final bool submitting;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    // Promoted to a local: a field cannot be narrowed by a null check.
    final chosen = slot;

    return Container(
      padding: EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.sm,
        DsSpacing.lg,
        DsSpacing.sm + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chosen != null) ...[
            Text(
              SalonLabels.dateTime(context.l10n, chosen.startsAt.toLocal()),
              style: context.dsText.body.semibold.tint(c.onSurface),
            ),
            DsGaps.vXs,
          ],
          DsButton(
            label: chosen == null
                ? context.l10n.salonPickATime
                : context.l10n.salonConfirmBooking,
            isLoading: submitting,
            // Disabled until she has picked, rather than enabled and then
            // complaining: a button that does nothing is a button that lies.
            onPressed: chosen == null ? null : onBook,
          ),
          DsGaps.vXxs,
          Text(
            context.l10n.salonPayAtSalonFreeCancel(salon.cancellationHours),
            textAlign: TextAlign.center,
            style: context.dsText.micro.tint(c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// One of her saved addresses, as a choice.
///
/// A row rather than a `RadioListTile`: the tile's own padding and text styles
/// are Material's, and this app draws its own.
class _AddressChoice extends StatelessWidget {
  const _AddressChoice({
    required this.address,
    required this.selected,
    required this.onSelect,
  });

  final AddressEntity address;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return GestureDetector(
      onTap: onSelect,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DsSpacing.xs),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? c.primary : c.onSurfaceVariant,
            ),
            const SizedBox(width: DsSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    address.label,
                    style: context.dsText.body.semibold.tint(c.onSurface),
                  ),
                  Text(
                    '${address.addressLine}، ${address.city}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.caption.tint(c.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
