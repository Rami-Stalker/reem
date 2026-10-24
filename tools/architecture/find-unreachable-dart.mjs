#!/usr/bin/env node
// Reports Dart libraries under lib/ that nothing reaches.
//
// A file is reachable when some other file names it in an `import`, `export`,
// or `part` directive. Roots are lib/main.dart and everything under test/.
// Both `package:ohara/...` and relative URIs are resolved to real paths, and the
// sweep iterates to a fixed point so a file kept alive only by another dead
// file is reported too.
//
//   node tools/architecture/find-unreachable-dart.mjs          # report
//   node tools/architecture/find-unreachable-dart.mjs --list   # paths only
//
// Exits 1 when anything is unreachable, so CI can gate on it.

import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const PACKAGE = 'package:ohara/';
const ROOTS = new Set(['lib/main.dart']);
const listOnly = process.argv.includes('--list');

const norm = (p) => p.split(path.sep).join('/');

function walk(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    return entry.isDirectory() ? walk(full) : [full];
  });
}

function directives(file) {
  const text = fs.readFileSync(path.join(root, file), 'utf8');
  return [...text.matchAll(/^\s*(?:import|export|part)\s+'([^']+)'/gm)].map((m) => m[1]);
}

function resolve(container, uri) {
  if (uri.startsWith(PACKAGE)) return `lib/${uri.slice(PACKAGE.length)}`;
  if (uri.startsWith('package:') || uri.startsWith('dart:')) return null;
  return norm(path.posix.normalize(path.posix.join(path.posix.dirname(container), uri)));
}

const every = ['lib', 'test']
  .flatMap((dir) => walk(path.join(root, dir)))
  .filter((f) => f.endsWith('.dart'))
  .map((f) => norm(path.relative(root, f)));

const dead = new Set();
for (;;) {
  const live = every.filter((f) => !dead.has(f));
  const reached = new Set();
  for (const file of live) {
    for (const uri of directives(file)) {
      const target = resolve(file, uri);
      if (target) reached.add(target);
    }
  }
  const found = live.filter(
    (f) => f.startsWith('lib/') && !reached.has(f) && !ROOTS.has(f),
  );
  if (found.length === 0) break;
  found.forEach((f) => dead.add(f));
}

const unreachable = [...dead].sort();

if (listOnly) {
  unreachable.forEach((f) => console.log(f));
} else {
  console.log('Unreachable Dart libraries under lib/');
  if (unreachable.length === 0) {
    console.log('  none — every library is reachable from main.dart or a test');
  } else {
    const lines = unreachable.reduce((total, f) => {
      return total + fs.readFileSync(path.join(root, f), 'utf8').split('\n').length;
    }, 0);
    console.log(`  ${unreachable.length} file(s), ${lines} lines`);
    unreachable.forEach((f) => console.log(`  - ${f}`));
  }
}

process.exit(unreachable.length === 0 ? 0 : 1);
