import 'package:ohara/core/shared/models/user_model.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/salons/domain/entities/appointment.dart';
import 'package:ohara/features/salons/domain/entities/salon.dart';

/// Wire decoding for «الصالونات والجمال».
///
/// Free functions rather than model subclasses, matching the rest of the app.
/// Every decoder is total — a missing field yields the empty value rather than
/// throwing — because a directory is a list, and one malformed salon should
/// cost one card rather than the whole page.

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const [];

int _int(Object? value) => switch (value) {
  final num n => n.toInt(),
  final String s => int.tryParse(s) ?? 0,
  _ => 0,
};

double _double(Object? value) => switch (value) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s) ?? 0,
  _ => 0,
};

bool _bool(Object? value) => value == true || value == 'true';

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

String _string(Object? value) => value?.toString() ?? '';

// ── Salon ───────────────────────────────────────────────────────────────

SalonService salonServiceFromJson(Map<String, dynamic> json) => SalonService(
  id: _string(json['id']),
  salonId: _string(json['salon_id']),
  name: _string(json['name']),
  description: json['description'] as String?,
  category: SalonCategory.fromWire(json['category'] as String?),
  price: Money.fromJson(json['price']),
  compareAtPrice: Money.tryFromJson(json['compare_at_price']),
  hasOffer: _bool(json['has_offer']),
  durationMinutes: _int(json['duration_minutes']),
  bufferMinutes: _int(json['buffer_minutes']),
  location: ServiceLocation.fromWire(json['location'] as String?),
  imageUrl: json['image_url'] as String?,
  isPackage: _bool(json['is_package']),
  // Absent on the customer's copy, where the server has already filtered the
  // menu to what is live — so the honest default is "yes".
  isActive: json['is_active'] == null ? true : _bool(json['is_active']),
  sortOrder: _int(json['sort_order']),
);

SalonHours salonHoursFromJson(Map<String, dynamic> json) => SalonHours(
  weekday: _int(json['weekday']),
  isClosed: _bool(json['is_closed']),
  opensAt: _string(json['opens_at']),
  closesAt: _string(json['closes_at']),
  breakStartsAt: json['break_starts_at'] as String?,
  breakEndsAt: json['break_ends_at'] as String?,
);

SalonMedia salonMediaFromJson(Map<String, dynamic> json) => SalonMedia(
  id: _string(json['id']),
  url: _string(json['url']),
  blurHash: json['blur_hash'] as String?,
);

Salon salonFromJson(Map<String, dynamic> json) => Salon(
  id: _string(json['id']),
  slug: _string(json['slug']),
  name: _string(json['name']),
  status: SalonStatus.fromWire(json['status'] as String?),
  tagline: json['tagline'] as String?,
  about: json['about'] as String?,
  governorate: _string(json['governorate']),
  city: _string(json['city']),
  district: json['district'] as String?,
  addressLine: json['address_line'] as String?,
  landmark: json['landmark'] as String?,
  latitude: json['latitude'] == null ? null : _double(json['latitude']),
  longitude: json['longitude'] == null ? null : _double(json['longitude']),
  phone: json['phone'] as String?,
  whatsapp: json['whatsapp'] as String?,
  logoUrl: json['logo_url'] as String?,
  coverUrl: json['cover_url'] as String?,
  rating: _double(json['rating']),
  reviewsCount: _int(json['reviews_count']),
  servicesCount: _int(json['services_count']),
  appointmentsCount: _int(json['appointments_count']),
  homeService: _bool(json['home_service']),
  homeServiceFee: Money.tryFromJson(json['home_service_fee']),
  isFeatured: _bool(json['is_featured']),
  priceFrom: Money.tryFromJson(json['price_from']),
  owner: json['owner'] == null
      ? null
      : UserModel.fromJson(_map(json['owner'])),
  // The server's own values when present; the entity's sensible defaults on a
  // card, which carries none of them.
  slotMinutes: json['slot_minutes'] == null ? 30 : _int(json['slot_minutes']),
  leadMinutes: json['lead_minutes'] == null ? 120 : _int(json['lead_minutes']),
  horizonDays: json['horizon_days'] == null ? 30 : _int(json['horizon_days']),
  concurrentCapacity:
      json['concurrent_capacity'] == null
      ? 1
      : _int(json['concurrent_capacity']),
  cancellationHours:
      json['cancellation_hours'] == null ? 4 : _int(json['cancellation_hours']),
  media: _maps(json['media']).map(salonMediaFromJson).toList(growable: false),
  services: _maps(json['services'])
      .map(salonServiceFromJson)
      .toList(growable: false),
  hours: _maps(json['hours']).map(salonHoursFromJson).toList(growable: false),
  closures: _maps(json['closures'])
      .map(
        (closure) => SalonClosure(
          date: _string(closure['date']),
          reason: closure['reason'] as String?,
        ),
      )
      .toList(growable: false),
);

