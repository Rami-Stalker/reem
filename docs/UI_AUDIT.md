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
