/**
 * Preloaded by `npm test`: the test suite never touches a remote database.
 *
 * The integration specs connect with a bare `new PrismaClient()`, which reads
 * `DATABASE_URL` — and `DATABASE_URL` in `.env` is the API's database, which
 * in production and on a developer machine pointed at it is the Supabase
 * database holding every real account, order and ledger entry. Most specs roll
 * their work back; a handful commit fixtures and delete them afterwards, and a
 * run that dies midway (a slow link, a timeout, a Ctrl+C) leaves those
 * fixtures behind in live data. That happened once. This makes it impossible
 * by default.
 *
 *  - `TEST_DATABASE_URL`, when set, is what the tests use.
 *  - Otherwise `DATABASE_URL` is used only if it names this machine
 *    (localhost / 127.0.0.1 / ::1 / the docker-compose `postgres` service).
 *  - Anything else is replaced with an address nothing listens on, so every
 *    integration spec reports "no database reachable" and skips, and the unit
 *    specs run as usual. `ALLOW_REMOTE_TEST_DATABASE=true` overrides this for a
 *    disposable remote database — never for a real one.
 */
require('dotenv').config();

const LOCAL_HOSTS = new Set(['localhost', '127.0.0.1', '::1', '[::1]', 'postgres']);
const UNREACHABLE = 'postgresql://refused:refused@127.0.0.1:9/remote-database-refused';

const candidate = process.env.TEST_DATABASE_URL || process.env.DATABASE_URL || '';
let host = '';
try {
  host = new URL(candidate).hostname.toLowerCase();
} catch {
  host = '';
}

if (LOCAL_HOSTS.has(host) || process.env.ALLOW_REMOTE_TEST_DATABASE === 'true') {
  process.env.DATABASE_URL = candidate;
} else {
  process.env.DATABASE_URL = UNREACHABLE;
  if (!process.env.REEM_TEST_GUARD_WARNED) {
    process.env.REEM_TEST_GUARD_WARNED = '1';
    process.stderr.write(
      `[test-database-guard] DATABASE_URL points at "${host || 'an unparseable URL'}", not this machine; ` +
        'integration specs will skip. Set TEST_DATABASE_URL to a local database to run them.\n',
    );
  }
}
