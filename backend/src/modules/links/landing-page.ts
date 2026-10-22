import { SharePreview } from './share-preview';

/**
 * The page a Reem link opens for somebody who is not inside the app.
 *
 * Hand-written HTML rather than a view engine. Three reasons, in order of how
 * much they mattered: a template engine is a dependency whose `views/`
 * directory has to be copied into the Docker image separately from `dist/` and
 * is exactly the kind of thing that works locally and 500s in production; this
 * page is one screen with no branching layout; and a string built here is
 * ordinary TypeScript that `landing-page.spec.ts` can assert against without
 * booting Nest.
 *
 * ## What the crawler needs, and what the browser needs
 *
 * They are different audiences reading the same document. WhatsApp, Telegram
 * and Facebook fetch this URL, read `<head>`, and never run a line of script —
 * so every Open Graph tag is rendered server-side with the real values. The
 * browser then gets the same document plus a stylesheet and one small script
 * whose only job is the «افتح في التطبيق» button.
 *
 * ## Why the button is not an automatic redirect
 *
 * Bouncing straight to `reem://…` on load looks clever and is hostile: on a
 * phone without the app, iOS shows a modal error and Android's WebView shows
 * `ERR_UNKNOWN_URL_SCHEME` — to a woman who has just been sent a dress by a
 * friend and has never heard of Reem. She gets the page; the app is one
 * obvious tap away.
 */

export interface LandingPageOptions {
  preview: SharePreview;
  /** Absolute canonical URL of this page. */
  canonicalUrl: string;
  /** `reem://…` — the fallback that works inside a messenger's browser. */
  schemeUrl: string;
  /** Where the app can be had. Any of them may be absent. */
  androidStoreUrl?: string;
  iosStoreUrl?: string;
  apkUrl?: string;
  /** CSP nonce for the single inline script. */
  nonce: string;
}

export interface MessagePageOptions {
  canonicalUrl: string;
  headline: string;
  detail: string;
  /** Omitted when the page has nowhere useful to send her — the root itself. */
  cta?: { label: string; url: string } | null;
  /**
   * A dead link should not enter a search index; the site root should. Both go
   * through this renderer, so which one it is has to be said rather than
   * assumed.
   */
  noindex?: boolean;
}

const BRAND = {
  rose: '#E85A8A',
  roseDeep: '#D43E73',
  roseInk: '#8C2549',
  blush: '#FFF8FB',
  blushCard: '#FFFFFF',
  blushEdge: '#F5EEF1',
  mauve: '#75487E',
  gold: '#E6C277',
  ink: '#221A1F',
  inkSoft: '#695761',
  inkFaint: '#897680',
};

/**
 * The tab icon, inline.
 *
 * A data URI rather than a file: this API serves no static assets outside the
 * media mount, so any `/favicon.ico` would be a 404 on every landing page —
 * and a browser tab showing a broken-document glyph beside a boutique's name is
 * the sort of small thing that reads as "this is not a real shop".
 */
const FAVICON =
  "data:image/svg+xml," +
  encodeURIComponent(
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">` +
      `<rect width="64" height="64" rx="16" fill="${BRAND.roseDeep}"/>` +
      `<circle cx="32" cy="26" r="11" fill="${BRAND.blush}"/>` +
      `<path d="M14 54c4-11 11-16 18-16s14 5 18 16z" fill="${BRAND.blush}"/>` +
      `</svg>`,
  );

/** Escapes text for an HTML text node or a double-quoted attribute. */
export function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/**
 * Escapes a value that is about to sit inside a `<script>` block as JSON.
 *
 * `escapeHtml` is wrong here — `&quot;` is not valid JSON — and a naive
 * `JSON.stringify` is unsafe, because the parser ends the script at the first
 * literal `</script>` wherever it appears, including inside a string.
 */
export function escapeJson(value: unknown): string {
  return JSON.stringify(value)
    .replace(/</g, '\\u003c')
    .replace(/>/g, '\\u003e')
    // U+2028 and U+2029 are line terminators in JavaScript but are legal,
    // unescaped, inside a JSON string — so a caption containing one would
    // end the statement mid-literal and take the whole page down with it.
    .replace(/[\u2028\u2029]/g, (char) =>
      char === '\u2028' ? '\\u2028' : '\\u2029',
    );
}

