import 'package:equatable/equatable.dart';

import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/core/shared/value_objects/money.dart';

/// «الصالونات والجمال» — a salon, what it does, and when it can see her.
///
/// The domain layer is plain Dart: no Flutter, no Riverpod, no Dio. These are
/// the facts the screens reason about, and the JSON they arrive as is the data
/// layer's problem.

/// What a salon does. A closed vocabulary, because «تصفية حسب نوع الخدمة» is
/// only answerable when two salons spell "manicure" the same way. Mirrors
/// `SalonServiceCategory` on the server.
enum SalonCategory {
  hair,
  nails,
  skin,
  makeup,
  lashesBrows,
  hairRemoval,
  massageSpa,
  bridal,
  other;

  static SalonCategory fromWire(String? value) =>
      switch (value?.toUpperCase()) {
        'HAIR' => SalonCategory.hair,
        'NAILS' => SalonCategory.nails,
        'SKIN' => SalonCategory.skin,
        'MAKEUP' => SalonCategory.makeup,
        'LASHES_BROWS' => SalonCategory.lashesBrows,
        'HAIR_REMOVAL' => SalonCategory.hairRemoval,
        'MASSAGE_SPA' => SalonCategory.massageSpa,
        'BRIDAL' => SalonCategory.bridal,
        _ => SalonCategory.other,
      };

  String get wire => switch (this) {
    SalonCategory.hair => 'HAIR',
    SalonCategory.nails => 'NAILS',
    SalonCategory.skin => 'SKIN',
    SalonCategory.makeup => 'MAKEUP',
    SalonCategory.lashesBrows => 'LASHES_BROWS',
    SalonCategory.hairRemoval => 'HAIR_REMOVAL',
    SalonCategory.massageSpa => 'MASSAGE_SPA',
    SalonCategory.bridal => 'BRIDAL',
    SalonCategory.other => 'OTHER',
  };
}

/// Where a service is performed. A property of the *service*: a salon may do
/// nails at home and colour only in the chair.
enum ServiceLocation {
  inSalon,
  atHome,
  both;

  static ServiceLocation fromWire(String? value) =>
      switch (value?.toUpperCase()) {
        'AT_HOME' => ServiceLocation.atHome,
        'BOTH' => ServiceLocation.both,
        _ => ServiceLocation.inSalon,
      };

  /// Whether this service can be booked to her house.
  bool get travels =>
      this == ServiceLocation.atHome || this == ServiceLocation.both;

  /// Whether it can be booked at the salon.
  bool get inChair =>
      this == ServiceLocation.inSalon || this == ServiceLocation.both;
}

/// Whether the directory can see it. `SUSPENDED` is an operator's word — a
/// salon can move itself between draft and active, and no further.
enum SalonStatus {
  draft,
  active,
  suspended;

  static SalonStatus fromWire(String? value) => switch (value?.toUpperCase()) {
    'ACTIVE' => SalonStatus.active,
    'SUSPENDED' => SalonStatus.suspended,
    _ => SalonStatus.draft,
  };

  bool get isLive => this == SalonStatus.active;
}

