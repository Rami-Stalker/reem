import assert from 'node:assert/strict';
import test from 'node:test';
import type { ConfigService } from '@nestjs/config';
import { AppLinksService } from './app-links.service';
import {
  escapeHtml,
  escapeJson,
  renderLandingPage,
  renderMessagePage,
  safeSchemeUrl,
  safeUrl,
} from './landing-page';
import {
  APP_HANDLED_KINDS,
  appLinkPatterns,
  appRouteFor,
  buildPath,
  schemeUrl,
  SHARE_PATHS,
  shareUrl,
} from './share-links';
import {
  formatCount,
  formatMoney,
  isUuid,
  summarise,
  truncate,
} from './share-preview.service';
import { SharePreview } from './share-preview';
import { Currency, Prisma } from '@prisma/client';

// ── Builders ────────────────────────────────────────────────────────────────

function preview(overrides: Partial<SharePreview> = {}): SharePreview {
  return {
    kind: 'product',
    path: '/product/abc',
    appRoute: '/product-details?id=abc',
    label: 'منتج على ريم',
    title: 'فستان سهرة',
    description: 'حرير بنقشة وردية',
    imageUrl: 'https://cdn.example.com/dress.jpg',
    ...overrides,
  };
}

function config(values: Record<string, unknown>): ConfigService {
  return { get: (key: string) => values[key] } as unknown as ConfigService;
}

function renderProductPage(overrides: Partial<SharePreview> = {}): string {
  return renderLandingPage({
    preview: preview(overrides),
    canonicalUrl: 'https://links.example.com/product/abc',
    schemeUrl: 'reem://product-details?id=abc',
    nonce: 'n0nc3',
  });
}

// ── Link shapes ─────────────────────────────────────────────────────────────

test('a share path fills its parameters and encodes each one once', () => {
  assert.equal(buildPath(SHARE_PATHS.product, { id: 'abc' }), '/product/abc');
  assert.equal(
    buildPath(SHARE_PATHS['room-invite'], { slug: 'a b/c' }),
    '/rooms/join/a%20b%2Fc',
  );
});

test('a missing parameter is a programming error, not a broken link', () => {
  assert.throws(() => buildPath(SHARE_PATHS.product, {}), /Missing "id"/);
});

test('the shared URL is the configured origin plus the canonical path', () => {
  assert.equal(
    shareUrl('https://links.example.com/', 'content', { id: 'p1' }),
    'https://links.example.com/p/p1',
  );
});

test('the scheme URL is built from the app route, not the share path', () => {
  // Load-bearing: this is what the landing page's button opens, and it has to
  // reach the right screen on an install that predates the share-path routes.
  assert.equal(
    schemeUrl('reem', 'product', { id: 'abc' }),
    'reem://product-details?id=abc',
  );
  assert.equal(schemeUrl('reem', 'content', { id: 'p1' }), 'reem://content/p1');
  assert.equal(
    schemeUrl('reem', 'room-invite', { slug: 's1' }),
    'reem://rooms/join/s1',
  );
});

test('the product app route keeps the query-parameter spelling the app routes on', () => {
  assert.equal(appRouteFor('product', { id: 'abc' }), '/product-details?id=abc');
  assert.equal(appRouteFor('profile', { id: 'u1' }), '/user/u1');
  assert.equal(
    appRouteFor('storefront', { id: 'u1' }),
    '/user/u1/products',
  );
});

test('an invitation is never intercepted by the app', () => {
  // The one person an invite is written for is the one person without Reem.
  assert.ok(!APP_HANDLED_KINDS.includes('referral'));
});

test('app-link patterns collapse nested paths and carry no duplicates', () => {
  const patterns = appLinkPatterns();
  assert.deepEqual(patterns, [
    '/product/*',
    '/p/*',
    '/user/*',
    '/collection/*',
    '/rooms/join/*',
    '/salons/*',
  ]);
  assert.equal(new Set(patterns).size, patterns.length);
  assert.ok(!patterns.some((pattern) => pattern.includes(':')));
});