/**
 * Only `http(s)` survives.
 *
 * Everything rendered into an `href` here comes from configuration or from the
 * database, and a `javascript:` URL in either would be stored XSS on a page
 * that is deliberately unauthenticated and public.
 */
export function safeUrl(value: string | null | undefined): string | null {
  const url = value?.trim();
  if (!url) return null;
  return /^https?:\/\//i.test(url) ? url : null;
}

/** The custom scheme gets its own check: only the scheme this app registered. */
export function safeSchemeUrl(value: string, scheme: string): string | null {
  return value.startsWith(`${scheme}://`) ? value : null;
}

export function renderLandingPage(options: LandingPageOptions): string {
  const { preview, canonicalUrl, nonce } = options;
  const image = safeUrl(preview.imageUrl);
  const bylineImage = safeUrl(preview.bylineImageUrl);
  const stores = [
    options.androidStoreUrl && {
      label: 'Google Play',
      url: safeUrl(options.androidStoreUrl),
    },
    options.iosStoreUrl && {
      label: 'App Store',
      url: safeUrl(options.iosStoreUrl),
    },
    options.apkUrl && {
      label: 'تحميل مباشر (APK)',
      url: safeUrl(options.apkUrl),
    },
  ].filter((entry): entry is { label: string; url: string } =>
    Boolean(entry && entry.url),
  );

  const ogType = preview.kind === 'product' ? 'product' : 'article';

  const head = [
    `<title>${escapeHtml(preview.title)} — ريم</title>`,
    `<meta name="description" content="${escapeHtml(preview.description)}">`,
    `<link rel="canonical" href="${escapeHtml(canonicalUrl)}">`,
    `<meta property="og:site_name" content="ريم">`,
    `<meta property="og:type" content="${ogType}">`,
    `<meta property="og:locale" content="ar_SY">`,
    `<meta property="og:url" content="${escapeHtml(canonicalUrl)}">`,
    `<meta property="og:title" content="${escapeHtml(preview.title)}">`,
    `<meta property="og:description" content="${escapeHtml(preview.description)}">`,
    image ? `<meta property="og:image" content="${escapeHtml(image)}">` : '',
    image ? `<meta property="og:image:secure_url" content="${escapeHtml(image)}">` : '',
    image ? `<meta property="og:image:alt" content="${escapeHtml(preview.title)}">` : '',
    preview.priceAmount
      ? `<meta property="product:price:amount" content="${escapeHtml(preview.priceAmount)}">`
      : '',
    preview.priceCurrency
      ? `<meta property="product:price:currency" content="${escapeHtml(preview.priceCurrency)}">`
      : '',
    // Twitter reads its own namespace and falls back to Open Graph for the
    // rest. `summary_large_image` is what turns a thumbnail into a full-width
    // card — which is the difference between a link that sells and one that
    // looks like a pasted URL.
    `<meta name="twitter:card" content="${image ? 'summary_large_image' : 'summary'}">`,
    `<meta name="twitter:title" content="${escapeHtml(preview.title)}">`,
    `<meta name="twitter:description" content="${escapeHtml(preview.description)}">`,
    image ? `<meta name="twitter:image" content="${escapeHtml(image)}">` : '',
    // Belt and braces for iOS: a device that has the app and arrives here
    // anyway (an unverified Universal Link, a copy-pasted URL) gets Safari's
    // own banner offering to open it.
    `<meta name="apple-mobile-web-app-capable" content="yes">`,
    structuredData(preview, canonicalUrl, image),
  ]
    .filter(Boolean)
    .join('\n    ');

  const facts = (preview.facts ?? [])
    .map(
      (fact) =>
        `<li><span class="fact-value">${escapeHtml(fact.value)}</span><span class="fact-label">${escapeHtml(fact.label)}</span></li>`,
    )
    .join('');

  const priceRow = preview.price
    ? `<p class="price">${escapeHtml(preview.price)}${
        preview.compareAtPrice
          ? `<s>${escapeHtml(preview.compareAtPrice)}</s>`
          : ''
      }</p>`
    : '';

  const byline = preview.byline
    ? `<div class="byline">${
        bylineImage
          ? `<img src="${escapeHtml(bylineImage)}" alt="" loading="lazy" referrerpolicy="no-referrer">`
          : '<span class="byline-dot"></span>'
      }<span>${escapeHtml(preview.byline)}</span></div>`
    : '';

  const note = preview.unavailableNote
    ? `<p class="note">${escapeHtml(preview.unavailableNote)}</p>`
    : '';

  // A caption that is short enough to be the headline is *also* the body, and
  // printing both puts the same sentence on the page twice.
  const bodyText = preview.body?.trim();
  const body =
    bodyText && bodyText !== preview.title.trim()
      ? `<p class="body">${escapeHtml(bodyText)}</p>`
      : '';

  const storeRow = stores.length
    ? `<div class="stores"><span>لا يوجد التطبيق بعد؟</span>${stores
        .map(
          (store) =>
            `<a href="${escapeHtml(store.url)}" rel="noopener">${escapeHtml(store.label)}</a>`,
        )
        .join('')}</div>`
    : // Honest rather than decorative: an «حمّلي التطبيق» button pointing at a
      // store page that does not exist yet is a worse first impression than
      // saying so.
      `<div class="stores"><span>التطبيق قيد الإطلاق — تابعينا لتحميله قريباً.</span></div>`;

  const hero = image
    ? `<div class="hero${preview.imageIsPortrait ? ' hero-portrait' : ''}" id="hero">
        <img src="${escapeHtml(image)}" alt="${escapeHtml(preview.title)}" id="hero-image" referrerpolicy="no-referrer">
      </div>`
    : `<div class="hero hero-empty"><span>ريم</span></div>`;

  return `<!doctype html>
<html lang="ar" dir="rtl">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="${BRAND.rose}">
    <meta name="robots" content="index, follow">
    <link rel="icon" href="${FAVICON}">
    ${head}
    <style>${styles()}</style>
  </head>
  <body>
    <header class="topbar">
      <a class="wordmark" href="/">ريم</a>
      <span class="tagline">سوق نسائي للأزياء والجمال</span>
    </header>

    <main class="card">
      ${hero}
      <div class="detail">
        <p class="label">${escapeHtml(preview.label)}</p>
        <h1>${escapeHtml(preview.title)}</h1>
        ${priceRow}
        ${byline}
        ${note}
        ${facts ? `<ul class="facts">${facts}</ul>` : ''}
        ${body}

        <button class="cta" type="button" id="open-app">افتحي في تطبيق ريم</button>
        <p class="cta-hint" id="open-hint" hidden>لم يفتح التطبيق؟ ثبّتيه من الروابط بالأسفل.</p>
        ${storeRow}
      </div>
    </main>

    <footer class="footer">
      <a href="/">ريم — الصفحة الرئيسية</a>
      <span>© ريم</span>
    </footer>

    <script nonce="${escapeHtml(nonce)}">${openAppScript(options)}</script>
  </body>
</html>`;
}

