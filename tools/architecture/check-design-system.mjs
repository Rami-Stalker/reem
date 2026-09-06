#!/usr/bin/env node
// Design-system fitness check.
//
// The visual drift this repo carried was never in the tokens -- those were
// good -- it was in adoption. Five hundred hand-rolled `TextStyle`s, two
// hundred raw `Colors.white`s and a per-screen spacing rhythm meant two pages
// built from the same palette still read as two apps. That is now cleaned up,
// and this is what keeps it cleaned up.
//
// Enforced rules apply to feature code (`lib/features/**`) and to the router.
// The design system itself is exempt: it is the one place allowed to name a
// swatch, and its own hygiene is covered by review.
//
//   node tools/architecture/check-design-system.mjs
//
// Exit code 1 on any enforced violation.

import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();

/** Where the rules bite. */
const ENFORCED_ROOTS = ['lib/features', 'lib/core/router', 'lib/core/media'];

/** The design system defines the vocabulary, so it may use the raw words. */
const EXEMPT_PREFIXES = ['lib/core/design_system/', 'lib/l10n/'];

/**
 * `Colors.transparent` is mode-independent and universally understood; banning
 * it buys nothing. Everything else in Material's palette is a theme bug.
 */
const ALLOWED_MATERIAL_COLORS = new Set(['transparent']);

