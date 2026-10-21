# UI consistency audit — buyer, seller and admin

A pass over every screen in the three apps, looking for two things: screens
that felt dated next to the new home, Discover and product pages, and places
where the apps disagreed with each other — in components, in spacing, and in
how they talk.

## What was found

| Area | Finding | Size |
| --- | --- | --- |
| Voice | Copy in three registers: friendly feminine standard Arabic (the client's choice, Q68/Q69), heavy Levantine colloquial («ما قدرنا نجيب…», «هلق», «شو»), and terse formal labels. Closet, Rooms, Market, Value, Seller intelligence and the Stylist were almost entirely colloquial. | ~1,000 inline strings in 22 features |
| Digits | Arabic-Indic digits (`٧ أيام`, `٣٠ ثانية`, `٪`) in 21 ARB strings and the trends charts, against the app's Western-digit rule (`arabic_numerals.dart`). | 28 |
| Locale | Status words (orders, parcels, payments, listings, rooms, market) were Arabic-only getters on domain enums, so English users saw Arabic and the localisation guard never saw them. | 9 enums |
| Loading / empty / error | 39 hand-built spinners, 13 hand-built progress bars, 21 raw snackbars, 6 ad-hoc empty and error states. | 79 sites |
| Components | `FilledButton` and `ListTile` had no theme, so they drifted per screen. | 2 |
| Glass cards | The card's shadow was painted under the translucent fill, inside the clip; its 22px offset showed as a pale band along every card's top edge. | every `DsGlassCard` |
| Drops | A drop card was a title and a row of thumbnails, with nothing about *when*. | 1 |
| Admin activity | The dashboard read a stale field and showed the raw status («APPROVED») where the time should be. | 1 |
| Spacing | Five off-grid `SizedBox(height: 2)` in policies — the only enforced design-system violations left. | 5 |

## What changed

- **One voice.** Every inline string moved to `app_ar.arb` with an English twin
  in `app_en.arb`, rewritten in friendly feminine standard Arabic, with real
  Arabic plurals (`=1/=2/few/other`) wherever a count is spoken. The 46 older
  ARB strings that were still colloquial were rewritten the same way.
- **Western digits everywhere,** including `%` instead of `٪`.
- **Labels follow the locale.** Domain enums no longer carry text. Their words
  live in presentation extensions on `AppLocalizations` (`order_labels.dart`,
  mirroring `seller_order_labels.dart`) or `labelOf(l10n)` extensions
  (`room_labels.dart`, `product_status_chip.dart`, `market_pieces.dart`).
- **One loader, one meter, one snackbar.** `DsLoadingIndicator.inline`,
  `DsMeter` and `DsSnackbar.on` replace the hand-built versions; empty and
  error states use `DsEmptyState` / `DsErrorState`.
- **Themed components.** `dsFilledButtonTheme` and `dsListTileTheme` are
  registered in `theme_factory.dart`.
- **Glass cards float cleanly.** The shadow is painted outside the card shape
  only.
- **Drops say when.** «يُفتح بعد ساعتين», «مفتوح · ينتهي بعد 3 أيام», or how
  far ahead an early-access invitation puts her, beside the starting price.
- **Clear actions.** The ambiguous «هاي» button in Rooms now reads «اختاري
  هذه»; drops are called «الإطلاقات» so they no longer read like an app version.

## What keeps it this way

`tools/architecture/check-localization.mjs` now also counts **Arabic letters
inside any literal** in presentation and design-system code, with a ceiling of
zero. Punctuation alone (`'، '`) is not counted. Data that is not copy carries
`// l10n-ignore: <reason>` on or above its line.

The three structural guards — boundaries, design system, localisation — all
reached zero, so CI no longer runs them with `continue-on-error`: a regression
fails the PR that introduces it.

## Deliberate exceptions

- `admin_record_details.dart` — a dictionary of server column names for the
  operator console. It follows the API rather than the product's voice, and is
  exempted by file in the check, with that reason.
- `language_screen.dart` — «العربية» is a language named in its own script.
- Android notification channel names (`core/notifications`) are registered at
  startup, before a locale is available.

## Server-written sentences

Reasons, care notes, missions, stylist replies, intelligence advice, room
activity and notifications are composed by the backend and shown as-is. About
170 of them were colloquial (`value.constants.ts`, `market/kernel/lifecycle.ts`,
`market-intelligence.service.ts`, `seller-intelligence/*`,
`closet.serializer.ts`, `rooms/*`, `reply-composer.ts`, `stylist-ranker.ts`,
`visual-search/*`); they now use the same friendly feminine standard Arabic,
and the stylist's language-model prompt asks for it instead of "a neutral
dialect".

Two kinds of server text were left alone on purpose:

- **Her words.** Suggestion chips and example prompts («عندي مناسبة وبدي
  فستان», «بلون تاني») are things she taps or types, and they are sent back
  to the parser.
- **Matching vocabularies.** `stylist-lexicon.ts`, `query-normalizer.ts` and
  `search/arabic.ts` read what women actually type, so they stay colloquial.

## Buyer app, verified end to end

The buyer app was run as a web build against the real API on a seeded
Postgres, and walked as the demo shopper: sign-in by code and the consent
gate, home, Discover, search, product page, bag, coupon, checkout and a
cash-on-delivery order (with and without a coupon), the order page and
cancelling, favourites and collections, closet (adding a piece with a photo,
«ماذا ألبس اليوم؟»), rooms (opening one for an occasion, proposing a piece
into it), the stylist, likes, saves, «أضيفي إلى صفحتي», following a boutique,
messaging a boutique, notifications, standing, wallet, rewards, addresses,
settings and policies. Every screen loads without an error state.

What that run found and fixed:

| Area | Problem | Fix |
| --- | --- | --- |
| Storefronts | Sellers approved after private pages were introduced kept a closed page, hiding all their posts from shoppers. | Approval opens the page; a migration opens existing verified shops. |
| Early access | New arrivals inside the members-only window were listed on home and search, but their product page answered «not found». | The visibility rule now applies to those lists too. |
| Favourites | The Collections tab failed for everyone with a list (a decimal price arrived as a string). | The model accepts both; a test pins the real payload. |
| Errors | English server messages reached Arabic screens. | Error states and snackbars show a friendly Arabic sentence instead. |
| Stories | One ring per story, so a shop appeared several times. | One ring per shop, played shop by shop. |
| Standing | A new shopper was told «جديدة» was her *next* tier, 100% done. | An unscored profile sits on the rung its score reaches. |
| Rooms | A room of suggestions read «all settled» at 0%; «add to a room» never listed its questions. | Ready needs a chosen piece; the sheet loads the room's questions. |
| Orders | The timeline and order notifications were English; the address repeated the city with Latin commas. | Timeline named from statuses; Arabic notifications; Arabic list comma. |
| Reminders | A basket reminder already sent aborted the batch inside a transaction. | The touch is recorded with skip-duplicates. |
| Copy | Remaining English counts and colloquial lines. | Localised; the guard now catches `'${n} items'`. |

Not testable in this environment: **photo search**. Its index is built by
downloading product photographs, which this sandbox cannot reach, and the
indexer is off by default (`VISUAL_SEARCH_INDEXER_ENABLED=false`) — in
production it must be switched on, or `scripts/index-visual.ts` run once.

## Seller app, verified end to end

The seller app was run the same way, signed in as the demo boutique: the
dashboard, products and the product form, the order queue and an order page,
analytics, trends, the radar, product intelligence, store health, reviews,
returns, the store page, earnings, the market, the content studio and the
composer. Two waiting orders were accepted and marked ready for the courier,
a review was answered (the reply is stored and shown under it), and the
payout card was opened.

What that run found and fixed:

| Area | Problem | Fix |
| --- | --- | --- |
| Content studio, composer | Both pages were blank: a sliver gap sat inside a list of boxes. | The box gap is used there; the design-system check now rejects `DsGaps.sliver*` inside `children:`. |
| Tab bar | A scrolling strip of 92px tiles cut the labels short and hid the fifth tab. | Five fixed tabs, icon over label. |
| Dates | Reviews, orders, returns and payouts formatted dates with a pinned `'ar'` locale: «٥ أكتوبر» beside Western prices, and Arabic months for English readers. | One `formatCalendarDate(l10n, …)`; the localisation check rejects a `DateFormat` with a pinned locale. |
| Order money | A platform-paid coupon was listed as a deduction, so the rows added up to less than her net. | The server sends the discount split by who paid it; only hers is deducted, the platform's is a note. |
| Counts | About thirty strings read «من 3 طلب», «5 يومًا», «5 تقييم», «1 products». | Arabic plural forms and English singulars; two-count lines read «مشاهدات: 12 · طلبات: 3». |
| Health advice | «ألغيتِ 1 طلب», «2 يوم». | The server says counts in Arabic: «ألغيتِ طلباً واحداً», «يومين», «5 ساعات». |
| Words from the server | «باقة Premium»; the composer offered «Post · Reel · Story»; the studio listed a row called «flash_offer». | Plan levels and content types are named in her language, with the server's name as a fallback for a type the app does not know yet. |
| Wording | The revenue card did not say its totals were all-time; the timeline said «أكّدتِ الاستلام» after she pressed «قبول الطلب». | «منذ افتتاح متجركِ»; «قبلتِ الطلب». |

Not an app defect, but worth knowing: the demo seed writes the boutique's two
paid payouts directly, without the ledger entries a real payout posts, so her
earnings statement is empty under a lifetime total of 110,200 ل.س. The real
flow posts those entries.

## Admin console, verified end to end

The console was run signed in as the super admin: the dashboard and its
briefing, content, orders, products, users, sellers, seller applications,
delivery, finance, commissions, analytics, trends, reports, moderation,
support, audit logs, system settings, Reem Value, notification campaigns and
analytics, and policies. Every screen loads without an error. A pending
seller application was approved from the console; the seller is now
verified and the decision is in the audit log.

What that run found and fixed:

| Area | Problem | Fix |
| --- | --- | --- |
| Statuses | Orders, audit severities and notification deliveries showed «Confirmed», «Info», «Sent». | Named in the shared status table. |
| Audit log | Rows were titled with action codes: `login`, `recovery_case_first_approval`, `PATCH /admin/…`. | Named; an unknown code still shows as itself, and the request line stays in the details. |
| Reports, policies, Value | `sales`, `customer-terms`, «known», «circle» inside Arabic sentences. | Report types, policy titles and rung names. |
| Commissions | Rates showed as basis points («1000»). | «10%». |
| Analytics | The chart's axis dates read `2026-10-19`. | «19 أكتوبر». |
| Counts | «قبل 3 ساعة», «قبل 2 دقيقة», «1 حساب وقّع», «2 ملف». | Arabic plurals. The relative-time fix also reaches the buyer and seller apps. |
| Voice | Three dashboard findings addressed her in the masculine («راجع»). | «راجعي», «شغّلي». |

Left as is on purpose: «Reem Value» is the feature's name in both languages;
system-setting keys (`auth.female_only_declaration`) and commission rule names
are data the operator types; and a decision on a seller application needs a
written reason even when it approves, because the server records it.