export function renderMessagePage(options: MessagePageOptions): string {
  return `<!doctype html>
<html lang="ar" dir="rtl">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="theme-color" content="${BRAND.rose}">
    <link rel="icon" href="${FAVICON}">
    <title>${escapeHtml(options.headline)} — ريم</title>
    <meta name="description" content="${escapeHtml(options.detail)}">
    <meta name="robots" content="${options.noindex === false ? 'index, follow' : 'noindex'}">
    <meta property="og:site_name" content="ريم">
    <meta property="og:type" content="website">
    <meta property="og:locale" content="ar_SY">
    <meta property="og:url" content="${escapeHtml(options.canonicalUrl)}">
    <meta property="og:title" content="${escapeHtml(options.headline)}">
    <meta property="og:description" content="${escapeHtml(options.detail)}">
    <style>${styles()}</style>
  </head>
  <body>
    <header class="topbar">
      <a class="wordmark" href="/">ريم</a>
      <span class="tagline">سوق نسائي للأزياء والجمال</span>
    </header>
    <main class="card card-plain">
      <div class="detail">
        <p class="label">ريم</p>
        <h1>${escapeHtml(options.headline)}</h1>
        <p class="body">${escapeHtml(options.detail)}</p>
        ${
          options.cta && safeUrl(options.cta.url)
            ? `<a class="cta" href="${escapeHtml(options.cta.url)}">${escapeHtml(options.cta.label)}</a>`
            : ''
        }
      </div>
    </main>
    <footer class="footer">
      <a href="/">ريم — الصفحة الرئيسية</a>
      <span>© ريم</span>
    </footer>
  </body>
</html>`;
}

