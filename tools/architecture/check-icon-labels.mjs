#!/usr/bin/env node
/**
 * An icon-only button must say what it does.
 *
 * A button whose whole content is an icon has no text for a screen reader to
 * read. Flutter announces it as "button" and nothing more — so a woman using
 * TalkBack or VoiceOver hears the same four letters for "add to cart", "remove
 * from favourites" and "delete". `tooltip:` is what fixes it: Flutter derives
 * the semantic label from it, and sighted users get the long-press hint for
 * free.
 *
 * This is checkable and the analyzer does not check it, which is the whole
 * reason it exists: 25 of the platform's 86 icon buttons carried no label at
 * all, including "add to cart" on the product card and the quantity steppers
 * in the basket.
 *
 * **A bare `GestureDetector` around an icon is worse, not better** — it does
 * not even announce as a button. Those need `Semantics(button: true, label:)`,
 * so a `tooltip` alone does not satisfy this check for them; they are caught
 * by eye, not here, and the two components that did it are now wrapped.
 */
import fs from 'node:fs';
import path from 'node:path';

const ROOT = 'lib';

/** The button constructors whose content is an icon and nothing else. */
const CONSTRUCTORS = ['IconButton(', 'DsIconButton(', 'GradientIconButton('];

function dartFiles(dir) {
  const found = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) found.push(...dartFiles(full));
    // Generated localisations are not hand-written UI.
    else if (entry.name.endsWith('.dart') && !full.includes('l10n')) {
      found.push(full);
    }
  }
  return found;
}

/** The source of the call, from its opening paren to its matching close. */
function callBody(src, open) {
  let depth = 0;
  for (let i = open; i < src.length; i += 1) {
    if (src[i] === '(') depth += 1;
    else if (src[i] === ')') {
      depth -= 1;
      if (depth === 0) return src.slice(open, i + 1);
    }
  }
  return src.slice(open);
}

let total = 0;
const unlabelled = [];

for (const file of dartFiles(ROOT)) {
  const src = fs.readFileSync(file, 'utf8');

  for (const constructor of CONSTRUCTORS) {
    let at = 0;
    while ((at = src.indexOf(constructor, at)) !== -1) {
      const open = src.indexOf('(', at + constructor.length - 1);
      const body = callBody(src, open);

      // `const DsIconButton({ ... })` is the constructor being *declared* —
      // the place `tooltip` is defined, not a use of it. A declaration's
      // parameter list opens with `({`; a call opens with an argument. That
      // one character is the whole difference, and matching on `class` or
      // `const` in the preceding text missed the declarations whose name sits
      // on its own line.
      const isDeclaration = /^\(\s*\{/.test(body);

      if (!isDeclaration) {
        total += 1;
        if (!/\btooltip:|\bsemanticLabel:/.test(body)) {
          unlabelled.push({
            file,
            line: src.slice(0, at).split('\n').length,
            icon: (body.match(/Icons?\.([A-Za-z_0-9]+)/) ?? [])[1] ?? '?',
          });
        }
      }
      at = open + body.length;
    }
  }
}

console.log('Icon button label check');
console.log(`  icon buttons: ${total}`);
console.log(`  unlabelled:   ${unlabelled.length}`);

if (unlabelled.length === 0) {
  console.log('  Every icon-only button says what it does.');
  process.exit(0);
}

console.error('\nThese announce as "button" and nothing else:\n');
for (const hit of unlabelled) {
  console.error(`  ${hit.file}:${hit.line}  (${hit.icon})`);
}
console.error(
  '\nAdd `tooltip:` — Flutter reads it aloud and shows it on long press.',
);
process.exit(1);
