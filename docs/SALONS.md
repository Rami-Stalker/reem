# «الصالونات والجمال»

Salons and beauty providers, their menus, and appointments booked inside Reem.

A woman finds a salon near her, reads what it does and what it charges, picks a
service, a day and an hour, and books. The salon confirms, serves her, and she
rates it. Nothing about that is paid for through Reem — see
[What an appointment is not](#what-an-appointment-is-not).

The whole point of the design is that this is **not a second application
bolted on**. A salon is owned by a `User`; the button that messages it opens
the chat that already exists; its notifications ride the notification service;
a home appointment uses the address book she keeps for parcels; and the link
she shares goes through the same share-link machinery a product does.

---

## What it is made of

### On the server

| Table | What it holds |
| --- | --- |
| `salons` | One salon. Owner, slug, address, coordinates, booking settings, counters. |
| `salon_media` | Its photographs. |
| `salon_services` | The menu: name, category, price, duration, buffer, where it is performed, whether it is a package. |
| `salon_package_items` | Which services a package contains. |
| `salon_working_hours` | One row per weekday, `0 = Sunday`, `HH:mm` strings, optional break. |
| `salon_closures` | Single dates the salon is shut — Eid, a holiday. |
| `appointments` | One booking. Frozen service name, duration and price; status; who cancelled and why. |
| `salon_reviews` | One per completed appointment, `appointment_id` unique. |

Code lives in `backend/src/modules/salons/`:

| File | Responsibility |
| --- | --- |
| `salon-hours.ts` | Pure arithmetic over local dates, weekdays and `HH:mm` windows. No Prisma, no Nest — which is why it can be tested exhaustively. |
| `salon-availability.service.ts` | Which start times are free: open windows minus breaks, minus closures, minus lead time, minus what is already booked against capacity. |
| `appointments.service.ts` | Booking, cancelling, confirming, completing, no-show, reviewing, reminders, stale closure. |
| `salons.service.ts` | The directory, a salon's page, and everything its owner writes. |
| `salons.controller.ts` | `/salons/*` and `/appointments/*`. |
| `salons.scheduler.ts` | Reminders every 10 minutes, stale closure every 30. |

### On the client

`lib/features/salons/`, in the usual three layers. The screens:

| Screen | Route | Who |
| --- | --- | --- |
| `salons_screen.dart` | `/salons` | Anyone — the directory, with search and filters |
| `salon_screen.dart` | `/salons/:id` | Anyone — the salon's page, by id **or slug** |
| `salon_booking_screen.dart` | `/salons/:id/book?service=…` | Signed in |
| `appointments_screen.dart` | `/appointments` | Signed in — «حجوزاتي» |
| `appointment_detail_screen.dart` | `/appointments/:id` | Signed in — both sides |
| `salon_workspace_screen.dart` | `/salon` | `salon:manage` |
| `salon_editor_screen.dart` | `/salon/edit` | `salon:manage` |
| `salon_services_screen.dart` | `/salon/services` | `salon:manage` |
| `salon_hours_screen.dart` | `/salon/hours` | `salon:manage` |
| `salon_queue_screen.dart` | `/salon/queue` | `salon:manage` |

`/salon` and `/salons/:id` differ by one letter on purpose, and the router
relies on the difference rather than on declaration order.

---

## The one invariant

**No two women may hold the same chair at the same hour.**

Everything else in this feature is a preference. This is the thing that, if it
breaks, makes the salon look incompetent to a customer standing in its doorway.

It cannot be a unique index. Service durations vary, so two appointments
collide by *overlapping*, not by sharing a start time; and a salon may have
four chairs, so overlap is allowed up to `concurrent_capacity`. That is a
count over a range, which no constraint expresses.

So it is a lock:

```ts
const appointment = await this.prisma.$transaction(async (tx) => {
  await tx.$queryRaw`SELECT id FROM salons WHERE id = ${salonId}::uuid FOR UPDATE`;

  const concurrent = await this.availability.concurrentAt(salonId, startsAt, endsAt, tx);
  if (concurrent >= salon.concurrentCapacity) {
    throw new ConflictException('That time has just been taken');
  }
  // …plus a per-customer overlap check, so she cannot book herself twice
  return tx.appointment.create({ /* … */ });
});
```

The row lock is on the **salon**, not on the appointment, because the thing
being protected is the salon's calendar as a whole. Two women booking different
salons never contend; two booking the same salon serialise for the duration of
one insert.

Overlap is the half-open interval test — `startsAt < end AND endsAt > start` —
so an appointment that ends at 15:00 does not collide with one that starts at
15:00. The service's `buffer_minutes` is added to `endsAt` at booking time, so
tidy-up between clients is part of the booked range rather than a second rule
applied later.

`salons.integration.spec.ts` runs this as a genuine race: four concurrent
booking attempts at capacity 1 and again at capacity 2, asserting that exactly
`capacity` survive. **The capacity-2 case fails if the lock is removed** — it
was added after the capacity-1 case was found to be vacuous, because the
pre-check alone happened to serialise it. If you touch `book()`, delete the
`FOR UPDATE` line and watch that test go red before putting it back.

---

## Availability is the server's, always

The client never computes a free slot. It asks, and it sends back the exact
instant it was offered:

```dart
BookingRequest(serviceId: …, startsAt: slot.startsAt)  // the instant, untouched
```

A second implementation in Dart would drift — a closure the client did not
know about, a lead time it rounded differently — and the symptom is a slot
offered and then refused, which reads as a broken app rather than as a busy
salon.

Times are reckoned in the salon's local day. `config.salons.utcOffsetMinutes`
is `180` (Damascus, UTC+3) and `salon-hours.ts` does the conversion in one
place. Syria does not observe daylight saving, so a fixed offset is correct
today; if that changes, that file is the only one to touch.

---

## What the client may draw

The server decides, the screen renders:

```ts
can_cancel: status === 'PENDING' || status === 'CONFIRMED',
can_review: status === 'COMPLETED' && !review,
```

A client that adjudicated would eventually offer a button the API refuses. The
detail screen reads these two booleans and nothing else — including for the
question of *which side is looking at it*, which it answers from whether the
payload carries a `customer` block. `serializePublicUser` strips the phone
number, so the salon writes to her through the chat rather than telephoning
her: a booking is not a reason to hand a salon a woman's mobile.

---

## Statuses

```
PENDING ──confirm──▶ CONFIRMED ──complete──▶ COMPLETED ──▶ review
   │                     │
   └──────cancel─────────┴──▶ CANCELLED          CONFIRMED ──▶ NO_SHOW
```

`CANCELLED` and `NO_SHOW` are deliberately not one status: the first is
somebody calling it off, the second is the salon saying she did not come.
Collapsing them would lose the only fact a salon needs from a booking that did
not happen.

Cancelling inside the salon's notice window is **recorded, not refused** —
`cancelled_late` is set and the screen says so before she confirms. A woman who
cannot come cannot come.

---

## The two scheduled jobs

Both are idempotent, because Render Free sleeps and runs catch-up passes.

| Job | Cron | What it does |
| --- | --- | --- |
| `salons.remindUpcoming` | every 10 min | Notifies appointments starting within `reminderLeadMinutes` (12h). |
| `salons.closeStale` | every 30 min | Auto-completes confirmed appointments `autoCompleteAfterHours` (24h) past their end, and cancels pending ones nobody ever confirmed. |

The reminder claims its work with a conditional update that sets
`reminder_sent_at` **first** and acts only if the update matched a row, so two
overlapping passes cannot both send. Auto-completion is what makes `can_review`
eventually true for a salon that never presses "done" — without it, a review
would depend on the owner's diligence.

---

## How it joins the rest of Reem

| It uses | Rather than |
| --- | --- |
| `User` + `salon:manage` / `appointment:book` permissions | A new `UserRole`, which would have meant touching the guards, the permission matrix, the admin console and the client navigation map |
| The existing chat (`ChatStartRequest.peer`) | A salon inbox |
| `NotificationsService.dispatch` + the `reem_appointments` channel | A salon notification system |
| The address book (`AddressEntity`) for home service | A salon-only address form |
| `ExchangeRateService` for the SYP mirror column | A salon pricing service |
| The share-link machinery, kind `salon` | A salon link format |
| `url_launcher` for the map | A map SDK, an API key and a billing account |

A `SELLER` holds `salon:manage`, so an account that already sells on Reem can
open a salon without an application, a review or a second sign-up. `CUSTOMER`
holds `appointment:book`. `OPERATIONS_ADMIN` holds `salon:manage` so staff can
fix a salon's details; `SUSPENDED` remains an operator's word that a salon
cannot say about itself.

---

## What an appointment is not

**It carries no money.** No ledger entry, no escrow, no commission, no order
row. `price` is the figure she was quoted, frozen at booking so a salon raising
its prices on Tuesday does not reprice Thursday, and she pays at the chair.

This is a decision, not an omission. Reem's financial kernel is double-entry
and every rule in it — escrow released on delivery, commission on a sub-order,
refunds against a payment — is about goods that ship. An appointment has no
shipment, no delivery event and no return. Putting it through the ledger would
have meant inventing all four.

If deposits are wanted later, the place to add them is a `Payment` against the
appointment and an escrow release on `COMPLETED` — not a change to any of the
above.

---

## Testing

```bash
cd backend && npm test          # 28 salon tests: 15 hours, 13 integration
flutter test test/salons_test.dart
```

`scripts/test-database-guard.js` refuses to run the integration tests against
anything but a local database. Do not work around it: these tests write real
rows and the race test writes them four at a time.

---

## What is not built

- **Media upload for salons.** `logo_url`, `cover_url` and `SalonMedia` are
  read and rendered; the owner's editor takes URLs rather than opening the
  picker. Wiring it is `DsMediaField` plus the existing upload subsystem.
- **Rescheduling.** She cancels and books again. A real reschedule is the same
  lock over two rows and is worth doing properly rather than as a cancel-plus-
  create that can lose the slot in between.
- **Package composition in the client editor.** `is_package` is settable;
  choosing which services a package contains is server-side only for now.
- **Salon-side review replies.** The endpoint and the provider method exist;
  no screen calls them yet.
