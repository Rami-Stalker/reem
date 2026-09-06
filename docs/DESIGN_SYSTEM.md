# Design system

Everything visual in the Reem client comes from `lib/core/design_system/`. This
document is the contract: what to reach for, and what never to write.

The short version:

```dart
final colors = context.dsColors;   // semantic colours
final text = context.dsText;       // semantic text roles

Text(product.title, style: text.cardTitle),
DsGaps.vMd,
Text(price.format(), style: text.price.tabular),
```

No `Colors.white`. No `TextStyle(fontSize: 14, ...)`. No `SizedBox(height: 12)`.
`tools/architecture/check-design-system.mjs` fails the build on all three.

---

## Why this exists

The tokens were never the problem. The palette, the spacing scale and the type
scale were all well designed. What had drifted was **adoption**: five hundred
hand-assembled `TextStyle`s, two hundred raw `Colors.white`s, and a vertical
rhythm that was whatever number each screen's author typed that afternoon. Two
pages built from the same palette still read as two different apps, because
the palette was the only thing they shared.

So the rule is not "use nice colours". The rule is that a screen may choose its
**layout** freely and may choose nothing else.

---

## Layers

| Layer | Path | What lives there |
| --- | --- | --- |
| Tokens | `foundation/tokens/` | Raw scales — colour swatches, spacing, radii, type sizes, motion, sizes |
| Theme | `foundation/theme/` | `ThemeData` assembly, the semantic `DsColorScheme`, and the `context.*` extensions |
| Components | `components/` | Buttons, cards, chips, inputs, states, loaders |
| Patterns | `patterns/` | Page scaffolds, app chrome, role palettes, product surfaces |
| Effects | `effects/` | Glass, mesh backgrounds |

Feature code imports one barrel:

```dart
import 'package:reem/core/design_system/design_system.dart';
```

---

## Colour

`context.dsColors` returns the semantic `DsColorScheme` for the active theme.
Read `primary`, `surface`, `onSurfaceVariant`, `border`, `success`, `price`,
`favorite` and friends — never a raw swatch, and never a Material colour.

### The three registers

Reem has three audiences and three palettes, all resolved from the live theme
so every one of them follows dark mode:

| Register | Accessor | Character |
| --- | --- | --- |
| The buyer's **boutique** | `context.boutique` | Blush rose and champagne. Warm, editorial. |
| The seller's **atelier** | `context.atelier` | Plum and gold. A workroom, sober where the shop is warm. |
| The operator's **console** | `context.console` | Graphite chrome, plum reserved for actions. |

All three expose the same field names — `ink`, `muted`, `background`, `surface`,
`line`, `primary`, `gold`, `positive`, `caution`, `critical` — so a widget that
moves between roles reads the same names in each.

### Colour over media

Text on a photograph or on a brand gradient does **not** follow the theme: the
thing behind it is the image, not the page. That intent has names:

```dart
DsColors.onMedia        // white, over imagery
DsColors.onMediaMuted   // secondary text over imagery
DsColors.onMediaFaint   // hairlines, inactive tracks
DsColors.mediaScrim     // the darkening wash under copy
DsColors.mediaGround    // the ground of a full-bleed surface
DsColors.onChampagne    // deep gold ink on the champagne gradient
DsColors.onGold         // ink on the gold pill gradient
```

A `Colors.white` in feature code is a theme bug until proven otherwise;
`DsColors.onMedia` says "this is over a picture".

### Status colour

Domain objects describe **meaning**, not colour. They return a `DsTone`, and
the widget resolves it:

```dart
DsTone get priorityTone => switch (priority) {
      TaskPriority.high => DsTone.critical,
      TaskPriority.medium => DsTone.caution,
      TaskPriority.low => DsTone.info,
    };

// in the widget
final color = context.toneColor(task.priorityTone);
final fill = context.toneContainer(task.priorityTone);
```

---

## Typography

`context.dsText` returns non-nullable, already-coloured roles. **Ask for a role,
never for a size.**

| Family | Roles |
| --- | --- |
| Page chrome | `hero` `pageTitle` `screenTitle` `sectionTitle` `sectionSubtitle` `overline` |
| Surfaces | `cardTitle` `cardSubtitle` `tileTitle` `tileValue` |
| Prose | `bodyLarge` `body` `bodyStrong` `bodyMuted` `bodySmall` `caption` `captionStrong` |
| Controls | `button` `buttonSmall` `label` `labelStrong` `labelLarge` `labelMedium` `badge` `micro` `link` `tab` |
| Commerce & data | `priceHero` `price` `priceSmall` `priceStruck` `metric` `metricSmall` `metricLabel` `numeric` |

Tune a role rather than rebuilding it:

```dart
text.caption.tint(colors.error)   // recolour, keep everything else
text.body.semibold                // .regular / .medium / .semibold / .bold
text.price.tabular                // tabular figures, so columns line up
text.sectionTitle.uiFamily        // force Cairo on a display-serif role
text.caption.fade(0.7)            // de-emphasise on a coloured ground
```

**Figures are set in the display serif.** The wallet balance, the seller's
revenue, a dashboard metric and a product price all use Playfair numerals —
that editorial voice is the brand. Labels around them stay in Cairo. This is
why `priceHero` and `metric` are serif while `price` (a small figure inside a
card) is not: below ~20px the serif goes spindly.

