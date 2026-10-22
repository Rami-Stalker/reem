// «الصالونات والجمال», pinned where it can silently drift.
//
// The availability rule itself is the server's and is tested there — 15 unit
// tests over the hour arithmetic and 13 integration tests over the booking
// lock, including a parameterised race that genuinely fails without it. What
// is worth pinning *here* is the client's half of the three contracts that
// cross the wire, because each one fails quietly rather than loudly:
//
//   1. the decoders, which must be total — a salon card carries none of the
//      detail fields, and a missing `status` must not read as SUSPENDED;
//   2. the filter query, whose keys are the server's parameter names;
//   3. the appointment deep link, because `reem://appointments/x` folds its
//      authority into the path and a wrong fold lands her on the 404 page.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reem/core/router/app_router_provider.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/salons/data/datasources/salons_remote_datasource.dart';
import 'package:reem/features/salons/data/models/salon_models.dart';
import 'package:reem/features/salons/domain/entities/appointment.dart';
import 'package:reem/features/salons/domain/entities/salon.dart';
import 'package:reem/features/salons/presentation/widgets/salon_labels.dart';
import 'package:reem/l10n/app_localizations.dart';

/// The salon labels are Arabic-first; the tests read them in Arabic.
final _ar = lookupAppLocalizations(const Locale('ar'));

