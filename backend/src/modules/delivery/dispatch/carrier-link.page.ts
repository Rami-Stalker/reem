/**
 * The driver link's page: one self-contained HTML file, Arabic and
 * right-to-left, built for a cheap phone on a weak connection. It reads the
 * parcel from `<this url>/parcel` and posts each step to `<this url>/<step>`.
 * Everything it shows is set with `textContent`, never parsed as HTML.
 */
export function carrierLinkPage(nonce: string): string {
  return `<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>توصيل طلب</title>
<style>
  :root { --bg:#faf7f5; --card:#fff; --ink:#1d1a19; --muted:#6f6763; --line:#e9e2de;
          --brand:#9b3d5a; --ok:#1f7a4d; --bad:#b3261e; }
  @media (prefers-color-scheme: dark) {
    :root { --bg:#151312; --card:#201d1c; --ink:#f3eeeb; --muted:#a9a09b; --line:#35302e;
            --brand:#e08aa4; --ok:#5cc28f; --bad:#f2827a; }
  }
  * { box-sizing: border-box; }
  body { margin:0; background:var(--bg); color:var(--ink);
         font: 16px/1.5 system-ui, -apple-system, "Segoe UI", Tahoma, sans-serif; }
  main { max-width: 520px; margin: 0 auto; padding: 16px; }
  h1 { font-size: 20px; margin: 4px 0 12px; }
  .card { background:var(--card); border:1px solid var(--line); border-radius:14px; padding:14px; margin-bottom:12px; }
  .label { color:var(--muted); font-size:13px; }
  .big { font-size: 22px; font-weight: 700; }
  .row { display:flex; gap:8px; flex-wrap:wrap; }
  a.pill { display:inline-block; padding:8px 12px; border-radius:999px; border:1px solid var(--line);
           color:var(--ink); text-decoration:none; }
  button { width:100%; padding:14px; margin-top:8px; border:0; border-radius:12px; font-size:17px;
           font-weight:600; background:var(--brand); color:#fff; }
  button.secondary { background:transparent; color:var(--ink); border:1px solid var(--line); }
  button.danger { background:var(--bad); }
  button:disabled { opacity:.5; }
  input, select { width:100%; padding:12px; font-size:18px; border-radius:10px; border:1px solid var(--line);
                  background:var(--bg); color:var(--ink); margin-top:6px; }
  #code { letter-spacing: 8px; text-align:center; font-size:26px; }
  .msg { padding:12px; border-radius:10px; margin-bottom:12px; display:none; }
  .msg.err { display:block; background:color-mix(in srgb, var(--bad) 15%, transparent); color:var(--bad); }
  .msg.ok { display:block; background:color-mix(in srgb, var(--ok) 15%, transparent); color:var(--ok); }
  .hidden { display:none; }
</style>
</head>
<body>
<main>
  <h1 id="title">جارٍ التحميل…</h1>
  <div id="msg" class="msg"></div>

  <section id="parcel" class="hidden">
    <div class="card">
      <div class="label">الحالة</div>
      <div id="status" class="big"></div>
      <div class="label" id="tracking"></div>
    </div>

    <div class="card" id="cod-card">
      <div class="label">المبلغ المطلوب تحصيله</div>
      <div id="cod" class="big"></div>
    </div>

    <div class="card" id="pickup-card">
      <div class="label">الاستلام من</div>
      <div id="pickup-name"></div>
      <div id="pickup-location" class="label"></div>
      <div class="row" id="pickup-actions"></div>
    </div>

    <div class="card" id="recipient-card">
      <div class="label">التسليم إلى</div>
      <div id="recipient-name" class="big"></div>
      <div id="address"></div>
      <div id="instructions" class="label"></div>
      <div class="row" id="recipient-actions" style="margin-top:8px"></div>
    </div>

    <div class="card" id="actions"></div>
  </section>
</main>
<script nonce="${nonce}">
(function () {
  var base = location.pathname.replace(/\\/+$/, '');
  var STATUS = {
    created: 'بانتظار الاستلام من المتجر', assigned: 'بانتظار الاستلام من المتجر',
    picked_up: 'استُلم من المتجر', in_transit: 'في الطريق', out_for_delivery: 'في الطريق إلى الزبونة',
    failed: 'محاولة تسليم فاشلة', delivered: 'تم التسليم ✓', returning: 'راجع للمتجر',
    returned: 'أُعيد للمتجر', cancelled: 'ملغى'
  };
  var REASONS = [
    ['NO_ANSWER', 'الزبونة لا ترد'], ['WRONG_ADDRESS', 'العنوان خاطئ'],
    ['CUSTOMER_REFUSED', 'رفضت الاستلام'], ['POSTPONED', 'طلبت التأجيل'],
    ['UNREACHABLE_AREA', 'منطقة لا يمكن الوصول إليها'], ['OTHER', 'سبب آخر']
  ];
  var $ = function (id) { return document.getElementById(id); };
  var parcel = null;

  function el(tag, text, cls) {
    var n = document.createElement(tag);
    if (text != null) n.textContent = text;
    if (cls) n.className = cls;
    return n;
  }
  function link(href, text) { var a = el('a', text, 'pill'); a.href = href; a.rel = 'noopener'; return a; }
  function say(text, ok) { var m = $('msg'); m.textContent = text; m.className = 'msg ' + (ok ? 'ok' : 'err'); }
  function money(m) {
    if (!m) return '';
    var n = Number(m.amount);
    var cur = m.currency === 'SYP' ? 'ل.س' : (m.currency === 'USD' ? '$' : (m.currency || ''));
    var digits = m.currency === 'SYP' ? 0 : 2;
    return (isFinite(n) ? n.toLocaleString('ar-SY', { maximumFractionDigits: digits }) : m.amount) + ' ' + cur;
  }

  function load() {
    fetch(base + '/parcel', { headers: { Accept: 'application/json' } })
      .then(function (r) { return r.json().then(function (b) { return { ok: r.ok, body: b }; }); })
      .then(function (res) {
        if (!res.ok) throw new Error((res.body && res.body.message) || 'الرابط غير صالح');
        parcel = res.body.data || res.body;
        render();
      })
      .catch(function (e) { $('title').textContent = 'تعذّر فتح الطلب'; say(e.message); });
  }

  function render() {
    $('title').textContent = 'طلب رقم ' + parcel.order_number;
    $('parcel').classList.remove('hidden');
    $('status').textContent = STATUS[parcel.status] || parcel.status;
    $('tracking').textContent = 'رمز التتبع: ' + parcel.tracking_code;

    $('cod-card').classList.toggle('hidden', !parcel.cod_amount);
    $('cod').textContent = parcel.cod_amount ? money(parcel.cod_amount) : '';

    var p = parcel.pickup, r = parcel.recipient;
    $('pickup-card').classList.toggle('hidden', !p);
    $('recipient-card').classList.toggle('hidden', !r);
    if (p) {
      $('pickup-name').textContent = p.name || '';
      $('pickup-location').textContent = p.location || '';
      var pa = $('pickup-actions'); pa.replaceChildren();
      if (p.phone) pa.appendChild(link('tel:' + p.phone, '📞 اتصال بالمتجر'));
    }
    if (r) {
      $('recipient-name').textContent = r.name || '';
      $('address').textContent = [r.governorate, r.city, r.district, r.address_line, r.landmark]
        .filter(Boolean).join('، ');
      $('instructions').textContent = r.delivery_instructions || '';
      var ra = $('recipient-actions'); ra.replaceChildren();
      if (r.phone) {
        ra.appendChild(link('tel:' + r.phone, '📞 اتصال'));
        ra.appendChild(link('https://wa.me/' + String(r.phone).replace(/\\D/g, ''), 'واتساب'));
      }
      if (r.latitude != null && r.longitude != null) {
        ra.appendChild(link('https://maps.google.com/?q=' + r.latitude + ',' + r.longitude, '📍 الخريطة'));
      }
    }
    renderActions();
  }

  function renderActions() {
    var box = $('actions'); box.replaceChildren();
    var steps = parcel.available_steps || [];
    box.classList.toggle('hidden', steps.length === 0);

    if (steps.indexOf('pick_up') >= 0) box.appendChild(button('استلمت الطلب من المتجر', function () { send('pick_up', {}); }));
    if (steps.indexOf('out_for_delivery') >= 0) box.appendChild(button('أنا في الطريق إلى الزبونة', function () { send('out_for_delivery', {}); }, 'secondary'));

    if (steps.indexOf('deliver') >= 0) {
      box.appendChild(el('div', parcel.handover_code_required
        ? 'اطلب من الزبونة رمز الاستلام (٤ أرقام) — مطلوب لهذا الطلب'
        : 'اطلب من الزبونة رمز الاستلام (٤ أرقام)', 'label'));
      var code = el('input'); code.id = 'code'; code.inputMode = 'numeric'; code.maxLength = 4; code.autocomplete = 'one-time-code';
      box.appendChild(code);
      var collected = null;
      if (parcel.cod_amount) {
        box.appendChild(el('div', 'المبلغ المحصَّل (اتركه فارغًا إن حصّلت المبلغ كاملًا)', 'label'));
        collected = el('input'); collected.inputMode = 'decimal'; box.appendChild(collected);
      }
      box.appendChild(button('تم التسليم', function () {
        var body = { handover_code: code.value.trim() || undefined };
        if (collected && collected.value.trim()) body.collected = collected.value.trim();
        send('deliver', body);
      }));
    }

    if (steps.indexOf('fail') >= 0) {
      var sel = el('select');
      REASONS.forEach(function (r) { var o = el('option', r[1]); o.value = r[0]; sel.appendChild(o); });
      var failBox = el('div', null, 'hidden');
      failBox.appendChild(el('div', 'سبب عدم التسليم', 'label'));
      failBox.appendChild(sel);
      failBox.appendChild(button('تأكيد فشل التسليم', function () { send('fail', { reason: sel.value }); }, 'danger'));
      box.appendChild(button('لم أتمكن من التسليم', function () { failBox.classList.toggle('hidden'); }, 'secondary'));
      box.appendChild(failBox);
    }
  }

  function button(text, onClick, cls) {
    var b = el('button', text, cls); b.type = 'button';
    b.addEventListener('click', function () { onClick(b); });
    return b;
  }

  function send(step, body) {
    var buttons = document.querySelectorAll('button');
    buttons.forEach(function (b) { b.disabled = true; });
    fetch(base + '/' + step, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify(body)
    })
      .then(function (r) { return r.json().then(function (b) { return { ok: r.ok, body: b }; }); })
      .then(function (res) {
        if (!res.ok) {
          var m = res.body && (res.body.message || (res.body.error && res.body.error.message));
          throw new Error(Array.isArray(m) ? m.join('، ') : (m || 'تعذّر الحفظ'));
        }
        parcel = res.body.data || res.body;
        say('تم الحفظ ✓', true);
        render();
      })
      .catch(function (e) { say(e.message); buttons.forEach(function (b) { b.disabled = false; }); });
  }

  load();
})();
</script>
</body>
</html>`;
}
