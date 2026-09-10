#!/usr/bin/env node
/**
 * A network image must say how large it may decode.
 *
 * A decoded bitmap costs four bytes per pixel, and the pixels are the *source
 * file's*, not the widget's. A boutique uploads a 2400×3200 photograph, a card
 * draws it 138 points wide, and Flutter holds 30 MB of RAM for it — while the
 * card shows about 0.2 MB worth of detail. `memCacheWidth` is the instruction
 * that stops that: decode to this width, discard the rest.
 *
 * Sixteen of the platform's twenty-six network images had no budget when this
 * check was written, four of them on the home screen — the first thing a woman
 * sees, several carousels alive at once. It is invisible on a development
 * machine with 32 GB and shows up as the OS killing the app on a 3 GB Android
 * phone, which is the phone this platform is for.
 *
 * Requesting a smaller *variant* from the server is a different fix for a
 * different cost: the variant bounds the download, `memCacheWidth` bounds the
 * decode. Most of the sites here already did the first and none of them did the
 * second, which is why the analyzer's silence proved nothing.
 *
 * The analyzer cannot express this, which is the whole reason the file exists.
 */
import fs from 'node:fs';
import path from 'node:path';

const ROOT = 'lib';

/** Constructors that fetch bytes over the network and decode them. */
const CONSTRUCTORS = ['CachedNetworkImage(', 'Image.network('];

/** Either name satisfies it: `cacheWidth` is Flutter's, `memCacheWidth` is the package's. */
const BUDGET = /\bmemCacheWidth:|\bcacheWidth:/;

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
const unbudgeted = [];

for (const file of dartFiles(ROOT)) {
  const src = fs.readFileSync(file, 'utf8');

  for (const constructor of CONSTRUCTORS) {
    let at = 0;
    while ((at = src.indexOf(constructor, at)) !== -1) {
      const open = src.indexOf('(', at + constructor.length - 1);
      const body = callBody(src, open);
      total += 1;
      if (!BUDGET.test(body)) {
        unbudgeted.push({
          file: file.split(path.sep).join('/'),
          line: src.slice(0, at).split('\n').length,
          constructor: constructor.slice(0, -1),
        });
      }
      at = open + body.length;
    }
  }
}

console.log('Image decode budget check');
console.log(`  network images: ${total}`);
console.log(`  without a budget: ${unbudgeted.length}`);

if (unbudgeted.length === 0) {
  console.log('  Every network image bounds its own decode.');
  process.exit(0);
}

console.error('\nThese decode at the source file’s full resolution:\n');
for (const hit of unbudgeted) {
  console.error(`  ${hit.file}:${hit.line}  (${hit.constructor})`);
}
console.error(
  [
    '',
    'Add `memCacheWidth:`. Use `MediaDecode.widthFor(context, <logical width>)`',
    'when the drawn width is known, or `MediaDecode.widthFrom(context,',
    'constraints)` inside a `LayoutBuilder` when a parent decides it.',
  ].join('\n'),
);
process.exit(1);
