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

test('there are controllers to check at all', () => {
  assert.ok(
    files.length > 50,
    `expected the platform's controllers, found ${files.length}`,
  );
});

test('every controller declares how it is authorized', () => {
  const undeclared = files.filter((file) => {
    const source = fs.readFileSync(file, 'utf8');
    return !DECLARATIONS.some((marker) => source.includes(marker));
  });

  assert.deepEqual(
    undeclared.map((file) => path.relative(CONTROLLER_DIR, file)),
    [],
    'These controllers declare no authorization. The guard will refuse every ' +
      'route on them. Add @Roles/@Authorize where the rule is declarative, ' +
      '@Public() where no session is needed, or @SelfScoped("how the service ' +
      'enforces ownership") where the rule depends on the row.',
  );
});

test('a self-scoped controller gives a reason worth reading', () => {
  const lazy: string[] = [];

  for (const file of files) {
    const source = fs.readFileSync(file, 'utf8');
    const match = source.match(/@SelfScoped\(\s*(['"])([\s\S]*?)\1/);
    if (!match) continue;
    // The reason is the whole value of the annotation: it is what a reviewer
    // reads instead of opening the service. "ownership" is not a reason.
    if (match[2].trim().split(/\s+/).length < 5) {
      lazy.push(path.relative(CONTROLLER_DIR, file));
    }
  }

  assert.deepEqual(
    lazy,
    [],
    'These say @SelfScoped but do not say how. Name the check.',
  );
});