SalonSlot salonSlotFromJson(Map<String, dynamic> json) => SalonSlot(
  time: _string(json['time']),
  startsAt: _date(json['starts_at']) ?? DateTime.now(),
  endsAt: _date(json['ends_at']) ?? DateTime.now(),
);

SalonOpenDay salonOpenDayFromJson(Map<String, dynamic> json) => SalonOpenDay(
  date: _string(json['date']),
  slots: _int(json['slots']),
);

SalonReview salonReviewFromJson(Map<String, dynamic> json) => SalonReview(
  id: _string(json['id']),
  rating: _int(json['rating']),
  body: json['body'] as String?,
  user: json['user'] == null ? null : UserModel.fromJson(_map(json['user'])),
  salonReply: json['salon_reply'] as String?,
  salonRepliedAt: _date(json['salon_replied_at']),
  createdAt: _date(json['created_at']) ?? DateTime.now(),
);

SalonCategoryCount salonCategoryCountFromJson(Map<String, dynamic> json) =>
    SalonCategoryCount(
      category: SalonCategory.fromWire(json['key'] as String?),
      servicesCount: _int(json['services_count']),
    );

SalonArea salonAreaFromJson(Map<String, dynamic> json) => SalonArea(
  governorate: _string(json['governorate']),
  city: _string(json['city']),
  salonsCount: _int(json['salons_count']),
);

// ── Appointment ─────────────────────────────────────────────────────────

AppointmentAddress appointmentAddressFromJson(Map<String, dynamic> json) =>
    AppointmentAddress(
      id: _string(json['id']),
      label: _string(json['label']),
      governorate: json['governorate'] as String?,
      city: _string(json['city']),
      addressLine: _string(json['address_line']),
      landmark: json['landmark'] as String?,
    );

Appointment appointmentFromJson(Map<String, dynamic> json) => Appointment(
  id: _string(json['id']),
  reference: _string(json['reference']),
  status: AppointmentStatus.fromWire(json['status'] as String?),
  salonId: _string(json['salon_id']),
  salon: json['salon'] == null ? null : salonFromJson(_map(json['salon'])),
  customer: json['customer'] == null
      ? null
      : UserModel.fromJson(_map(json['customer'])),
  serviceId: _string(json['service_id']),
  serviceName: _string(json['service_name']),
  durationMinutes: _int(json['duration_minutes']),
  price: Money.fromJson(json['price']),
  startsAt: _date(json['starts_at']) ?? DateTime.now(),
  endsAt: _date(json['ends_at']) ?? DateTime.now(),
  atHome: _bool(json['at_home']),
  address: json['address'] == null
      ? null
      : appointmentAddressFromJson(_map(json['address'])),
  customerNote: json['customer_note'] as String?,
  salonNote: json['salon_note'] as String?,
  confirmedAt: _date(json['confirmed_at']),
  completedAt: _date(json['completed_at']),
  cancelledAt: _date(json['cancelled_at']),
  cancelledBy: AppointmentActor.fromWire(json['cancelled_by'] as String?),
  cancellationReason: json['cancellation_reason'] as String?,
  cancelledLate: _bool(json['cancelled_late']),
  // The server decides what she may do, so a screen can never offer a button
  // the API would refuse.
  canCancel: _bool(json['can_cancel']),
  canReview: _bool(json['can_review']),
  review: json['review'] == null
      ? null
      : salonReviewFromJson(_map(json['review'])),
  createdAt: _date(json['created_at']) ?? DateTime.now(),
);