/**
 * `schema.org` in JSON-LD.
 *
 * Open Graph is what the messengers read; this is what a search engine and
 * Facebook's richer product card read. Cheap to emit and it is the difference
 * between a shared product appearing as an article and appearing as a product
 * with a price.
 */
function structuredData(
  preview: SharePreview,
  canonicalUrl: string,
  image: string | null,
): string {
  if (preview.kind !== 'product') return '';
  const data: Record<string, unknown> = {
    '@context': 'https://schema.org',
    '@type': 'Product',
    name: preview.title,
    description: preview.description,
    url: canonicalUrl,
    ...(image ? { image: [image] } : {}),
    ...(preview.byline ? { brand: { '@type': 'Brand', name: preview.byline } } : {}),
    ...(preview.priceAmount && preview.priceCurrency
      ? {
          offers: {
            '@type': 'Offer',
            price: preview.priceAmount,
            priceCurrency: preview.priceCurrency,
            url: canonicalUrl,
            availability: preview.unavailableNote
              ? 'https://schema.org/OutOfStock'
              : 'https://schema.org/InStock',
          },
        }
      : {}),
  };
  return `<script type="application/ld+json">${escapeJson(data)}</script>`;
}

/**
 * The one piece of behaviour on the page.
 *
 * Assigning `location.href` to a custom scheme either hands the tab to the app
 * — in which case this document is backgrounded and the timer never fires,
 * because `visibilitychange` clears it — or does nothing visible, in which case
 * the hint appears. The store links are already on the page either way, so
 * nothing here navigates her somewhere she did not ask to go.
 */
function openAppScript(options: LandingPageOptions): string {
  return `
(function () {
  var target = ${escapeJson(options.schemeUrl)};

  // A photograph that 404s — an external URL that has rotted, a file removed
  // from storage — otherwise leaves the browser's broken-image icon at the top
  // of a page a stranger was sent. The blush placeholder is the same one a
  // product with no picture at all gets.
  var hero = document.getElementById('hero');
  var heroImage = document.getElementById('hero-image');
  function dropHero() {
    if (!hero) return;
    hero.className = 'hero hero-empty';
    hero.innerHTML = '<span>ريم</span>';
  }
  if (heroImage) {
    heroImage.addEventListener('error', dropHero);
    // The error may have fired before this script ran.
    if (heroImage.complete && heroImage.naturalWidth === 0) dropHero();
  }

  var button = document.getElementById('open-app');
  var hint = document.getElementById('open-hint');
  if (!button) return;
  var timer = null;
  function stop() { if (timer) { clearTimeout(timer); timer = null; } }
  document.addEventListener('visibilitychange', function () {
    if (document.hidden) stop();
  });
  window.addEventListener('pagehide', stop);
  button.addEventListener('click', function () {
    stop();
    timer = setTimeout(function () {
      if (hint) hint.hidden = false;
    }, 1500);
    window.location.href = target;
  });
})();`;
}