// ── Escaping ────────────────────────────────────────────────────────────────

test('HTML escaping covers both text nodes and quoted attributes', () => {
  assert.equal(
    escapeHtml(`<img src="x" onerror='alert(1)'>&`),
    '&lt;img src=&quot;x&quot; onerror=&#39;alert(1)&#39;&gt;&amp;',
  );
});

test('JSON in a script block cannot end the script block', () => {
  const escaped = escapeJson({ caption: '</script><script>alert(1)</script>' });
  assert.ok(!escaped.includes('</script>'));
  assert.deepEqual(JSON.parse(escaped), {
    caption: '</script><script>alert(1)</script>',
  });
});

test('JSON escaping neutralises the two separators that are line breaks in JS', () => {
  const escaped = escapeJson({ caption: `a b c` });
  assert.ok(!escaped.includes(' '));
  assert.ok(!escaped.includes(' '));
  assert.deepEqual(JSON.parse(escaped), { caption: 'a b c' });
});

test('only http(s) reaches an href', () => {
  assert.equal(safeUrl('https://cdn.example.com/a.jpg'), 'https://cdn.example.com/a.jpg');
  assert.equal(safeUrl('javascript:alert(1)'), null);
  assert.equal(safeUrl('data:text/html;base64,PHN2Zz4='), null);
  assert.equal(safeUrl('   '), null);
  assert.equal(safeUrl(null), null);
});

test('only the scheme this app registered is treated as a deep link', () => {
  assert.equal(safeSchemeUrl('reem://home', 'reem'), 'reem://home');
  assert.equal(safeSchemeUrl('javascript://home', 'reem'), null);
});

// ── The page a crawler reads ────────────────────────────────────────────────

test('the preview tags a messenger reads carry the real values', () => {
  const html = renderProductPage({
    price: '145,000 ل.س',
    byline: 'بوتيك لمى',
  });

  assert.ok(html.includes('<meta property="og:title" content="فستان سهرة">'));
  assert.ok(
    html.includes('<meta property="og:description" content="حرير بنقشة وردية">'),
  );
  assert.ok(
    html.includes(
      '<meta property="og:image" content="https://cdn.example.com/dress.jpg">',
    ),
  );
  assert.ok(
    html.includes(
      '<meta property="og:url" content="https://links.example.com/product/abc">',
    ),
  );
  assert.ok(html.includes('<meta property="og:type" content="product">'));
  // Without this WhatsApp and Twitter draw a thumbnail beside the text rather
  // than the full-width card the photograph deserves.
  assert.ok(
    html.includes('<meta name="twitter:card" content="summary_large_image">'),
  );
  assert.ok(html.includes('145,000 ل.س'));
  assert.ok(html.includes('بوتيك لمى'));
});

test('a picture-less preview asks for the small card instead of the large one', () => {
  const html = renderProductPage({ imageUrl: null });
  assert.ok(html.includes('<meta name="twitter:card" content="summary">'));
  assert.ok(!html.includes('og:image'));
});

test('a title carrying markup cannot escape its meta tag', () => {
  const html = renderProductPage({
    title: '"><script>alert(1)</script>',
  });
  assert.ok(!html.includes('<script>alert(1)</script>'));
  assert.ok(html.includes('&quot;&gt;&lt;script&gt;'));
});

test('a media URL that is not http(s) is dropped rather than rendered', () => {
  const html = renderProductPage({ imageUrl: 'javascript:alert(1)' });
  assert.ok(!html.includes('javascript:'));
  assert.ok(!html.includes('og:image'));
});

test('the only script on the page carries the nonce, and the deep link is inside it', () => {
  const html = renderProductPage();
  const scripts = html.match(/<script(?![^>]*application\/ld\+json)[^>]*>/g) ?? [];
  assert.equal(scripts.length, 1);
  assert.ok(scripts[0].includes('nonce="n0nc3"'));
  assert.ok(html.includes('reem://product-details?id=abc'));
});

