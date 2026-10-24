# «مناسباتي»

Her calendar of days worth getting ready for — a cousin's wedding, Eid, a
graduation — and the help to get ready for each one.

She writes a day down. Ohara then shows her how long is left, a checklist
(the look, what the look is missing, the salon, the gift), and a reminder at a
week, three days and one day before. If the people she named for that day
have already seen the outfit, Ohara says so: «ما لبستيه قدّامهم».

The design rule is the same as the salons': **this is not a second
application.** The look is a `ClosetLook` from her closet, the salon is an
`Appointment` she booked through the salon flow, and the countdown is one more
notification type. An occasion only points at those things.

---

## What it is made of

### On the server

One table, `occasions`, from `20261023120000_occasions`. Purely additive.

| Column | What it holds |
| --- | --- |
| `kind` | `WEDDING`, `ENGAGEMENT`, `HENNA`, `EID`, `BIRTHDAY`, `GRADUATION`, `EVENING`, `FAMILY_VISIT`, `WORK`, `TRAVEL`, `OTHER` |
| `date` | A calendar day (`DATE`), in Damascus reckoning. Not an instant |
| `starts_at_time` | `HH:mm`, local, optional. Shown, never computed with |
| `circle` / `circle_key` | Who will be there, as she typed it, and normalised for matching |
| `look_id` | → `closet_looks`, `ON DELETE SET NULL` |
| `appointment_id` | → `appointments`, `ON DELETE SET NULL` |
| `done_steps` | Only the steps the server cannot see. Today that is `gift` |
| `reminders_enabled` | Her switch for the countdown |
| `last_reminder_stage` | The smallest countdown mark already behind her |

Code lives in `backend/src/modules/occasions/`:

| File | Responsibility |
| --- | --- |
| `occasion-plan.ts` | Pure. The kinds, local days, the countdown marks, the checklist, the reminder text, and the repeat warning. No Prisma, no clock |
| `occasions.service.ts` | Validation, ownership checks, reads and writes, and the countdown sweep |
| `occasions.serializer.ts` | The wire shape. Embeds the look and the appointment in their own features' shapes |
| `occasions.controller.ts` | `/occasions/*`, all `@SelfScoped` |
| `occasions.scheduler.ts` | The hourly countdown sweep |

### On the client

`lib/features/occasions/`, in the salon feature's shape (data, domain,
presentation; providers plus one actions object).

| Screen | Route |
| --- | --- |
| `occasions_screen.dart` | `/occasions` — upcoming and past tabs |
| `occasion_editor_screen.dart` | `/occasions/new` and `/occasions/:id/edit` |
| `occasion_detail_screen.dart` | `/occasions/:id` — the countdown's deep link |

She reaches it from the closet's top bar and from the profile menu, beside
«حجوزاتي». It has no tab: the five buyer tabs are a fixed set.

---

## Nothing in the plan is stored if it can be observed

The checklist is worked out on every read from the occasion's two links:

| Step | When it appears | Done when |
| --- | --- | --- |
| `look` | Always | A look is linked |
| `pieces` | The linked look has slots filled from the shop, not her closet | Never ticked — it goes away when the look is complete |
| `salon` | Weddings, engagements, henna, Eid, graduations, evenings | The linked appointment is `CONFIRMED` or `COMPLETED`. `PENDING` is **waiting** |
| `gift` | Weddings, engagements, Eid, birthdays, graduations | She ticks it (`PUT /occasions/:id/steps/gift`) |

A stored "salon booked" flag would go on saying "booked" after the salon
cancelled. Reading the appointment's status every time means a cancelled
booking turns the step back to "to do" with nobody having to tell the
occasion. `setStep` refuses every key but `gift` for the same reason.

A step is **urgent** when it is still to do and the day is close: pieces
within 5 days (delivery takes days), salon within 3, look and gift within 2.

The client never works any of this out. It draws `steps`, `progress`,
`next_step` and `days_left` from the payload, the way the salon screens draw
`can_cancel`.

---

## The countdown

Three marks: **7, 3 and 1** days before. Each is there for a decision she can
still make — order missing pieces, book the salon, and "tomorrow". Not more:
a countdown that rings every day gets muted.

- **Idempotent.** The mark is claimed with a conditional update on
  `last_reminder_stage` *before* the notification is sent, the same way the
  salon reminder claims `reminder_sent_at`. Concurrent and catch-up sweeps
  ring once per mark — `occasions.integration.spec.ts` runs two sweeps at the
  same time to check it.
- **No ringing about a mark she has passed.** On create, and when the date
  changes, `last_reminder_stage` is set to the mark the day is already in. A
  wedding written down five days ahead waits for the three-day mark rather than
  ringing a minute later.
- **Daytime only.** The notification is `TRANSACTIONAL` (she asked for it),
  so the platform's quiet hours do not hold it. The sweep therefore only sends
  between 10:00 and 21:00 local, and leaves the mark unclaimed outside them.
- **No shop in it.** The reminder names the next step, never a product.

| Job | Cron (UTC) | What it does |
| --- | --- | --- |
| `OccasionsScheduler.remindUpcoming` | `:07` every hour | Sends due countdown marks |

The notification type is `occasion`, on its own Android channel
`reem_occasions` («مناسباتي»), with deep link `reem://occasions/:id` and a
collapse key per occasion so "three days" replaces "a week".

---

## «ما لبستيه قدّامهم»

On the detail route (and in the answer to every write), the server compares
this occasion's look against her other occasions **with the same circle**:

- the same look, or
- a shared *statement* piece — dress, abaya, outerwear, top, bottom.

Shoes, bags and jewellery are left out: they repeat for everyone, and warnings
about them would teach her to ignore the warnings that matter.

Both directions in time count. A dress planned for the 20th that is also
planned for her sister-in-law's engagement on the 12th is worth hearing about
before either day. Two occasions with no circle are **never** assumed to share
people — one wrong warning makes her ignore the right ones.

The circle is matched on `normaliseArabic` from the stylist lexicon, so
«أهل زوجي» and «اهل زوجي» are the same people.

---

## API

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/occasions` | `scope` = `upcoming` (default, soonest first) / `past` (latest first) |
| GET | `/occasions/:id` | With `repeats` |
| POST | `/occasions` | `{ title, kind, date, starts_at_time?, location?, circle?, note?, look_id?, appointment_id?, reminders_enabled? }` |
| PATCH | `/occasions/:id` | Any of the above. `null` clears a field or unlinks the look / appointment |
| PUT | `/occasions/:id/steps/:key` | `{ done }`. Only `gift` |
| DELETE | `/occasions/:id` | The look and the booking stay |

A look must be one she built and an appointment one she booked; anything else
is a 400. Dates may be up to two years back (a past occasion is what the
repeat warning reads) and three years ahead.

---

## Testing

```bash
cd backend && npm test   # occasion-plan.spec.ts (23) + occasions.integration.spec.ts (5)
flutter test test/occasions_test.dart
```

---

## What is not built

- **Sharing an occasion** with friends, or a group plan. Deliberately absent
  for now: an occasion names who she will see and what she will wear.
- **Gift ideas from the shop.** The gift is a tick box. The lexicon already
  has `GIFT` slots per occasion, so suggestions could attach there.
- **Fixed dates for Eid.** She types the date. The Islamic calendar shifts
  every year, and a wrong pre-filled date is worse than none.
- **Logging the wear.** Marking a past occasion's look as worn does not yet
  write a `ClosetLookWear`. The repeat warning does not need it.