class SalonService extends Equatable {
  const SalonService({
    required this.id,
    required this.salonId,
    required this.name,
    required this.category,
    required this.price,
    required this.durationMinutes,
    this.description,
    this.compareAtPrice,
    this.hasOffer = false,
    this.bufferMinutes = 0,
    this.location = ServiceLocation.inSalon,
    this.imageUrl,
    this.isPackage = false,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String salonId;
  final String name;
  final String? description;
  final SalonCategory category;
  final Money price;

  /// The struck-through original, when the salon is running an offer.
  final Money? compareAtPrice;

  /// Decided by the server, never by the card. A compare-at at or below the
  /// asking price is a data error rather than a deal.
  final bool hasOffer;

  final int durationMinutes;
  final int bufferMinutes;
  final ServiceLocation location;
  final String? imageUrl;
  final bool isPackage;
  final bool isActive;
  final int sortOrder;

  @override
  List<Object?> get props => [id, name, price, durationMinutes, isActive];
}

/// One weekday's opening hours. `HH:mm` strings, as the salon reckons them.
class SalonHours extends Equatable {
  const SalonHours({
    required this.weekday,
    required this.opensAt,
    required this.closesAt,
    this.isClosed = false,
    this.breakStartsAt,
    this.breakEndsAt,
  });

  /// 0 = Sunday … 6 = Saturday. `DateTime.weekday % 7` produces it.
  final int weekday;
  final bool isClosed;
  final String opensAt;
  final String closesAt;
  final String? breakStartsAt;
  final String? breakEndsAt;

  bool get hasBreak => breakStartsAt != null && breakEndsAt != null;

  @override
  List<Object?> get props => [weekday, isClosed, opensAt, closesAt];
}

class SalonClosure extends Equatable {
  const SalonClosure({required this.date, this.reason});

  /// `YYYY-MM-DD`.
  final String date;
  final String? reason;

  @override
  List<Object?> get props => [date, reason];
}

class SalonMedia extends Equatable {
  const SalonMedia({required this.id, required this.url, this.blurHash});

  final String id;
  final String url;
  final String? blurHash;

  @override
  List<Object?> get props => [id, url];
}

/// A salon, as the directory and the page both read it.
///
/// One class rather than a card/detail pair: the card fields are a subset, and
/// two classes would mean two parsers and a conversion nobody remembers to
/// keep in step. The detail-only fields are simply null on a card.
class Salon extends Equatable {
  const Salon({
    required this.id,
    required this.slug,
    required this.name,
    required this.governorate,
    required this.city,
    this.status = SalonStatus.draft,
    this.tagline,
    this.about,
    this.district,
    this.addressLine,
    this.landmark,
    this.latitude,
    this.longitude,
    this.phone,
    this.whatsapp,
    this.logoUrl,
    this.coverUrl,
    this.rating = 0,
    this.reviewsCount = 0,
    this.servicesCount = 0,
    this.appointmentsCount = 0,
    this.homeService = false,
    this.homeServiceFee,
    this.isFeatured = false,
    this.priceFrom,
    this.owner,
    this.slotMinutes = 30,
    this.leadMinutes = 120,
    this.horizonDays = 30,
    this.concurrentCapacity = 1,
    this.cancellationHours = 4,
    this.media = const [],
    this.services = const [],
    this.hours = const [],
    this.closures = const [],
  });

  final String id;
  final String slug;
  final String name;

  /// Only her own workspace reads this: the directory returns nothing but
  /// live salons, so on a card it is always [SalonStatus.active].
  final SalonStatus status;

  final String? tagline;
  final String? about;

  final String governorate;
  final String city;
  final String? district;
  final String? addressLine;
  final String? landmark;
  final double? latitude;
  final double? longitude;

  final String? phone;
  final String? whatsapp;
  final String? logoUrl;
  final String? coverUrl;

  final double rating;
  final int reviewsCount;
  final int servicesCount;
  final int appointmentsCount;

  final bool homeService;
  final Money? homeServiceFee;
  final bool isFeatured;

  /// The cheapest live service — «من ٢٥٬٠٠٠ ل.س» on a card.
  final Money? priceFrom;

  /// Who to message. A salon has no inbox of its own: a question about an
  /// appointment goes to the woman who runs it, through the chat that already
  /// exists.
  final User? owner;

  final int slotMinutes;
  final int leadMinutes;
  final int horizonDays;

  /// How many women the salon can serve at the same hour — one chair, or four.
  final int concurrentCapacity;

  final int cancellationHours;

  final List<SalonMedia> media;
  final List<SalonService> services;
  final List<SalonHours> hours;
  final List<SalonClosure> closures;

  /// «دمشق · المزة» — what a card prints under the name.
  String get area => district == null || district!.isEmpty
      ? '$governorate · $city'
      : '$city · $district';

  /// The written address, for the map link and for reading aloud.
  String get fullAddress => [
    if (addressLine != null && addressLine!.isNotEmpty) addressLine,
    if (landmark != null && landmark!.isNotEmpty) landmark,
    city,
    governorate,
  ].whereType<String>().join('، ');

  /// True when the salon has dropped a pin. Without one the map link falls
  /// back to searching the written address, which still works.
  bool get hasCoordinates => latitude != null && longitude != null;

  bool get hasBeenReviewed => reviewsCount > 0;

  /// The categories this salon actually offers — what its page lists as tabs.
  List<SalonCategory> get categories {
    final seen = <SalonCategory>[];
    for (final service in services) {
      if (!seen.contains(service.category)) seen.add(service.category);
    }
    return seen;
  }

  @override
  List<Object?> get props => [id, name, rating, servicesCount, services.length];
}

/// One free start time, as the server offered it.
///
/// Carries the instant as well as the label, and the booking sends the instant
/// back: she books the slot she was *offered* rather than one the client
/// re-derived, which is what keeps the day view and the booking rule from ever
/// disagreeing.
class SalonSlot extends Equatable {
  const SalonSlot({
    required this.time,
    required this.startsAt,
    required this.endsAt,
  });

  /// `18:00`, in the salon's own reckoning.
  final String time;
  final DateTime startsAt;
  final DateTime endsAt;

  @override
  List<Object?> get props => [startsAt, endsAt];
}

/// How many free slots a day has — the day strip on the booking screen.
class SalonOpenDay extends Equatable {
  const SalonOpenDay({required this.date, required this.slots});

  /// `YYYY-MM-DD`.
  final String date;
  final int slots;

  bool get isOpen => slots > 0;

  @override
  List<Object?> get props => [date, slots];
}

class SalonReview extends Equatable {
  const SalonReview({
    required this.id,
    required this.rating,
    required this.createdAt,
    this.body,
    this.user,
    this.salonReply,
    this.salonRepliedAt,
  });

  final String id;
  final int rating;
  final String? body;
  final User? user;
  final String? salonReply;
  final DateTime? salonRepliedAt;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, rating, body, salonReply];
}

/// The filter sheet's vocabulary, with live counts — so a filter that would
/// return nothing is not offered.
class SalonCategoryCount extends Equatable {
  const SalonCategoryCount({required this.category, required this.servicesCount});

