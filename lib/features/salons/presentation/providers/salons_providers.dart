import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:ohara/core/domain/pagination/paginated_data.dart';
import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/salons/data/datasources/salons_remote_datasource.dart';
import 'package:ohara/features/salons/domain/entities/appointment.dart';
import 'package:ohara/features/salons/domain/entities/salon.dart';

/// «الصالونات والجمال», wired.
///
/// Riverpod throughout, matching the rest of the app: `FutureProvider` for a
/// read that is simply a read, a `StateNotifier` for the directory because it
/// pages and filters, and `autoDispose` everywhere so a screen she has left
/// stops holding a list of salons and their photographs.

final salonsDataSourceProvider = Provider<SalonsRemoteDataSource>(
  (ref) => SalonsRemoteDataSourceImpl(ref.watch(dioProvider)),
);

// ── The directory ───────────────────────────────────────────────────────────

class SalonDirectoryState {
  const SalonDirectoryState({
    this.salons = const [],
    this.filters = const SalonFilters(),
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.error,
    this.page = 1,
  });

  final List<Salon> salons;
  final SalonFilters filters;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final int page;

  bool get isEmpty => !isLoading && salons.isEmpty && error == null;

  SalonDirectoryState copyWith({
    List<Salon>? salons,
    SalonFilters? filters,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    int? page,
    bool clearError = false,
  }) {
    return SalonDirectoryState(
      salons: salons ?? this.salons,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      page: page ?? this.page,
    );
  }
}

class SalonDirectoryNotifier extends StateNotifier<SalonDirectoryState> {
  SalonDirectoryNotifier(this._api) : super(const SalonDirectoryState());

  final SalonsRemoteDataSource _api;

  /// Bumped on every filter change, so a slow page-one response for the *old*
  /// filters cannot land on top of the new ones. Without it, typing quickly
  /// into the search field shows results for a word she has already deleted.
  int _generation = 0;

