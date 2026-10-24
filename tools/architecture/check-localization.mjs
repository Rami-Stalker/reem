#!/usr/bin/env node
// Localisation fitness check.
//
// Ohara is Arabic-first. An English literal in a widget is not a style
// preference, it is a screen a Syrian woman cannot read — and the app had 383
// of them, including an entire rewards hub. The customer-facing surfaces are
// clean now; this keeps them clean and holds the rest to a ceiling that only
// moves down.
//
//   node tools/architecture/check-localization.mjs
//
// Exit code 1 when a guarded area gains a literal, or when the overall count
// rises above the recorded baseline.

import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();

/**
 * Areas that are finished. A new literal in any of these fails the build,
 * because these are the screens a customer actually reaches.
 */
const GUARDED = [
  'lib/features/settings/presentation/screens/rewards_screen.dart',
  'lib/features/search/presentation/screens/search_screen.dart',
  'lib/features/product_details/presentation',
  'lib/features/user_profile/presentation',
  'lib/features/create/presentation',
  'lib/features/onboarding/presentation',
  'lib/features/cart/presentation',
  'lib/features/rewards/presentation',
];

/**
 * Everything else. The backlog reached zero, so the ceiling is zero: the whole
 * app is guarded now, and `GUARDED` is only the list of areas whose failure
 * message is worth being specific about.
 *
 * A literal that genuinely is not copy — a dialling mask, an intl date
 * pattern, a record id the server matches on — carries an inline
 * `// l10n-ignore: <reason>` instead of a translation.
 */
const BASELINE = 0;

const SEARCH_ROOTS = ['lib/features', 'lib/core'];

/** Files that legitimately hold English: none of this is shown to anyone. */
const EXEMPT = [
  '/data/',
  '/domain/',
  'lib/l10n/',
  'api_endpoints',
  'route_paths',
  'route_names',
  // `AdminSectionConfig.title` is an English constant on purpose: it travels
  // to the API, where it identifies the section rather than greeting anyone.
  // What the operator reads comes from `AdminSectionTitle.titleOf(l10n)`.
  'admin/presentation/providers/admin_provider.dart',
  // Font family names are identifiers registered in pubspec.yaml.
  'foundation/tokens/ds_typography.dart',
];

const LITERAL = /'([^'\\\n]{3,160})'/g;

/** Shapes that look like prose but are identifiers, paths or formats. */
const NOT_PROSE = new RegExp(
  '^(' +
    '[a-z_]+(\\.[a-z_]+)+' + // identifiers.and.paths
    '|/[^ ]*' + // /routes
    '|[a-z]+://.*' + // urls
    '|[A-Za-z]+/[A-Za-z0-9.+-]+' + // mime types
    '|[a-z][a-zA-Z0-9]*' + // camelCase single token
    '|[A-Z_]+' + // CONSTANTS
    '|[\\d\\s.,:%+#-]*' + // numbers and punctuation
    '|[a-z]+(_[a-z0-9]+)+' + // snake_case
    ')$',
);

const ARABIC = /[؀-ۿ]/;

/** `${expr}` and `$name` are values, not copy. */
const INTERPOLATION = /\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*/g;

