import 'package:reem/core/domain/pagination/paginated_data.dart';
import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/features/salons/data/models/salon_models.dart';
import 'package:reem/features/salons/domain/entities/appointment.dart';
import 'package:reem/features/salons/domain/entities/salon.dart';

/// What she is asking the salon for.
class BookingRequest {
  const BookingRequest({
    required this.serviceId,
    required this.startsAt,
    this.atHome = false,
    this.addressId,
    this.note,
  });

  final String serviceId;

  /// The exact instant the availability call offered, sent back untouched.
  /// She books the slot she was *shown*, rather than one the client re-derived
  /// — which is what keeps the day view and the booking rule from disagreeing.
  final DateTime startsAt;

  final bool atHome;
  final String? addressId;
  final String? note;

  Map<String, dynamic> toJson() => {
    'service_id': serviceId,
    'starts_at': startsAt.toUtc().toIso8601String(),
    if (atHome) 'at_home': true,
    if (addressId != null) 'address_id': addressId,
    if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
  };
}

/// A salon's own description of itself, from the owner's workspace.
class SalonDraft {
  const SalonDraft({
    required this.name,
    required this.governorate,
    required this.city,
    required this.addressLine,
    this.tagline,
    this.about,
    this.district,
    this.landmark,
    this.latitude,
    this.longitude,
    this.phone,
    this.whatsapp,
    this.logoUrl,
    this.coverUrl,
    this.slotMinutes,
    this.leadMinutes,
    this.horizonDays,
    this.concurrentCapacity,
    this.cancellationHours,
    this.homeService,
    this.homeServiceFee,
    this.publish,
  });

  final String name;
  final String governorate;
  final String city;
  final String addressLine;
  final String? tagline;
  final String? about;
  final String? district;
  final String? landmark;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? whatsapp;
  final String? logoUrl;
  final String? coverUrl;
  final int? slotMinutes;
  final int? leadMinutes;
  final int? horizonDays;
  final int? concurrentCapacity;
  final int? cancellationHours;
  final bool? homeService;
  final num? homeServiceFee;

  /// True moves it to ACTIVE, false back to DRAFT. Null leaves it alone.
  /// SUSPENDED is an operator's word and is not expressible here.
  final bool? publish;

  Map<String, dynamic> toJson() => {
    'name': name,
    'governorate': governorate,
    'city': city,
    'address_line': addressLine,
    if (tagline != null) 'tagline': tagline,
    if (about != null) 'about': about,
    if (district != null) 'district': district,
    if (landmark != null) 'landmark': landmark,
    'latitude': ?latitude,
    'longitude': ?longitude,
    if (phone != null) 'phone': phone,
    if (whatsapp != null) 'whatsapp': whatsapp,
    if (logoUrl != null) 'logo_url': logoUrl,
    if (coverUrl != null) 'cover_url': coverUrl,
    'slot_minutes': ?slotMinutes,
    'lead_minutes': ?leadMinutes,
    'horizon_days': ?horizonDays,
    'concurrent_capacity': ?concurrentCapacity,
    'cancellation_hours': ?cancellationHours,
    'home_service': ?homeService,
    'home_service_fee': ?homeServiceFee,
    if (publish != null) 'status': publish! ? 'ACTIVE' : 'DRAFT',
  };
}

/// One line of the menu, as the owner enters it.
class ServiceDraft {
  const ServiceDraft({
    required this.name,
    required this.category,
    required this.price,
    required this.durationMinutes,
    this.description,
    this.compareAtPrice,
    this.bufferMinutes,
    this.location,
    this.imageUrl,
    this.isPackage,
    this.packageServiceIds,
    this.isActive,
    this.sortOrder,
  });

  final String name;
  final SalonCategory category;
  final num price;
  final int durationMinutes;
  final String? description;
  final num? compareAtPrice;
  final int? bufferMinutes;
  final ServiceLocation? location;
  final String? imageUrl;
  final bool? isPackage;
  final List<String>? packageServiceIds;
  final bool? isActive;
  final int? sortOrder;

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category.wire,
    'price': price,
    'duration_minutes': durationMinutes,
    if (description != null) 'description': description,
    'compare_at_price': ?compareAtPrice,
    'buffer_minutes': ?bufferMinutes,
    if (location != null)
      'location': switch (location!) {
        ServiceLocation.inSalon => 'IN_SALON',
        ServiceLocation.atHome => 'AT_HOME',
        ServiceLocation.both => 'BOTH',
      },
    if (imageUrl != null) 'image_url': imageUrl,
    'is_package': ?isPackage,
    if (packageServiceIds != null) 'package_service_ids': packageServiceIds,
    'is_active': ?isActive,
    'sort_order': ?sortOrder,
  };
}