  Future<void> load({SalonFilters? filters}) async {
    final generation = ++_generation;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      filters: filters ?? state.filters,
      page: 1,
    );
    try {
      final page = await _api.salons(filters: state.filters, page: 1);
      if (generation != _generation) return;
      state = state.copyWith(
        salons: page.items,
        isLoading: false,
        hasMore: page.hasNextPage,
        page: 1,
      );
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    final generation = _generation;
    state = state.copyWith(isLoadingMore: true);
    try {
      final next = await _api.salons(
        filters: state.filters,
        page: state.page + 1,
      );
      if (generation != _generation) return;
      state = state.copyWith(
        salons: [...state.salons, ...next.items],
        isLoadingMore: false,
        hasMore: next.hasNextPage,
        page: state.page + 1,
      );
    } catch (_) {
      if (generation != _generation) return;
      // A failed *next* page is not an error state — she still has the ones
      // above it, and scrolling again retries.
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> applyFilters(SalonFilters filters) => load(filters: filters);

  Future<void> search(String query) =>
      load(filters: state.filters.copyWith(query: query, clearQuery: query.isEmpty));

  Future<void> clearFilters() => load(filters: const SalonFilters());
}

final salonDirectoryProvider =
    StateNotifierProvider.autoDispose<
      SalonDirectoryNotifier,
      SalonDirectoryState
    >((ref) {
      return SalonDirectoryNotifier(ref.watch(salonsDataSourceProvider))..load();
    });

/// The filter sheet's vocabulary, with live counts — so a filter that would
/// return nothing is not offered.
final salonCategoriesProvider =
    FutureProvider.autoDispose<List<SalonCategoryCount>>(
      (ref) => ref.watch(salonsDataSourceProvider).categories(),
    );

final salonAreasProvider = FutureProvider.autoDispose<List<SalonArea>>(
  (ref) => ref.watch(salonsDataSourceProvider).areas(),
);

/// One salon's page. Keyed by id **or slug**, which is what a shared link
/// carries.
final salonProvider = FutureProvider.autoDispose.family<Salon, String>(
  (ref, idOrSlug) => ref.watch(salonsDataSourceProvider).salon(idOrSlug),
);

final salonReviewsProvider = FutureProvider.autoDispose
    .family<PaginatedData<SalonReview>, String>(
      (ref, salonId) => ref.watch(salonsDataSourceProvider).reviews(salonId),
    );

// ── The calendar ────────────────────────────────────────────────────────────

/// What a day picker is asking about: one salon, one service, one date.
class AvailabilityQuery {
  const AvailabilityQuery({
    required this.salonId,
    required this.serviceId,
    required this.date,
  });

  final String salonId;
  final String serviceId;

  /// `YYYY-MM-DD`, in the salon's own reckoning.
  final String date;

  @override
  bool operator ==(Object other) =>
      other is AvailabilityQuery &&
      other.salonId == salonId &&
      other.serviceId == serviceId &&
      other.date == date;

  @override
  int get hashCode => Object.hash(salonId, serviceId, date);
}

/// The free times, straight from the server.
///
/// Never computed on the client. The availability rule is the salon's — its
/// hours, its closures, its capacity, its lead time — and a second
/// implementation here would eventually offer a slot the booking then refuses,
/// which reads as a broken app rather than as a busy salon.
final salonAvailabilityProvider = FutureProvider.autoDispose
    .family<List<SalonSlot>, AvailabilityQuery>(
      (ref, query) => ref
          .watch(salonsDataSourceProvider)
          .availability(
            query.salonId,
            serviceId: query.serviceId,
            date: query.date,
          ),
    );

class OpenDaysQuery {
  const OpenDaysQuery({required this.salonId, required this.serviceId});

  final String salonId;
  final String serviceId;

  @override
  bool operator ==(Object other) =>
      other is OpenDaysQuery &&
      other.salonId == salonId &&
      other.serviceId == serviceId;

  @override
  int get hashCode => Object.hash(salonId, serviceId);
}

final salonOpenDaysProvider = FutureProvider.autoDispose
    .family<List<SalonOpenDay>, OpenDaysQuery>(
      (ref, query) => ref
          .watch(salonsDataSourceProvider)
          .openDays(query.salonId, serviceId: query.serviceId),
    );

// ── Her bookings ────────────────────────────────────────────────────────────

/// «حجوزاتي», split the way she thinks about them rather than by status.
final myAppointmentsProvider = FutureProvider.autoDispose
    .family<PaginatedData<Appointment>, String>(
      (ref, filter) {
        // Rebuilt when the account changes: a booking is a fact about one
        // woman, and the previous account's Thursday must not linger.
        ref.watch(authNotifierProvider.select((s) => s.user?.id));
        return ref
            .watch(salonsDataSourceProvider)
            .appointments(filter: filter);
      },
    );

final appointmentProvider = FutureProvider.autoDispose
    .family<Appointment, String>(
      (ref, id) => ref.watch(salonsDataSourceProvider).appointment(id),
    );

/// Everything that writes to a booking, in one place.
///
/// A notifier rather than loose calls so that every write invalidates the same
/// set of reads: her list, that booking, and — when the salon acts — its queue.
/// Forgetting one of those is how a cancelled appointment stays on screen.
class AppointmentActions {
  AppointmentActions(this._ref);

  final Ref _ref;

  SalonsRemoteDataSource get _api => _ref.read(salonsDataSourceProvider);

  Future<Appointment> book(String salonId, BookingRequest request) async {
    final appointment = await _api.book(salonId, request);
    _invalidateLists();
    return appointment;
  }

  Future<Appointment> cancel(String id, {String? reason}) async {
    final appointment = await _api.cancel(id, reason: reason);
    _invalidateLists();
    _ref.invalidate(appointmentProvider(id));
    return appointment;
  }

  Future<SalonReview> review(
    String id, {
    required int rating,
    String? body,
  }) async {
    final review = await _api.review(id, rating: rating, body: body);
    _invalidateLists();
    _ref.invalidate(appointmentProvider(id));
    return review;
  }

  Future<Appointment> confirm(String id, {String? note}) =>
      _salonAction(id, () => _api.confirm(id, note: note));

  Future<Appointment> complete(String id, {String? note}) =>
      _salonAction(id, () => _api.complete(id, note: note));

  Future<Appointment> noShow(String id, {String? note}) =>
      _salonAction(id, () => _api.noShow(id, note: note));

  Future<Appointment> _salonAction(
    String id,
    Future<Appointment> Function() action,
  ) async {
    final appointment = await action();
    _ref.invalidate(appointmentProvider(id));
    _ref.invalidate(salonQueueProvider);
    _invalidateLists();
    return appointment;
  }

  void _invalidateLists() {
    _ref.invalidate(myAppointmentsProvider);
  }
}

final appointmentActionsProvider = Provider<AppointmentActions>(
  AppointmentActions.new,
);

// ── Owning a salon ──────────────────────────────────────────────────────────

/// Her salon, or null. The workspace asks this before drawing anything, and
/// null is the normal answer for most accounts — it is the state the "open a
/// salon" screen exists for, not an error.
final mySalonProvider = FutureProvider.autoDispose<Salon?>((ref) {
  ref.watch(authNotifierProvider.select((s) => s.user?.id));
  return ref.watch(salonsDataSourceProvider).mySalon();
});

/// What the salon has coming. `filter` is `upcoming`, `past` or a status.
final salonQueueProvider = FutureProvider.autoDispose
    .family<PaginatedData<Appointment>, ({String salonId, String filter})>(
      (ref, key) => ref
          .watch(salonsDataSourceProvider)
          .queue(key.salonId, filter: key.filter),
    );

/// The owner's writes. Separate from [AppointmentActions] because these change
/// the salon rather than a booking, and they invalidate a different read.
class SalonOwnerActions {
  SalonOwnerActions(this._ref);

  final Ref _ref;

  SalonsRemoteDataSource get _api => _ref.read(salonsDataSourceProvider);

  Future<Salon> save(SalonDraft draft) async {
    final salon = await _api.saveSalon(draft);
    _ref.invalidate(mySalonProvider);
    return salon;
  }

  Future<void> saveService(String? serviceId, ServiceDraft draft) async {
    await _api.saveService(serviceId, draft);
    _ref.invalidate(mySalonProvider);
  }

  Future<void> deactivateService(String serviceId) async {
    await _api.deactivateService(serviceId);
    _ref.invalidate(mySalonProvider);
  }

  Future<void> setHours(List<SalonHours> hours) async {
    await _api.setHours(hours);
    _ref.invalidate(mySalonProvider);
  }

  Future<void> addClosure(String date, {String? reason}) async {
    await _api.addClosure(date, reason: reason);
    _ref.invalidate(mySalonProvider);
  }

  Future<void> removeClosure(String date) async {
    await _api.removeClosure(date);
    _ref.invalidate(mySalonProvider);
  }

  Future<SalonReview> replyToReview(String reviewId, String body) =>
      _api.replyToReview(reviewId, body);
}

final salonOwnerActionsProvider = Provider<SalonOwnerActions>(
  SalonOwnerActions.new,
);
