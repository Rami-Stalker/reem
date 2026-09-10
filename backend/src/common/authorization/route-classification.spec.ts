import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import path from 'node:path';

/**
 * Every route says how it is protected, and this is what keeps it that way.
 *
 * `AuthorizationGuard` used to return `true` for any route that declared no
 * policy. Almost all of those routes *were* protected — by an ownership check
 * inside the service — but the guarantee could not be read from the
 * declaration, only from opening the service behind it. A new route added to
 * one of those controllers inherited "allowed" in silence, and nothing
 * anywhere would have said so.
 *
 * The guard now fails closed, and a controller must be one of three things:
 *
 * - **`@Public()`** — no session needed, stated deliberately.
 * - **`@Roles` / `@Authorize` / `@RequirePermissions`** — the rule is
 *   declarative and the guard enforces it.
 * - **`@SelfScoped('...')`** — the rule depends on the row, the service
 *   enforces it, and the reason names the check so a reviewer need not go
 *   looking.
 *
 * A file scan rather than a runtime scan on purpose: this must fail in CI when
 * somebody *writes* an unclassified controller, not when a request eventually
 * reaches one in production.
 */
const CONTROLLER_DIR = path.join(__dirname, '..', '..', 'modules');

const DECLARATIONS = [
  '@Public()',
  '@OptionalAuth()',
  '@Roles(',
  '@Authorize(',
  '@RequirePermissions(',
  '@SelfScoped(',
];

function controllers(dir: string): string[] {
  const found: string[] = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) found.push(...controllers(full));
    else if (entry.name.endsWith('.controller.ts')) found.push(full);
  }
  return found;
}

const files = controllers(CONTROLLER_DIR);

/**
 * Splits a controller file into its decorated declarations.
 *
 * Line-oriented and paren-counting rather than a real parse, but it handles
 * the two things a naive scan gets wrong: a decorator whose arguments span
 * several lines, and a `@Roles(...)` written *below* the `@Get(...)` it
 * belongs to, which is legal and common here.
 *
 * Each entry is a whole decorator run plus the declaration it decorates.
 */
function decoratedDeclarations(source: string): string[] {
  const lines = source
    // A comment can contain the text of a decorator, so comments are blanked
    // before the scan rather than matched against.
    .replace(/\/\*[\s\S]*?\*\//g, (block) => block.replace(/[^\n]/g, ' '))
    .split(/\r?\n/)
    .map((line) => line.replace(/\/\/.*$/, ''));

  const blocks: string[] = [];
  let buffer: string[] = [];
  let depth = 0;

  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    if (depth === 0 && buffer.length === 0 && !line.trim().startsWith('@')) {
      continue;
    }

    buffer.push(line);
    depth +=
      (line.match(/[([{]/g) ?? []).length -
      (line.match(/[)\]}]/g) ?? []).length;
    if (depth > 0) continue;
    depth = 0;

    // The run continues while the next meaningful line is another decorator;
    // when it is not, that line is the declaration being decorated.
    let next = i + 1;
    while (next < lines.length && lines[next].trim() === '') next += 1;
    if (next < lines.length && lines[next].trim().startsWith('@')) continue;
    if (next < lines.length) {
      buffer.push(lines[next]);
      i = next;
    }

    blocks.push(buffer.join('\n'));
    buffer = [];
  }

  return blocks;
}

const ROUTE = /@(?:Get|Post|Patch|Put|Delete)\s*\(/;
const CLASS = /^export\s+(?:abstract\s+)?class\s+\w+/m;

test('there are controllers to check at all', () => {
  assert.ok(
    files.length > 50,
    `expected the platform's controllers, found ${files.length}`,
  );
});

test('every route declares how it is authorized', () => {
  // Per *handler*, not per file. The file-level version of this test passed
  // while thirty-six routes were being refused in production: one `@Public()`
  // anywhere in a file vouched for every route in it, and three of these files
  // hold more than one controller, so a declaration on the first vouched for
  // the second as well. `GET /auth/me` was among them — the call every client
  // makes to restore a session — so signing in worked and staying signed in
  // did not.
  const undeclared: string[] = [];

  for (const file of files) {
    const source = fs.readFileSync(file, 'utf8');
    let classDeclares = false;

    for (const block of decoratedDeclarations(source)) {
      const declares = DECLARATIONS.some((marker) => block.includes(marker));
      if (CLASS.test(block)) {
        classDeclares = declares;
        continue;
      }
      if (!ROUTE.test(block) || declares || classDeclares) continue;
      const route = block
        .split(/\r?\n/)
        .find((line) => ROUTE.test(line))
        ?.trim();
      undeclared.push(`${path.relative(CONTROLLER_DIR, file)} — ${route}`);
    }
  }

  assert.deepEqual(
    undeclared,
    [],
    'These routes declare no authorization, so the guard refuses every ' +
      'request to them. Add @Roles/@Authorize where the rule is declarative, ' +
      '@Public() where no session is needed, or @SelfScoped("how the service ' +
      'enforces ownership") where the rule depends on the row.',
  );
});

test('a self-scoped controller gives a reason worth reading', () => {
  const lazy: string[] = [];

  for (const file of files) {
    const source = fs.readFileSync(file, 'utf8');
    for (const match of source.matchAll(/@SelfScoped\(\s*(['"])([\s\S]*?)\1/g)) {
      // The reason is the whole value of the annotation: it is what a reviewer
      // reads instead of opening the service. "ownership" is not a reason.
      if (match[2].trim().split(/\s+/).length < 5) {
        lazy.push(path.relative(CONTROLLER_DIR, file));
      }
    }
  }

  assert.deepEqual(
    lazy,
    [],
    'These say @SelfScoped but do not say how. Name the check.',
  );
});
