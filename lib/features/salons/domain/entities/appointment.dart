import 'package:equatable/equatable.dart';

import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/salons/domain/entities/salon.dart';

/// Where a booking is in its life.
///
/// Five states, and the two that end it mean opposite things about who is
/// answerable: `cancelled` is somebody calling it off, `noShow` is the salon
/// saying she did not come. Collapsing them would lose the only fact a salon
/// needs from a booking that did not happen.
enum AppointmentStatus {
  pending,
  confirmed,
  completed,
  cancelled,
  noShow;

  static AppointmentStatus fromWire(String? value) =>
      switch (value?.toUpperCase()) {
        'CONFIRMED' => AppointmentStatus.confirmed,
        'COMPLETED' => AppointmentStatus.completed,
        'CANCELLED' => AppointmentStatus.cancelled,
        'NO_SHOW' => AppointmentStatus.noShow,
        _ => AppointmentStatus.pending,
      };

  /// Still holding a slot in the salon's calendar.
  bool get isLive =>
      this == AppointmentStatus.pending || this == AppointmentStatus.confirmed;

  bool get isClosed => !isLive;
}

/// Who called it off.
enum AppointmentActor {
  customer,
  salon,
  system;

  static AppointmentActor? fromWire(String? value) =>
      switch (value?.toUpperCase()) {
        'CUSTOMER' => AppointmentActor.customer,
        'SALON' => AppointmentActor.salon,
        'SYSTEM' => AppointmentActor.system,
        _ => null,
      };
}

/// The address a home appointment is performed at — her own, from the address
/// book she already keeps for parcels.
class AppointmentAddress extends Equatable {
  const AppointmentAddress({
    required this.id,
    required this.label,
    required this.city,
    required this.addressLine,
    this.governorate,
    this.landmark,
  });

  final String id;
  final String label;
  final String? governorate;
  final String city;
  final String addressLine;
  final String? landmark;

  String get oneLine =>
      [addressLine, landmark, city].whereType<String>().join('، ');

  @override
  List<Object?> get props => [id, label, addressLine];
}

/// One booking.
///
/// Note what it does **not** carry: a payment. An appointment is a reservation
/// paid at the chair — there is no ledger entry, no escrow and no order behind
/// it. `price` is the figure she was quoted, frozen at booking so that a salon
/// raising its prices on Tuesday does not reprice Thursday.
class Appointment extends Equatable {
  const Appointment({
    required this.id,
    required this.reference,
    required this.status,
    required this.salonId,
    required this.serviceId,
    required this.serviceName,
    required this.durationMinutes,
    required this.price,
    required this.startsAt,
    required this.endsAt,
    required this.createdAt,
    this.salon,
    this.customer,
    this.atHome = false,
    this.address,
    this.customerNote,
    this.salonNote,
    this.confirmedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelledBy,
    this.cancellationReason,
    this.cancelledLate = false,
    this.canCancel = false,
    this.canReview = false,
    this.review,
  });

  final String id;

  /// `RM-7K3Q9F` — what she reads out on the telephone. Short, unambiguous,
  /// and deliberately not a UUID.
  final String reference;

  final AppointmentStatus status;
  final String salonId;

  /// Present on her list and on the salon's queue; null on neither in practice.
  final Salon? salon;

  /// Present only on the salon's copy. Her own copy carries no customer block
  /// — she knows who she is, and her contact details do not belong in a
  /// payload she could forward.
  final User? customer;

  final String serviceId;
  final String serviceName;
  final int durationMinutes;
  final Money price;

  final DateTime startsAt;
  final DateTime endsAt;

  final bool atHome;
  final AppointmentAddress? address;

  final String? customerNote;
  final String? salonNote;

  final DateTime? confirmedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final AppointmentActor? cancelledBy;
  final String? cancellationReason;

  /// She cancelled inside the salon's notice window. Recorded rather than
  /// refused: a woman who cannot come cannot come.
  final bool cancelledLate;

  /// **Decided by the server**, so a screen can never offer a button the API
  /// would refuse. The client draws; it does not adjudicate.
  final bool canCancel;
  final bool canReview;

  final SalonReview? review;

  final DateTime createdAt;

  bool get isUpcoming => status.isLive && startsAt.isAfter(DateTime.now());

  @override
  List<Object?> get props => [id, status, startsAt, canCancel, canReview];
}