const RULES = [
  {
    id: 'no-raw-material-colors',
    // `Colors.white`, `Colors.grey[600]`, `Colors.pink.shade200` ...
    pattern: /\bColors\.([A-Za-z]+)/g,
    skip: (match) => ALLOWED_MATERIAL_COLORS.has(match[1]),
    hint: 'read colour from `context.dsColors` / a role palette, or use `DsColors.onMedia` over imagery',
  },
  {
    id: 'no-literal-color-values',
    pattern: /Color\(0x[0-9a-fA-F]{6,8}\)/g,
    hint: 'add the swatch to DsColors and reach it through the semantic scheme',
  },
  {
    id: 'no-hand-rolled-text-styles',
    // A bare `TextStyle(` in feature code. `.copyWith(` on a role is fine.
    pattern: /(?<![.\w])TextStyle\(/g,
    hint: 'use a role from `context.dsText` and tune it with `.tint()` / `.copyWith()`',
  },
  {
    id: 'no-literal-font-sizes',
    pattern: /fontSize:\s*[0-9]/g,
    hint: 'the size belongs to a `context.dsText` role, not to the call site',
  },
  {
    id: 'no-literal-corner-radius',
    pattern: /BorderRadius\.circular\(\s*[0-9]/g,
    hint: 'use a `DsRadius` token so a card and a sheet cannot disagree',
  },
  {
    id: 'no-deprecated-opacity',
    pattern: /\.withOpacity\(/g,
    hint: 'use `.withValues(alpha:)` -- withOpacity loses precision and is deprecated',
  },
  {
    id: 'off-grid-spacers',
    // A childless `SizedBox` is a gap, and gaps live on the 4px grid.
    pattern: /SizedBox\(\s*(?:height|width):\s*[0-9]+(?:\.[0-9]+)?\s*[,)]/g,
    hint: 'use a `DsGaps` spacer, or a `DsSizes` constant when it is a real dimension',
  },
  {
    id: 'off-grid-insets',
    pattern: /EdgeInsets(?:Directional)?\.(?:all|symmetric|only|fromLTRB)\([^)]*?[0-9]+(?:\.[0-9]+)?/g,
    hint: 'use a `DsSpacing` token or one of its named component insets',
  },
];

/**
 * Nothing is advisory any more: the two spacing queues that lived here were
 * burned down to zero and promoted into [RULES]. The mechanism stays, because
 * the next sweep will want somewhere to park a debt it cannot finish in one
 * pass.
 */
const ADVISORY = [];

/** How far below a `ds-ignore` marker its exemption can reach. */
const MAX_EXEMPT_SPAN = 20;

const files = ENFORCED_ROOTS.flatMap((dir) => walk(path.join(root, dir)))
  .filter((file) => file.endsWith('.dart'))
  .map((file) => normalize(path.relative(root, file)))
  .filter((file) => !EXEMPT_PREFIXES.some((prefix) => file.startsWith(prefix)))
  .sort();

const violations = [];
const advisory = new Map(ADVISORY.map((rule) => [rule.id, []]));

for (const file of files) {
  const text = fs.readFileSync(path.join(root, file), 'utf8');
  const lines = text.split(/\r?\n/);

  // `// ds-ignore: rule-id -- why` on the line above (or at the end of the
  // line) exempts it. The reason is mandatory: an exemption without one is
  // how a rule quietly stops meaning anything.
  const exemptions = collectExemptions(lines);

  for (const [index, raw] of lines.entries()) {
    const line = stripNoise(raw);
    if (!line) continue;

    for (const rule of RULES) {
      if (exemptions.get(index + 1)?.has(rule.id)) continue;
      for (const match of line.matchAll(rule.pattern)) {
        if (rule.skip?.(match)) continue;
        violations.push({
          rule: rule.id,
          file,
          line: index + 1,
          detail: match[0],
          hint: rule.hint,
        });
      }
    }

    for (const rule of ADVISORY) {
      for (const _ of line.matchAll(rule.pattern)) {
        advisory.get(rule.id).push({ file, line: index + 1 });
      }
    }
  }
}

report();

if (violations.length > 0) {
  process.exitCode = 1;
}

/**
 * Reads `// ds-ignore: rule-id -- reason` markers.
 *
 * A marker covers its own line and the expression that follows it: every
 * subsequent line indented at least as deeply, up to [MAX_EXEMPT_SPAN] lines.
 * That is exactly the shape of a Dart argument list, so one marker above a
 * multi-line `TextStyle(...)` covers the whole literal.
 *
 * The `--` reason is mandatory. An exemption nobody had to justify is how a
 * rule quietly stops meaning anything.
 */
function collectExemptions(lines) {
  const map = new Map();
  const add = (line, rule) => {
    const set = map.get(line) ?? new Set();
    set.add(rule);
    map.set(line, set);
  };

  for (const [index, raw] of lines.entries()) {
    const match = /\/\/\s*ds-ignore:\s*([a-z-]+)(.*)$/.exec(raw);
    if (!match) continue;
    if (!match[2].includes('--')) {
      violations.push({
        rule: 'ds-ignore-needs-a-reason',
        file: 'unknown',
        line: index + 1,
        detail: raw.trim(),
        hint: 'write `// ds-ignore: rule-id -- why this one is deliberate`',
      });
      continue;
    }

    const rule = match[1];
    const indent = raw.length - raw.trimStart().length;
    add(index + 1, rule);

    for (let i = index + 1; i < lines.length && i <= index + MAX_EXEMPT_SPAN; i++) {
      const next = lines[i];
      if (next.trim() === '') break;
      const nextIndent = next.length - next.trimStart().length;
      if (nextIndent < indent) break;
      add(i + 1, rule);
    }
  }
  return map;
}

/** Drops comments and string literals so prose and copy never trip a rule. */
function stripNoise(line) {
  const trimmed = line.trimStart();
  if (trimmed.startsWith('//')) return '';
  return line
    .replace(/'(?:\\.|[^'\\])*'/g, "''")
    .replace(/"(?:\\.|[^"\\])*"/g, '""')
    .replace(/\/\/.*$/, '');
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

function report() {
  console.log('Design-system fitness check');
  console.log(`Scanned ${files.length} files under ${ENFORCED_ROOTS.join(', ')}`);
  console.log(`Enforced violations: ${violations.length}`);

  const byRule = new Map();
  for (const violation of violations) {
    const bucket = byRule.get(violation.rule) ?? [];
    bucket.push(violation);
    byRule.set(violation.rule, bucket);
  }

  for (const [rule, found] of byRule) {
    console.log(`\n- ${rule} (${found.length})`);
    console.log(`  ${found[0].hint}`);
    for (const violation of found.slice(0, 20)) {
      console.log(`    ${violation.file}:${violation.line}  ${violation.detail}`);
    }
    if (found.length > 20) {
      console.log(`    ... and ${found.length - 20} more`);
    }
  }

  console.log('\nAdvisory (burn down incrementally, does not fail the build):');
  for (const rule of ADVISORY) {
    console.log(`- ${rule.id}: ${advisory.get(rule.id).length}`);
  }
}