abstract interface class SalonsRemoteDataSource {
  // ── The directory ──────────────────────────────────────────────────────
  Future<PaginatedData<Salon>> salons({
    SalonFilters filters,
    int page,
    int limit,
  });

  Future<Salon> salon(String idOrSlug);

  Future<PaginatedData<SalonReview>> reviews(String salonId, {int page});

  Future<List<SalonCategoryCount>> categories();

  Future<List<SalonArea>> areas();

  // ── The calendar ───────────────────────────────────────────────────────
  Future<List<SalonSlot>> availability(
    String salonId, {
    required String serviceId,
    required String date,
  });

  Future<List<SalonOpenDay>> openDays(
    String salonId, {
    required String serviceId,
    int days,
  });

  // ── Booking ────────────────────────────────────────────────────────────
  Future<Appointment> book(String salonId, BookingRequest request);

  Future<PaginatedData<Appointment>> appointments({String? filter, int page});

  Future<Appointment> appointment(String id);

  Future<Appointment> cancel(String id, {String? reason});

  Future<SalonReview> review(String id, {required int rating, String? body});

  // ── Owning one ─────────────────────────────────────────────────────────
  Future<Salon?> mySalon();

  Future<Salon> saveSalon(SalonDraft draft);

  Future<SalonService> saveService(String? serviceId, ServiceDraft draft);

  Future<void> deactivateService(String serviceId);

  Future<Salon?> setHours(List<SalonHours> hours);

  Future<void> addClosure(String date, {String? reason});

  Future<void> removeClosure(String date);

  Future<PaginatedData<Appointment>> queue(
    String salonId, {
    String? filter,
    String? date,
    int page,
  });

  Future<Appointment> confirm(String id, {String? note});

  Future<Appointment> complete(String id, {String? note});

  Future<Appointment> noShow(String id, {String? note});

  Future<SalonReview> replyToReview(String reviewId, String body);
}