function styles(): string {
  return `
:root {
  --rose: ${BRAND.rose};
  --rose-deep: ${BRAND.roseDeep};
  --rose-ink: ${BRAND.roseInk};
  --blush: ${BRAND.blush};
  --card: ${BRAND.blushCard};
  --edge: ${BRAND.blushEdge};
  --mauve: ${BRAND.mauve};
  --gold: ${BRAND.gold};
  --ink: ${BRAND.ink};
  --ink-soft: ${BRAND.inkSoft};
  --ink-faint: ${BRAND.inkFaint};
}
* { box-sizing: border-box; }
html, body { margin: 0; padding: 0; }
body {
  background: linear-gradient(180deg, var(--blush) 0%, #FCF0F5 100%);
  min-height: 100vh;
  color: var(--ink);
  font-family: "Segoe UI", "Noto Sans Arabic", "Dubai", "Tahoma", system-ui, sans-serif;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 16px;
}
.topbar {
  width: 100%;
  max-width: 900px;
  display: flex;
  align-items: baseline;
  gap: 12px;
  padding: 8px 4px 20px;
}
.wordmark {
  font-size: 26px;
  font-weight: 700;
  letter-spacing: 1px;
  color: var(--rose-deep);
  text-decoration: none;
}
.tagline { color: var(--ink-faint); font-size: 13px; }
.card {
  width: 100%;
  max-width: 900px;
  background: var(--card);
  border: 1px solid var(--edge);
  border-radius: 24px;
  overflow: hidden;
  box-shadow: 0 18px 48px rgba(140, 37, 73, 0.10);
  display: grid;
  grid-template-columns: 1fr;
}
.hero {
  background: #FCF0F5;
  aspect-ratio: 4 / 3;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}
.hero img { width: 100%; height: 100%; object-fit: cover; display: block; }
.hero-portrait { aspect-ratio: 4 / 5; }
.hero-empty {
  color: var(--rose);
  font-size: 44px;
  font-weight: 700;
  aspect-ratio: 16 / 7;
  background: linear-gradient(135deg, #FFE7EF 0%, #F1E5FF 100%);
}
.detail { padding: 22px 20px 26px; }
.card-plain { max-width: 560px; }
.label {
  margin: 0 0 8px;
  font-size: 12px;
  letter-spacing: 1px;
  color: var(--mauve);
  text-transform: none;
}
h1 { margin: 0 0 12px; font-size: 24px; line-height: 1.35; font-weight: 700; }
.price {
  margin: 0 0 14px;
  font-size: 23px;
  font-weight: 700;
  color: var(--rose-deep);
  display: flex;
  align-items: baseline;
  gap: 10px;
}
.price s { font-size: 15px; font-weight: 400; color: var(--ink-faint); }
.byline { display: flex; align-items: center; gap: 8px; margin-bottom: 12px; color: var(--ink-soft); font-size: 14px; }
.byline img { width: 28px; height: 28px; border-radius: 50%; object-fit: cover; }
.byline-dot { width: 8px; height: 8px; border-radius: 50%; background: var(--gold); }
.note {
  margin: 0 0 14px;
  padding: 10px 12px;
  border-radius: 12px;
  background: #FCF7EC;
  color: #79551F;
  font-size: 14px;
}
.facts { list-style: none; margin: 0 0 14px; padding: 0; display: flex; flex-wrap: wrap; gap: 10px; }
.facts li {
  background: #FFF5F8;
  border: 1px solid var(--edge);
  border-radius: 12px;
  padding: 8px 12px;
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.fact-value { font-weight: 700; font-size: 14px; }
.fact-label { font-size: 11px; color: var(--ink-faint); }
.body { margin: 0 0 20px; color: var(--ink-soft); line-height: 1.7; font-size: 15px; white-space: pre-wrap; }
.cta {
  display: block;
  width: 100%;
  border: none;
  border-radius: 16px;
  padding: 16px;
  font-size: 16px;
  font-weight: 700;
  font-family: inherit;
  color: #fff;
  background: linear-gradient(135deg, var(--rose) 0%, var(--rose-deep) 100%);
  cursor: pointer;
  text-align: center;
  text-decoration: none;
  box-shadow: 0 10px 24px rgba(212, 62, 115, 0.28);
}
.cta:active { transform: translateY(1px); }
.cta-hint { margin: 10px 0 0; font-size: 13px; color: var(--ink-faint); text-align: center; }
.stores {
  margin-top: 16px;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: center;
  gap: 10px;
  font-size: 13px;
  color: var(--ink-faint);
}
.stores a { color: var(--rose-deep); font-weight: 600; text-decoration: none; }
.stores a:hover { text-decoration: underline; }
.footer {
  width: 100%;
  max-width: 900px;
  display: flex;
  justify-content: space-between;
  padding: 18px 6px 8px;
  font-size: 12px;
  color: var(--ink-faint);
}
.footer a { color: var(--ink-faint); text-decoration: none; }
@media (min-width: 720px) {
  .card { grid-template-columns: 1fr 1fr; }
  .card-plain { grid-template-columns: 1fr; }
  .hero, .hero-portrait, .hero-empty { aspect-ratio: auto; height: 100%; min-height: 380px; }
  .detail { padding: 32px 30px; align-self: center; }
  h1 { font-size: 28px; }
}
`;
}