---

## Spacing

Everything sits on a 4px grid.

```dart
DsGaps.vMd            // a 16px vertical gap
DsGaps.hXs            // an 8px horizontal gap
DsGaps.section        // the rhythm between page sections
DsGaps.sliverBottomSafe   // clearance under a floating bar, as a sliver

DsSpacing.cardPadding     // the inner padding of a card
DsSpacing.pillPadding     // status pills
DsSpacing.chipPadding     // tappable chips
DsSpacing.listRowPadding  // a settings / orders row
DsSpacing.screenHorizontal
```

Fixed dimensions — icons, avatars, controls, thumbnails, aspect ratios — come
from `DsSizes`. `DsIcons`, `DsConstraints` and `DsGrid` forward to it, so there
is exactly one number behind each concept.

---

## Page chrome

Every scrolling screen is:

```dart
ReemScrollPage(
  onRefresh: notifier.load,
  slivers: [
    PremiumAppBar(title: context.l10n.myOrders, showBack: true),
    ...content,
    DsGaps.sliverBottomSafe,
  ],
)
```

`PremiumAppBar` resolves its register from the route (buyer / seller / admin)
and paints a pinned frosted bar with a gradient title. It takes `subtitle`,
`bottom` and `flexibleContent`, so a screen that wants a hero balance or a
cover photo in the header does not have to leave the pattern. `ReemAppBar` is
the box-layout twin for `Scaffold(appBar:)` screens and lightboxes.

Do not hand-roll a `SliverAppBar`. The six screens that did were the six that
looked like a different app.

## Shared surfaces

| Need | Reach for |
| --- | --- |
| A content card | `SurfaceCard` |
| A buyer panel | `CustomerPanel` |
| A button | `DsButton`, or `PrimaryButton` / `SecondaryButton` / `GhostButton` |
| A circular icon action | `DsIconButton` |
| A chip | `DsChip` (`enabled: false` renders the unavailable treatment) |
| A pill / count | `DsBadge`, `DsDiscountBadge` |
| Nothing to show | `DsEmptyState` (`.cart`, `.favorites`, `.search`) |
| Something went wrong | `DsErrorState`, `DsErrorState.offline` |
| Loading | `DsLoadingIndicator`, or `DsShimmer` + `DsSkeleton` for content-shaped placeholders |
| A full-screen photo | `MediaLightbox.open(context, url: ...)` |
| A horizontal product rail | `ProductRail` |

## Motion

`DsMotion` carries the durations and curves; `DsStaggerAnimations.item` is the
one entrance used by grids and lists. Everything routes through
`DsReducedMotion`, so a device asking for less motion gets none rather than a
slower version of the same thing.

---

## Accessibility

The design system carries it, so screens inherit it.

`DsScaleAnimations.tapScale` is the wrapper behind every pressable surface —
buttons, icon buttons, cards, story bubbles — and it declares `Semantics(button,
enabled, onTap)`. A control built on it announces itself without the screen
doing anything.

What a call site still owes:

- **`tooltip` on every `DsIconButton`.** An icon has no text, so the tooltip is
  the only thing a screen reader can read. One without it is unusable without
  sight.
- **`semanticLabel` on a `SurfaceCard`** whose contents do not already say what
  tapping it does.
- **`name` on a `DsAvatar`**, which becomes its label. "Avatar" is noise, and
  the initials fallback would otherwise be read letter by letter.

Two properties are tested in `test/accessibility_test.dart` and worth keeping
there:

- **Controls announce themselves** — label, button role, enabled state. A
  *disabled* control still announces, so an unavailable action is
  distinguishable from a missing one.
- **The layout survives large text.** Reem's buyers include women running their
  phones at 150–200%. Any widget with a fixed dimension around growing text is
  a silent failure at 100% — `DsChip` overflowed its row by 170px at 2× until
  its label was made `Flexible`. Add new components to that group.

## The guard

```bash
node tools/architecture/check-design-system.mjs
```

Enforced across `lib/features/`, `lib/core/router/` and `lib/core/media/`:

- `no-raw-material-colors` — no `Colors.*` except `transparent`
- `no-literal-color-values` — no `Color(0xFF...)`
- `no-hand-rolled-text-styles` — no bare `TextStyle(`
- `no-literal-font-sizes` — no `fontSize: 14`
- `no-literal-corner-radius` — no `BorderRadius.circular(12)`
- `no-deprecated-opacity` — `.withValues(alpha:)`, not `.withOpacity()`
- `off-grid-spacers` / `off-grid-insets` — spacing comes from the scale

The design system itself is exempt: it is the one place allowed to name a
swatch.

### Genuine exceptions

Some things really are outside the system — a monospaced recovery code, a
wordmark, an emoji drawn as an illustration. Mark them, with a reason:

```dart
// ds-ignore: no-hand-rolled-text-styles -- recovery codes are read character
// by character, so they need a monospaced family the type scale lacks.
style: const TextStyle(fontFamily: 'monospace', height: 1.8),
```

The `--` reason is mandatory. An exemption nobody had to justify is how a rule
quietly stops meaning anything.