final class SalonsRemoteDataSourceImpl extends BaseRemoteDataSource
    implements SalonsRemoteDataSource {
  const SalonsRemoteDataSourceImpl(super.dio);

  @override
  Future<PaginatedData<Salon>> salons({
    SalonFilters filters = const SalonFilters(),
    int page = 1,
    int limit = 20,
  }) {
    return getPaginated<Salon>(
      ApiEndpoints.salons,
      query: {...filters.toQuery(), 'page': page, 'limit': limit},
      itemFromJson: salonFromJson,
    );
  }

  @override
  Future<Salon> salon(String idOrSlug) =>
      getDecoded(ApiEndpoints.salon(idOrSlug), decode: salonFromJson);

  @override
  Future<PaginatedData<SalonReview>> reviews(String salonId, {int page = 1}) {
    return getPaginated<SalonReview>(
      ApiEndpoints.salonReviews(salonId),
      query: {'page': page, 'limit': 20},
      itemFromJson: salonReviewFromJson,
    );
  }

  @override
  Future<List<SalonCategoryCount>> categories() async {
    final json = await getJson(ApiEndpoints.salonCategories);
    return (json['categories'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => salonCategoryCountFromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  @override
  Future<List<SalonArea>> areas() async {
    final json = await getJson(ApiEndpoints.salonAreas);
    return (json['areas'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => salonAreaFromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  @override
  Future<List<SalonSlot>> availability(
    String salonId, {
    required String serviceId,
    required String date,
  }) async {
    final json = await getJson(
      ApiEndpoints.salonAvailability(salonId),
      query: {'service_id': serviceId, 'date': date},
    );
    return (json['slots'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => salonSlotFromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  @override
  Future<List<SalonOpenDay>> openDays(
    String salonId, {
    required String serviceId,
    int days = 7,
  }) async {
    final json = await getJson(
      ApiEndpoints.salonOpenDays(salonId),
      query: {'service_id': serviceId, 'days': days},
    );
    return (json['days'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => salonOpenDayFromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  @override
  Future<Appointment> book(String salonId, BookingRequest request) async {
    return appointmentFromJson(
      await postJson(ApiEndpoints.salonBook(salonId), body: request.toJson()),
    );
  }

  @override
  Future<PaginatedData<Appointment>> appointments({
    String? filter,
    int page = 1,
  }) {
    return getPaginated<Appointment>(
      ApiEndpoints.appointments,
      query: {'filter': ?filter, 'page': page, 'limit': 20},
      itemFromJson: appointmentFromJson,
    );
  }

  @override
  Future<Appointment> appointment(String id) =>
      getDecoded(ApiEndpoints.appointment(id), decode: appointmentFromJson);

  @override
  Future<Appointment> cancel(String id, {String? reason}) async {
    return appointmentFromJson(
      await postJson(
        ApiEndpoints.appointmentCancel(id),
        body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
      ),
    );
  }

  @override
  Future<SalonReview> review(
    String id, {
    required int rating,
    String? body,
  }) async {
    return salonReviewFromJson(
      await postJson(
        ApiEndpoints.appointmentReview(id),
        body: {
          'rating': rating,
          if (body != null && body.isNotEmpty) 'body': body,
        },
      ),
    );
  }

  // ── Owning one ─────────────────────────────────────────────────────────

  @override
  Future<Salon?> mySalon() async {
    final json = await getJson(ApiEndpoints.salonMine);
    // The endpoint answers `null` for an account with no salon yet, which is
    // most of them — and is the state the workspace's empty screen is for.
    return json.isEmpty || json['id'] == null ? null : salonFromJson(json);
  }

  @override
  Future<Salon> saveSalon(SalonDraft draft) async =>
      salonFromJson(await putJson(ApiEndpoints.salons, body: draft.toJson()));

  @override
  Future<SalonService> saveService(String? serviceId, ServiceDraft draft) async {
    final json = serviceId == null
        ? await postJson(ApiEndpoints.salonServices, body: draft.toJson())
        : await patchJson(
            ApiEndpoints.salonService(serviceId),
            body: draft.toJson(),
          );
    return salonServiceFromJson(json);
  }

  @override
  Future<void> deactivateService(String serviceId) =>
      deleteRequest(ApiEndpoints.salonService(serviceId));

  @override
  Future<Salon?> setHours(List<SalonHours> hours) async {
    final json = await putJson(
      ApiEndpoints.salonHours,
      body: {
        'days': hours
            .map(
              (day) => {
                'weekday': day.weekday,
                'is_closed': day.isClosed,
                'opens_at': day.opensAt,
                'closes_at': day.closesAt,
                if (day.breakStartsAt != null)
                  'break_starts_at': day.breakStartsAt,
                if (day.breakEndsAt != null) 'break_ends_at': day.breakEndsAt,
              },
            )
            .toList(growable: false),
      },
    );
    return json['id'] == null ? null : salonFromJson(json);
  }

  @override
  Future<void> addClosure(String date, {String? reason}) async {
    await postJson(
      ApiEndpoints.salonClosures,
      body: {'date': date, 'reason': ?reason},
    );
  }

  @override
  Future<void> removeClosure(String date) =>
      deleteRequest(ApiEndpoints.salonClosure(date));

  @override
  Future<PaginatedData<Appointment>> queue(
    String salonId, {
    String? filter,
    String? date,
    int page = 1,
  }) {
    return getPaginated<Appointment>(
      ApiEndpoints.salonQueue(salonId),
      query: {
        'filter': ?filter,
        'date': ?date,
        'page': page,
        'limit': 20,
      },
      itemFromJson: appointmentFromJson,
    );
  }

  @override
  Future<Appointment> confirm(String id, {String? note}) async =>
      appointmentFromJson(
        await postJson(
          ApiEndpoints.appointmentConfirm(id),
          body: {'note': ?note},
        ),
      );

  @override
  Future<Appointment> complete(String id, {String? note}) async =>
      appointmentFromJson(
        await postJson(
          ApiEndpoints.appointmentComplete(id),
          body: {'note': ?note},
        ),
      );

  @override
  Future<Appointment> noShow(String id, {String? note}) async =>
      appointmentFromJson(
        await postJson(
          ApiEndpoints.appointmentNoShow(id),
          body: {'note': ?note},
        ),
      );

  @override
  Future<SalonReview> replyToReview(String reviewId, String body) async =>
      salonReviewFromJson(
        await postJson(
          ApiEndpoints.salonReviewReply(reviewId),
          body: {'body': body},
        ),
      );
}