void main() {
  group('decoding a salon', () {
    test('a directory card decodes without any of the detail fields', () {
      // What `serializeSalonCard` actually sends. Every field the page needs
      // and the card does not carry has to fall back rather than throw.
      final salon = salonFromJson({
        'id': 's-1',
        'slug': 'lamsa',
        'name': 'لمسة',
        'status': 'ACTIVE',
        'governorate': 'دمشق',
        'city': 'المزة',
        'rating': 4.5,
        'reviews_count': 12,
        'services_count': 6,
        'home_service': true,
        'is_featured': false,
        'price_from': {'amount': '25000', 'currency': 'SYP'},
      });

      expect(salon.status, SalonStatus.active);
      expect(salon.services, isEmpty);
      expect(salon.hours, isEmpty);
      // The entity's defaults, not zeroes: a booking screen reached from a
      // card must not think the salon takes bookings zero days ahead.
      expect(salon.slotMinutes, 30);
      expect(salon.horizonDays, 30);
      expect(salon.concurrentCapacity, 1);
      expect(salon.priceFrom?.format(), isNotEmpty);
    });

    test('a salon with no status reads as a draft, never as suspended', () {
      // `fromWire` defaults down rather than up. A build that meets a status
      // it does not know must not decide the salon is live.
      expect(SalonStatus.fromWire(null), SalonStatus.draft);
      expect(SalonStatus.fromWire('SOMETHING_NEW'), SalonStatus.draft);
      expect(SalonStatus.fromWire('ACTIVE').isLive, isTrue);
    });

    test('the area line prefers the district when there is one', () {
      const withDistrict = Salon(
        id: 's',
        slug: 's',
        name: 'n',
        governorate: 'دمشق',
        city: 'المزة',
        district: 'فيلات غربية',
      );
      const without = Salon(
        id: 's',
        slug: 's',
        name: 'n',
        governorate: 'دمشق',
        city: 'المزة',
      );

      expect(withDistrict.area, 'المزة · فيلات غربية');
      expect(without.area, 'دمشق · المزة');
    });

    test('a service category the client does not know reads as other', () {
      // The enum is a mirror of a Prisma enum. A server that grows a category
      // before the app does must not crash the menu.
      expect(SalonCategory.fromWire('EYELASH_TINTING'), SalonCategory.other);
      expect(SalonCategory.fromWire('lashes_brows'), SalonCategory.lashesBrows);
    });
  });

  group('decoding an appointment', () {
    Map<String, dynamic> payload({Map<String, dynamic>? extra}) => {
      'id': 'a-1',
      'reference': 'RM-7K3Q9F',
      'status': 'CONFIRMED',
      'salon_id': 's-1',
      'service_id': 'sv-1',
      'service_name': 'صبغة',
      'duration_minutes': 90,
      'price': {'amount': '40000', 'currency': 'SYP'},
      'starts_at': '2026-09-20T15:00:00.000Z',
      'ends_at': '2026-09-20T16:30:00.000Z',
      'created_at': '2026-09-17T09:00:00.000Z',
      ...?extra,
    };

    test('the customer block is absent on her own copy', () {
      // The server sends the customer only on the salon's copy — her contact
      // details do not belong in a payload she could forward. The detail
      // screen reads exactly this to tell which side is looking at it.
      final mine = appointmentFromJson(payload());
      final theirs = appointmentFromJson(
        payload(
          extra: {
            'customer': {
              'id': 'u-1',
              'name': 'ريم',
              'created_at': '2026-01-01T00:00:00.000Z',
            },
          },
        ),
      );

      expect(mine.customer, isNull);
      expect(theirs.customer?.id, 'u-1');
    });

    test('can_cancel and can_review default to false', () {
      // The client draws, it does not adjudicate. A payload that says nothing
      // must offer nothing rather than offer a button the API refuses.
      final appointment = appointmentFromJson(payload());

      expect(appointment.canCancel, isFalse);
      expect(appointment.canReview, isFalse);
    });

    test('a live appointment is one still holding a slot', () {
      expect(AppointmentStatus.pending.isLive, isTrue);
      expect(AppointmentStatus.confirmed.isLive, isTrue);
      expect(AppointmentStatus.completed.isLive, isFalse);
      expect(AppointmentStatus.cancelled.isLive, isFalse);
      expect(AppointmentStatus.noShow.isLive, isFalse);
    });

    test('an unknown status reads as pending, never as confirmed', () {
      expect(
        AppointmentStatus.fromWire('RESCHEDULED'),
        AppointmentStatus.pending,
      );
    });
  });

  group('the filter query', () {
    test('every key is the name the server reads', () {
      const filters = SalonFilters(
        query: 'صبغة',
        governorate: 'دمشق',
        city: 'المزة',
        category: SalonCategory.hair,
        minPrice: 10000,
        maxPrice: 80000,
        minRating: 4,
        homeServiceOnly: true,
        sort: 'rating',
      );

      expect(filters.toQuery(), {
        'q': 'صبغة',
        'governorate': 'دمشق',
        'city': 'المزة',
        'category': 'HAIR',
        'min_price': 10000.0,
        'max_price': 80000.0,
        'min_rating': 4.0,
        'home_service': true,
        'sort': 'rating',
      });
    });

    test('an empty query sends no key at all', () {
      // Not `q=`. An empty search term is the absence of a filter, and the
      // server's search key would fold it into a match on everything.
      expect(const SalonFilters(query: '').toQuery().containsKey('q'), isFalse);
      expect(const SalonFilters().toQuery(), isEmpty);
    });

    test('the badge counts area, category, price and rating as one each', () {
      const filters = SalonFilters(
        governorate: 'دمشق',
        city: 'المزة',
        minPrice: 1,
        maxPrice: 2,
        homeServiceOnly: true,
      );

      // Governorate and city are one choice — «دمشق · المزة» — and a range is
      // one filter, so this is three rather than five.
      expect(filters.activeCount, 3);
    });

    test('clearing a filter actually clears it', () {
      const filters = SalonFilters(
        query: 'x',
        city: 'المزة',
        category: SalonCategory.nails,
      );
      final cleared = filters.copyWith(
        clearQuery: true,
        clearArea: true,
        clearCategory: true,
      );

      // `copyWith(query: null)` cannot clear — null means "unchanged" — which
      // is why the clear flags exist at all.
      expect(cleared.query, isNull);
      expect(cleared.city, isNull);
      expect(cleared.category, isNull);
      expect(cleared.isEmpty, isTrue);
    });
  });

  group('the booking request', () {
    test('sends back the exact instant the server offered', () {
      // She books the slot she was *shown*. A client that re-derived the
      // instant from a label would eventually offer a time the booking rule
      // refuses, which reads as a broken app rather than as a busy salon.
      final request = BookingRequest(
        serviceId: 'sv-1',
        startsAt: DateTime.utc(2026, 9, 20, 15),
      );

      expect(request.toJson()['starts_at'], '2026-09-20T15:00:00.000Z');
      // Absent rather than false, so the server's own default decides.
      expect(request.toJson().containsKey('at_home'), isFalse);
    });

    test('a blank note is not sent', () {
      final request = BookingRequest(
        serviceId: 'sv-1',
        startsAt: DateTime.utc(2026, 9, 20, 15),
        note: '   ',
      );

      expect(request.toJson().containsKey('note'), isFalse);
    });
  });

  group('the Arabic labels', () {
    test('a duration reads as a woman would say it', () {
      expect(SalonLabels.duration(_ar, 45), '45 دقيقة');
      expect(SalonLabels.duration(_ar, 60), 'ساعة');
      expect(SalonLabels.duration(_ar, 90), 'ساعة ونصف');
      expect(SalonLabels.duration(_ar, 120), 'ساعتان');
      expect(SalonLabels.duration(_ar, 135), 'ساعتان و15 دقيقة');
    });

    test('weekday 0 is Sunday, matching the server column', () {
      // The whole hours editor and every `SalonHours` row depend on this
      // agreeing with `SalonWorkingHours.weekday` in Prisma.
      expect(SalonLabels.weekday(_ar, 0), 'الأحد');
      expect(SalonLabels.weekday(_ar, 5), 'الجمعة');
      expect(SalonLabels.weekday(_ar, 6), 'السبت');
    });

    test('the clock is twelve-hour, because an appointment is spoken', () {
      expect(SalonLabels.time(_ar, DateTime(2026, 9, 20, 18, 30)), '6:30 م');
      expect(SalonLabels.time(_ar, DateTime(2026, 9, 20, 9, 5)), '9:05 ص');
      expect(SalonLabels.time(_ar, DateTime(2026, 9, 20)), '12:00 ص');
      expect(SalonLabels.time(_ar, DateTime(2026, 9, 20, 12)), '12:00 م');
    });

    test('a near day is named rather than dated', () {
      final today = DateTime.now();
      expect(SalonLabels.relativeDay(_ar, today), 'اليوم');
      expect(
        SalonLabels.relativeDay(_ar, today.add(const Duration(days: 1))),
        'غداً',
      );
      // Far enough away and it becomes a date, because "after 40 days" is not
      // something anybody reads off a card.
      expect(
        SalonLabels.relativeDay(_ar, today.add(const Duration(days: 40))),
        contains(' '),
      );
    });

    test('every status and every canceller has a sentence', () {
      for (final status in AppointmentStatus.values) {
        expect(SalonLabels.status(_ar, status), isNotEmpty);
        expect(SalonLabels.statusHint(_ar, status), isNotEmpty);
      }
      for (final actor in AppointmentActor.values) {
        expect(SalonLabels.cancelledBy(_ar, actor), isNotEmpty);
      }
      // Including the one the server may simply not say.
      expect(SalonLabels.cancelledBy(_ar, null), isNotEmpty);
    });
  });

  group('the routes', () {
    test('an appointment notification opens the appointment', () {
      // `reem://appointments/a-1` — the first segment is the URI's authority,
      // not part of its path. Getting this fold wrong is what dropped a woman
      // who tapped a room invite on the 404 page, and the appointment link is
      // shaped identically.
      final path = deepLinkPath(Uri.parse('reem://appointments/a-1'));

      expect(path, '/appointments/a-1');
      expect(path, RoutePaths.appointmentOf('a-1'));
    });

    test('a shared salon link keeps its slug', () {
      // The slug is what makes the link read as a name, and the server
      // resolves a salon by id *or* slug for exactly this reason.
      expect(RoutePaths.salonOf('lamsa'), '/salons/lamsa');
      expect(
        RoutePaths.salonBookingOf('lamsa', 'sv-1'),
        '/salons/lamsa/book?service=sv-1',
      );
    });

    test('the owner workspace and the customer page are different paths', () {
      // `/salon` and `/salons/:id`. One letter apart on purpose, and the
      // router relies on the difference rather than on declaration order.
      expect(RoutePaths.salonWorkspace, '/salon');
      expect(RoutePaths.salon, '/salons/:id');
      expect(RoutePaths.salonWorkspace, isNot(RoutePaths.salons));
    });
  });
}
