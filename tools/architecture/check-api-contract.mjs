#!/usr/bin/env node
/**
 * Every path the client declares must be a route the API serves.
 *
 * The client keeps its whole endpoint surface in one file, which is what makes
 * this checkable at all. The failure it guards against is quiet: somebody
 * declares a path for a feature that is planned, builds a screen on it, and
 * the screen ships answering 404 — or worse, a route is renamed on the server
 * and the constant keeps pointing at the old one. Neither shows up in
 * `flutter analyze`, in `tsc`, or in any test, because both halves compile
 * perfectly well on their own.
 *
 * Direction is deliberate: client → server, not the reverse. A backend route
 * with no client caller is ordinary (admin tooling, webhooks, routes the app
 * has not reached yet). A *client* path with no backend route is always a
 * defect.
 *
 * Path parameters are normalised away — Dart writes `$id` or `${id}`, Nest
 * writes `:id` — so this compares shapes, not values. It cannot tell you the
 * method is right or the body matches; the contract tests under `test/contract`
 * do that. This catches the coarser mistake that those never see, because a
 * contract test only covers an endpoint somebody remembered to write one for.
 */
import fs from 'node:fs';
import path from 'node:path';

const BACKEND = 'backend/src';
const CLIENT = 'lib/core/network/api_endpoints.dart';

/** Every `METHOD path` the API actually serves. */
function backendRoutes(dir) {
  const routes = new Set();
  const walk = (d) => {
    for (const entry of fs.readdirSync(d, { withFileTypes: true })) {
      const full = path.join(d, entry.name);
      if (entry.isDirectory()) {
        walk(full);
      } else if (entry.name.endsWith('.controller.ts')) {
        const src = fs.readFileSync(full, 'utf8');
        // A file may hold several controllers — `rewards.controller.ts` holds
        // three — and each owns the routes that follow it. Taking only the
        // first prefix silently mis-attributes the rest.
        const marks = [
          ...src.matchAll(/@Controller\(\s*['"`]([^'"`]*)['"`]?\s*\)/g),
        ].map((m) => ({ prefix: m[1], at: m.index }));
        if (marks.length === 0) continue;

        for (const verb of src.matchAll(
          /@(Get|Post|Put|Patch|Delete)\(\s*(?:['"`]([^'"`]*)['"`])?/g,
        )) {
          let prefix = '';
          for (const mark of marks) if (mark.at < verb.index) prefix = mark.prefix;
          routes.add(join(prefix, verb[2] ?? ''));
        }
      }
    }
  };
  walk(dir);
  return routes;
}

const join = (prefix, sub) =>
  `/${prefix}/${sub}`.replace(/\/+/g, '/').replace(/(.)\/$/, '$1');

/** Dart `$id` and `${id}`, Nest `:id` — all the same hole in the path. */
const normalise = (value) =>
  value
    .replace(/\$\{[^}]*\}/g, '*')
    .replace(/\$[A-Za-z_][A-Za-z0-9_]*/g, '*')
    .replace(/:[A-Za-z0-9_]+/g, '*')
    .replace(/\?.*$/, '')
    .replace(/(.)\/$/, '$1');

function clientPaths(file) {
  const src = fs.readFileSync(file, 'utf8');
  // Only string literals that look like paths. A comment mentioning a path in
  // quotes would be picked up too, so comments here avoid quoting one.
  return new Set(
    [...src.matchAll(/'(\/[^']*)'/g)].map((m) => m[1]).filter((p) => p.length > 1),
  );
}

const served = new Set([...backendRoutes(BACKEND)].map(normalise));
const declared = [...new Set([...clientPaths(CLIENT)].map(normalise))];
const unmatched = declared.filter((p) => !served.has(p)).sort();

console.log('API contract check');
console.log(`  backend routes: ${served.size}`);
console.log(`  client paths:   ${declared.length}`);

if (unmatched.length === 0) {
  console.log('  Every path the client declares is served.');
  process.exit(0);
}

console.error(`\n${unmatched.length} client path(s) reach nothing:\n`);
for (const p of unmatched) console.error(`  ${p}`);
console.error(
  '\nEither the route was renamed on the server, or this is a screen built ' +
    'on a feature the API does not have. Both ship as a 404.',
);
process.exit(1);