function isProse(value) {
  // Captures that are not really string literals. The regex pairs quotes
  // naively, so a nested quote — `padLeft(2, '0')`, `startsWith('#')` —
  // makes it open mid-expression and close somewhere arbitrary. Both tests
  // below detect that, and between them they removed thirty phantom findings.
  const opens = (value.match(/\$\{/g) ?? []).length;
  const closes = (value.match(/\}/g) ?? []).length;
  if (opens > closes) return false; // opened an interpolation it never closed
  if (/^[)\]}]/.test(value.trim())) return false; // started mid-expression

  // A URL being assembled is a route, not copy, even with words in it.
  if (/^[^ ]*[?&][a-z_]+=/.test(value)) return false;

  if (NOT_PROSE.test(value)) return false;
  if (ARABIC.test(value)) return false; // inline Arabic is a separate debt

  // Judge what is left once the interpolations are removed: `'${a} of ${b}'`
  // is copy, `'${count}'` is a number on its way to a Text widget.
  const literalPart = value.replace(INTERPOLATION, ' ');
  const words = literalPart.match(/[A-Za-z]{2,}/g) ?? [];
  if (words.length >= 2) return true;
  if (words.length === 1 && /^\s*[A-Z]/.test(literalPart)) return true;
  // A count with an English noun — `'${n} items'` — is copy too: one word,
  // lower case, standing after a value with a space between them.
  return (
    words.length === 1 &&
    value.includes("$") &&
    /^\s+[a-z]{3,}\s*$/.test(literalPart.replace(/^\s*/, ' '))
  );
}

const files = SEARCH_ROOTS.flatMap((dir) => walk(path.join(root, dir)))
  .filter((file) => file.endsWith('.dart'))
  .map((file) => normalize(path.relative(root, file)))
  .filter((file) => file.includes('/presentation/') || file.includes('/design_system/'))
  .filter((file) => !EXEMPT.some((part) => file.includes(part)))
  .sort();

const guardedHits = [];
/**
 * A date formatted in a pinned locale — `DateFormat('d MMMM', 'ar')`. It gave
 * English readers Arabic month names and, because intl writes Arabic dates in
 * Arabic-Indic digits, Arabic readers «٥ أكتوبر» beside Western prices. Dates
 * go through `formatCalendarDate(l10n, …)`, which takes the reader's locale
 * and converts the digits. `l10n-ignore` does not cover this one.
 */
const PINNED_DATE_LOCALE = /DateFormat(?:\.\w+)?\([^;]*?'(?:ar|en)(?:_[A-Z]+)?'\s*\)/;
const pinnedDateHits = [];
const otherHits = [];
const arabicHits = [];

/**
 * Inline Arabic is copy too. It used to be "a separate debt" and grew to
 * eleven hundred strings in three dialects; the whole app now reads from the
 * ARB bundles, so the ceiling for Arabic letters inside a literal is zero.
 * Punctuation alone (`'، '`) is a separator, not copy, and is not counted.
 */
const ARABIC_LETTER = /[\u0621-\u064A]/;
const ANY_LITERAL = /'((?:[^'\\\n]|\\.)*)'|"((?:[^"\\\n]|\\.)*)"/g;

/** Files whose Arabic is data rather than copy, each with its reason. */
const ARABIC_EXEMPT = [
  // Server column names for the operator console — a dictionary that follows
  // the API, not the product's voice (see the comment above the map).
  'admin/presentation/widgets/admin_record_details.dart',
];

for (const file of files) {
  const lines = fs.readFileSync(path.join(root, file), 'utf8').split(/\r?\n/);
  const guarded = GUARDED.some((prefix) => file.startsWith(prefix));

  for (const [index, raw] of lines.entries()) {
    const trimmed = raw.trimStart();
    // Directives carry package URIs, not copy. `export` matters as much as
    // `import` here: the design-system barrels are almost entirely exports,
    // and counting them inflated the backlog by seventy.
    if (
      trimmed.startsWith('//') ||
      trimmed.startsWith('import ') ||
      trimmed.startsWith('export ') ||
      trimmed.startsWith('part ')
    ) {
      continue;
    }
    if (PINNED_DATE_LOCALE.test(raw)) {
      pinnedDateHits.push({ file, line: index + 1, value: raw.trim() });
    }

    // An opt-out for a literal that is genuinely not copy — a dialling mask,
    // an intl pattern, a record id. It covers its own line and the one below,
    // so it can sit above the expression rather than trailing it, where it
    // would swallow a comma.
    if (raw.includes('l10n-ignore')) continue;
    if (index > 0 && lines[index - 1].includes('l10n-ignore')) continue;

    if (!ARABIC_EXEMPT.some((part) => file.includes(part))) {
      for (const match of raw.matchAll(ANY_LITERAL)) {
        const value = match[1] ?? match[2] ?? '';
        if (ARABIC_LETTER.test(value)) {
          arabicHits.push({ file, line: index + 1, value });
        }
      }
    }

    for (const match of raw.matchAll(LITERAL)) {
      if (!isProse(match[1])) continue;
      if (guarded) {
        guardedHits.push({ file, line: index + 1, value: match[1] });
      } else {
        otherHits.push({ file, line: index + 1, value: match[1] });
      }
    }
  }
}