test('a product preview emits schema.org with a machine-readable price', () => {
  const html = renderProductPage({
    price: '145,000 ل.س',
    priceAmount: '145000.00',
    priceCurrency: 'SYP',
  });
  const match = html.match(
    /<script type="application\/ld\+json">(.*?)<\/script>/s,
  );
  assert.ok(match);
  const data = JSON.parse(match[1]) as Record<string, any>;
  assert.equal(data['@type'], 'Product');
  assert.equal(data.offers.price, '145000.00');
  assert.equal(data.offers.priceCurrency, 'SYP');
  assert.equal(data.offers.availability, 'https://schema.org/InStock');
});

test('a product nobody stocks says so, and says so in its structured data', () => {
  const html = renderProductPage({
    priceAmount: '145000.00',
    priceCurrency: 'SYP',
    unavailableNote: 'غير متوفر حالياً لدى أي بائعة',
  });
  assert.ok(html.includes('غير متوفر حالياً لدى أي بائعة'));
  assert.ok(html.includes('https://schema.org/OutOfStock'));
});

test('only a product gets product structured data', () => {
  const html = renderLandingPage({
    preview: preview({ kind: 'content', path: '/p/x', appRoute: '/content/x' }),
    canonicalUrl: 'https://links.example.com/p/x',
    schemeUrl: 'reem://content/x',
    nonce: 'n',
  });
  assert.ok(!html.includes('application/ld+json'));
  assert.ok(html.includes('<meta property="og:type" content="article">'));
});

test('a store link is offered when one is configured, and not invented when none is', () => {
  const withStore = renderLandingPage({
    preview: preview(),
    canonicalUrl: 'https://links.example.com/product/abc',
    schemeUrl: 'reem://product-details?id=abc',
    androidStoreUrl: 'https://play.google.com/store/apps/details?id=shop.reem.app',
    nonce: 'n',
  });
  assert.ok(withStore.includes('Google Play'));

  const withoutStore = renderProductPage();
  assert.ok(!withoutStore.includes('Google Play'));
  assert.ok(withoutStore.includes('التطبيق قيد الإطلاق'));
});

test('a dead link is a branded page that keeps itself out of the index', () => {
  const html = renderMessagePage({
    canonicalUrl: 'https://links.example.com/product/gone',
    headline: 'لم نجد هذا الرابط',
    detail: 'قد تكون البائعة أزالت هذا المنتج.',
    cta: { label: 'تصفّحي ريم', url: 'https://links.example.com/' },
  });
  assert.ok(html.includes('<meta name="robots" content="noindex">'));
  assert.ok(html.includes('لم نجد هذا الرابط'));
  assert.ok(html.includes('href="https://links.example.com/"'));
  assert.ok(html.includes('dir="rtl"'));
});

test('the site root is indexable and needs no call to action', () => {
  const html = renderMessagePage({
    canonicalUrl: 'https://links.example.com/',
    headline: 'ريم',
    detail: 'سوق نسائي.',
    cta: null,
    noindex: false,
  });
  assert.ok(html.includes('<meta name="robots" content="index, follow">'));
  assert.ok(!html.includes('class="cta"'));
});

// ── Association files ───────────────────────────────────────────────────────

test('assetlinks.json is empty rather than wrong until a fingerprint exists', () => {
  const service = new AppLinksService(
    config({
      'links.android.packageName': 'shop.reem.app',
      'links.android.fingerprints': [],
    }),
  );
  assert.deepEqual(service.assetLinks(), []);
});

test('assetlinks.json names the package and every fingerprint it was given', () => {
  const service = new AppLinksService(
    config({
      'links.android.packageName': 'shop.reem.app',
      'links.android.fingerprints': ['AA:BB', 'CC:DD'],
    }),
  );
  const [entry] = service.assetLinks() as any[];
  assert.deepEqual(entry.relation, ['delegate_permission/common.handle_all_urls']);
  assert.equal(entry.target.namespace, 'android_app');
  assert.equal(entry.target.package_name, 'shop.reem.app');
  // Both the upload key and Play's app-signing key, or store installs fail to
  // verify while the locally-built APK works.
  assert.deepEqual(entry.target.sha256_cert_fingerprints, ['AA:BB', 'CC:DD']);
});