  final SalonCategory category;
  final int servicesCount;

  @override
  List<Object?> get props => [category, servicesCount];
}

/// A locality the directory actually has salons in.
class SalonArea extends Equatable {
  const SalonArea({
    required this.governorate,
    required this.city,
    required this.salonsCount,
  });

  final String governorate;
  final String city;
  final int salonsCount;

  @override
  List<Object?> get props => [governorate, city, salonsCount];
}

/// What the directory is being asked for. Every field narrows; all null is the
/// whole live directory, which is what «الصالونات والجمال» opens on.
class SalonFilters extends Equatable {
  const SalonFilters({
    this.query,
    this.governorate,
    this.city,
    this.category,
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.homeServiceOnly = false,
    this.sort,
  });

  final String? query;
  final String? governorate;
  final String? city;
  final SalonCategory? category;
  final double? minPrice;
  final double? maxPrice;
  final double? minRating;
  final bool homeServiceOnly;
  final String? sort;

  bool get isEmpty =>
      (query == null || query!.isEmpty) &&
      governorate == null &&
      city == null &&
      category == null &&
      minPrice == null &&
      maxPrice == null &&
      minRating == null &&
      !homeServiceOnly;

  /// How many filters are on, for the badge on the filter button.
  int get activeCount => [
    governorate != null || city != null,
    category != null,
    minPrice != null || maxPrice != null,
    minRating != null,
    homeServiceOnly,
  ].where((on) => on).length;

  SalonFilters copyWith({
    String? query,
    String? governorate,
    String? city,
    SalonCategory? category,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    bool? homeServiceOnly,
    String? sort,
    bool clearQuery = false,
    bool clearArea = false,
    bool clearCategory = false,
    bool clearPrice = false,
    bool clearRating = false,
  }) {
    return SalonFilters(
      query: clearQuery ? null : (query ?? this.query),
      governorate: clearArea ? null : (governorate ?? this.governorate),
      city: clearArea ? null : (city ?? this.city),
      category: clearCategory ? null : (category ?? this.category),
      minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
      minRating: clearRating ? null : (minRating ?? this.minRating),
      homeServiceOnly: homeServiceOnly ?? this.homeServiceOnly,
      sort: sort ?? this.sort,
    );
  }

  Map<String, dynamic> toQuery() => {
    if (query != null && query!.isNotEmpty) 'q': query,
    if (governorate != null) 'governorate': governorate,
    if (city != null) 'city': city,
    if (category != null) 'category': category!.wire,
    if (minPrice != null) 'min_price': minPrice,
    if (maxPrice != null) 'max_price': maxPrice,
    if (minRating != null) 'min_rating': minRating,
    if (homeServiceOnly) 'home_service': true,
    if (sort != null) 'sort': sort,
  };

  @override
  List<Object?> get props => [
    query,
    governorate,
    city,
    category,
    minPrice,
    maxPrice,
    minRating,
    homeServiceOnly,
    sort,
  ];
}