console.log('Localisation fitness check');
console.log(`Scanned ${files.length} presentation files`);
console.log(`Guarded areas: ${guardedHits.length} literals (must be 0)`);
const otherCount = otherHits.length;
console.log(`Everywhere else: ${otherCount} literals (baseline ${BASELINE})`);
console.log(`Inline Arabic: ${arabicHits.length} literals (must be 0)`);
console.log(`Dates in a pinned locale: ${pinnedDateHits.length} (must be 0)`);

// `--list` prints the unguarded backlog, so it can be worked through.
if (process.argv.includes('--list')) {
  const byFile = new Map();
  for (const hit of otherHits) {
    byFile.set(hit.file, [...(byFile.get(hit.file) ?? []), hit]);
  }
  for (const [file, hits] of [...byFile].sort((a, b) => b[1].length - a[1].length)) {
    console.log(`
### ${file} (${hits.length})`);
    for (const hit of hits) console.log(`  ${hit.line}  ${hit.value}`);
  }
}

if (guardedHits.length > 0) {
  console.log('\nEnglish copy in a finished area:');
  console.log('  move it to lib/l10n/app_en.arb + app_ar.arb and read it');
  console.log('  through `context.l10n`. A notifier with no context should');
  console.log('  carry a message enum, the way `AuthMessage` does.');
  for (const hit of guardedHits.slice(0, 30)) {
    console.log(`    ${hit.file}:${hit.line}  ${hit.value}`);
  }
  if (guardedHits.length > 30) {
    console.log(`    ... and ${guardedHits.length - 30} more`);
  }
}

if (otherCount > BASELINE) {
  console.log(
    `\nThe unguarded count rose to ${otherCount}, above the ${BASELINE} baseline.`,
  );
  console.log('Localise what you added, or finish an area and guard it.');
}

if (arabicHits.length > 0) {
  console.log('\nInline Arabic copy:');
  console.log('  add it to app_ar.arb with an English twin in app_en.arb, in');
  console.log('  the friendly feminine voice (Q68/Q69), and read it through');
  console.log('  `context.l10n`. Data that is not copy carries `// l10n-ignore:`.');
  for (const hit of arabicHits.slice(0, 30)) {
    console.log(`    ${hit.file}:${hit.line}  ${hit.value}`);
  }
  if (arabicHits.length > 30) {
    console.log(`    ... and ${arabicHits.length - 30} more`);
  }
}

if (pinnedDateHits.length > 0) {
  console.log('\nDate formatted in a pinned locale:');
  console.log('  use `formatCalendarDate(context.l10n, date, pattern: …)` so the');
  console.log("  reader's language picks the month names and digits stay Western.");
  for (const hit of pinnedDateHits) {
    console.log(`    ${hit.file}:${hit.line}  ${hit.value}`);
  }
}

if (
  guardedHits.length > 0 ||
  otherCount > BASELINE ||
  arabicHits.length > 0 ||
  pinnedDateHits.length > 0
) {
  process.exitCode = 1;
}

function walk(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const next = path.join(dir, entry.name);
    if (entry.isDirectory()) return walk(next);
    return entry.isFile() ? [next] : [];
  });
}

function normalize(value) {
  return value.replaceAll(path.sep, '/');
}