test('the Apple association lists every path the app claims and no parameters', () => {
  const service = new AppLinksService(
    config({ 'links.ios.appIds': ['TEAM1234.shop.reem.app'] }),
  );
  const aasa = service.appleAppSiteAssociation() as any;
  assert.deepEqual(aasa.applinks.details[0].appIDs, ['TEAM1234.shop.reem.app']);
  const paths = aasa.applinks.details[0].components.map((c: any) => c['/']);
  assert.deepEqual(paths, appLinkPatterns());
  assert.ok(!paths.includes('/invite/*'));
});

test('an unconfigured Apple association is still a valid document', () => {
  const service = new AppLinksService(config({ 'links.ios.appIds': [] }));
  const aasa = service.appleAppSiteAssociation() as any;
  assert.deepEqual(aasa.applinks.details, []);
});

// ── Formatting ──────────────────────────────────────────────────────────────

test('a price is printed the way the app prints it', () => {
  assert.equal(
    formatMoney(new Prisma.Decimal('145000'), Currency.SYP),
    '145,000 ل.س',
  );
  assert.equal(
    formatMoney(new Prisma.Decimal('145000.4'), Currency.SYP),
    '145,000 ل.س',
  );
  assert.equal(formatMoney(new Prisma.Decimal('9.5'), Currency.USD), '$9.50');
});

test('counts abbreviate the way the cards do', () => {
  assert.equal(formatCount(0), '0');
  assert.equal(formatCount(999), '999');
  assert.equal(formatCount(1500), '1.5K');
  assert.equal(formatCount(2_400_000n), '2.4M');
});

test('a description is cut on a word boundary', () => {
  assert.equal(truncate('one two three', 40), 'one two three');
  assert.equal(truncate('aaaa bbbb cccc dddd', 14), 'aaaa bbbb…');
  // Whitespace of every kind collapses, so a caption full of newlines does not
  // arrive at a messenger as a wall of blanks.
  assert.equal(truncate('a  \n b', 40), 'a b');
});

test('an empty description falls back rather than leaving the tag blank', () => {
  assert.equal(summarise('   ', 'شاهدي هذه القطعة'), 'شاهدي هذه القطعة');
  assert.equal(summarise(null, 'بديل'), 'بديل');
  assert.equal(summarise('نص حقيقي', 'بديل'), 'نص حقيقي');
});

test('a malformed id resolves to nothing instead of throwing a JSON error', () => {
  assert.ok(isUuid('3f2504e0-4f89-11d3-9a0c-0305e82c3301'));
  assert.ok(!isUuid('not-a-uuid'));
  assert.ok(!isUuid(undefined));
});

test('a caption short enough to be the headline is not printed twice', () => {
  function page(body: string | null): string {
    return renderLandingPage({
      preview: preview({
        kind: 'content',
        title: 'ثلاث طرق لتنسيق الفستان',
        body,
        path: '/p/x',
        appRoute: '/content/x',
      }),
      canonicalUrl: 'https://links.example.com/p/x',
      schemeUrl: 'reem://content/x',
      nonce: 'n',
    });
  }

  // The caption is already the headline; printing it again as a paragraph put
  // the same sentence on the page twice.
  const echoed = page('ثلاث طرق لتنسيق الفستان');
  assert.ok(!echoed.includes('class="body"'));
  assert.equal(echoed, page(null));
});

test('a caption longer than the headline still gets its own paragraph', () => {
  const html = renderLandingPage({
    preview: preview({
      kind: 'content',
      title: 'ثلاث طرق',
      body: 'ثلاث طرق لتنسيق الفستان الحريري',
      path: '/p/x',
      appRoute: '/content/x',
    }),
    canonicalUrl: 'https://links.example.com/p/x',
    schemeUrl: 'reem://content/x',
    nonce: 'n',
  });
  assert.ok(html.includes('class="body"'));
});
