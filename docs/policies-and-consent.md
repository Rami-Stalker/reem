# Policies and consent

A consent is only worth something if the text it was given against can still be
produced.

That sentence is the whole design. Everything below — the version table, the
frozen published row, the hash carried onto every acceptance, the refusal to
edit a live document — exists so that "she agreed to this" is a claim the
platform can still substantiate in two years, in front of somebody who does not
take our word for it.

The second requirement, from the client, is that the terms must be changeable
**without shipping an app**. The eight documents are rows, an administrator
edits and publishes them from the console, and every phone shows the new text
on its next read.

---

## The eight documents

| Kind | Slug | Who must sign | Required at sign-up |
| --- | --- | --- | --- |
| `CUSTOMER_TERMS` | `customer-terms` | Shoppers | yes |
| `SELLER_TERMS` | `seller-terms` | Sellers | yes |
| `PRIVACY` | `privacy` | Everyone | yes |
| `RETURNS` | `returns` | Everyone | no |
| `COMMISSIONS` | `commissions` | Sellers | yes |
| `DISPUTES` | `disputes` | Everyone | no |
| `LIABILITY` | `liability` | Everyone | no |
| `CONTENT` | `content` | Everyone | no |

"Who must sign" is `PolicyAudience`. It decides **whose signature is required**,
never who may read — every published policy is readable by anyone, signed in or
not, because a policy behind a login is not a published policy. A shopper who
wants to read the commissions policy before she trusts a boutique can.

Four are required at sign-up and that is a deliberate minimum: a form demanding
eight separate signatures is a form nobody reads. Both columns are editable from
the console without a deploy.

**The text itself is a first draft, not a legal opinion.** It was written from
how this platform actually behaves — seven days from delivery, ten per cent on
the post-discount item total, earnings held until the return window closes, a
removal that always carries a reason — rather than from a boilerplate template
describing some other marketplace. Every number in it is a number the code
enforces. It still needs a lawyer's pass, and the whole point of the subsystem
is that the pass lands as an edit in the console rather than as a release.

---

## Where things live

```
backend/src/modules/policies/
├── policy-content.ts            the eight, as first published (ar + en)
├── policy.bootstrap.ts          writes what is missing, on boot, idempotently
├── policies.service.ts          reading, and recording a signature
├── policies.controller.ts       /policies — open, except accept/pending
├── policy-admin.service.ts      drafts, publishing, the frozen-version rule
├── policy-admin.controller.ts   /admin/policies — behind policy:manage
└── dto/                         validation for both surfaces

lib/features/policies/
├── domain/entities/             PolicySummary, PolicyDetail, PolicyReceipt
├── data/datasources/            the reads, and the console's writes
├── presentation/providers/      catalogue, detail, required, pending, receipts
├── presentation/screens/        centre, detail, consent gate, admin desk
└── presentation/widgets/        the consent field, the receipts sheet, editor

lib/core/design_system/components/typography/ds_rich_text.dart
                                 the restricted-Markdown renderer
```

---

## The data model

```
PolicyDocument ── PolicyDocumentVersion ── PolicyDocumentTranslation
       │                    │
       └── PolicyAcceptance ┘
```

- **`PolicyDocument`** carries nothing a reader sees — no title, no body. Those
  belong to the translation, because the name of a policy can change with its
  text and a title pinned outside its versions starts lying the first time legal
  renames one.
- **`PolicyDocumentVersion`** is one issue. `DRAFT` is editable and invisible
  outside the console. `PUBLISHED` is frozen. `ARCHIVED` is what the previous
  published version becomes, and stays readable forever so an acceptance
  recorded against it can still be shown to the woman who made it.
- **`PolicyDocumentTranslation`** is one version in one language, with the
  SHA-256 of its body at publication.
- **`PolicyAcceptance`** is a signature: account, version, locale, hash,
  source, moment, and the address it came from. Append-only — no route updates
  or deletes one. Withdrawing consent is closing the account, which is a
  different operation with a different record.

Three rules are enforced in `PolicyAdminService` rather than trusted to a
careful operator:

1. **A published version is immutable.** Every write refuses anything that is
   not a draft.
2. **One draft at a time, per document.** Two people editing two drafts and each
   publishing theirs is how a clause silently reverts.
3. **Exactly one published version per document.** Publishing archives its
   predecessor in the same transaction, so no reader ever sees a document with
   two current texts or none.

---

## Consent

### At registration

`GET /policies/required?role=buyer|seller` is **open** — it has to be, because
the form needs to name the documents before there is a session to authorise the
question with. The screen shows one checkbox above links to each document, and
`POST /auth/register` carries `accepted_policy_version_ids`.

The server checks that every required document's *currently published* version
id is in that list, and refuses with `POLICY_CONSENT_REQUIRED` (422) naming the
ones that are missing. Version ids rather than a boolean, because a record that
says `accepted: true` cannot answer "agreed to what".

It **fails open** in two cases.

When no policies are published at all: a platform nobody can register for is a
worse failure than an hour of accounts that signed nothing.

And when the field is **absent entirely**, which is what an app build older than
this feature sends. The API deploys days before a store rollout reaches every
handset, so refusing those requests would mean nobody on the shipped build could
create an account until she updated. An old client is not withholding consent —
it does not know the question exists. The account is recorded unsigned and meets
the consent gate on its next launch, which is the case that gate exists for.

An empty array is **not** the same thing. A client that sends the field has been
asked, and an answer covering nothing is refused. `undefined` is "did not know";
`[]` is "said no". `policies.integration.spec.ts` pins that distinction, because
it is one `??` away from regressing.

### When a customer becomes a seller

`POST /auth/seller-verification` takes the same field and requires the seller
audience. This is the only honest moment to ask: at registration those documents
did not address her, and after approval she is already selling.

### The gate

`GET /policies/pending` answers what an account still owes a signature on. Two
things put a document there, and only two:

- she has **never** accepted it and it is required for her side of the
  marketplace — which is every account that predates this subsystem; or
- the published version was published with `requiresReacceptance`, and her
  signature is against an older one.

A version published *without* that flag deliberately does not appear.
Interrupting a hundred thousand women to re-sign a comma is how a consent gate
becomes something people learn to tap through without reading. The console asks
the question at publish time, and it is required rather than defaulted so that
publishing is always a decision about whether the change is material.

`AppChrome` renders `PolicyConsentScreen` **instead of** the app's navigator
when the list is non-empty — not as an overlay and not as a route, so there is
no back gesture, deep link or notification tap that can get behind it. The gate
carries its own `Navigator` (there is no other one while it is up) so the full
text of each document opens from inside it. Signing out is offered as the honest
alternative to agreeing.

It fails open on a network error: this gates the whole app, and a five-second
blip must not be able to lock a woman out of Ohara.

### Her receipts

`GET /policies/acceptances` returns what she agreed to, which version, and when.
The policy centre surfaces it, and each row opens **the text she signed** by
version id — an archived document the centre no longer lists. A receipt showing
today's terms would prove nothing.

---

## Where policies surface in the app

| Surface | What it links to |
| --- | --- |
| Settings → Support | the policy centre |
| Buyer profile menu → Support | the policy centre |
| Seller profile menu → Support | the policy centre |
| Registration form | the documents required for the chosen role |
| Seller application | seller terms + commissions |
| Checkout, under the summary | customer terms + returns policy |
| Order detail, under the actions | disputes + returns |
| Return request screen | the returns policy |
| Content composer, under Publish | content and removal policy |
| Seller earnings, under the statement | commissions policy |
| Admin console → Policies | the editing desk |

None of the customer-facing entries requires a session.

The rule behind that list: a policy is linked from **the screen where the
question it answers is actually asked** — «كم يوم عندي أرجّع؟» at the till,
«ليش انحذف منشوري؟» in the composer, «ليش أرباحي محجوزة؟» on the statement.
A policy centre alone satisfies the letter of "the terms are available" and
almost nothing of its purpose. `PolicyNotice` and `PolicyLink`
(`lib/features/policies/presentation/widgets/policy_link.dart`) are the one
shared shape all of these use, and `PolicySlugs` keeps the six link targets
from being six string literals that can each rot separately.

---

## The console

`/admin/policies`, behind `policy:manage` — a permission held by `SUPER_ADMIN`
and `OPERATIONS_ADMIN` and nobody else. Deliberately not `content:manage`, which
every seller holds: publishing a version of the terms of use changes the
contract with every account, and that is not a content-moderation action.

Six operations: edit a document's switches (audience, required-at-sign-up,
visibility), open a draft, edit the draft in both languages, publish it, discard
it, and read how far a published version has landed across the population.

A new draft **clones the published text** by default. Amending one clause must
not mean retyping the document, which is where a clause goes missing.

Every write is recorded by `AdminAuditInterceptor` — actor, route, document,
outcome — without this module asking. The bodies are not recorded: they are
already versioned rows, and the audit trail is not a second copy of the terms.

---

## Rollout notes

- **Applied to Supabase on 2026-09-16** via `npm run db:pooled:deploy` —
  `prisma migrate deploy` hangs over the transaction pooler, which is what
  `scripts/migrate-pooled.mjs` exists for. Verified afterwards: four tables,
  three enums, permissions 33 → 34, `policy:manage` granted to `SUPER_ADMIN`
  and `OPERATIONS_ADMIN`, 105 user rows untouched, RLS on and no `anon` /
  `authenticated` grants on any of the four — the consent rows carry an IP
  address and a user agent and must not be reachable from the Data API.
- **The schema is ahead of the code, deliberately.** Every statement is
  additive, so the running API — which does not yet have `PoliciesModule` —
  is unaffected, and `policy_documents` stays empty until the next deploy
  boots `PolicyBootstrap`. That same deploy is when the consent gate goes
  live for every existing account.
- The migration `20260916160000_policy_centre` creates the four tables **and
  inserts the `policy:manage` permission with its two role grants**.
  `resolvePermissions` reads the RBAC tables and only falls back to the code
  defaults when a role has no rows at all — so on an already-seeded database a
  permission that existed only in TypeScript would be a permission nobody holds
  and a console screen that could only answer 403.
- `PolicyBootstrap` publishes version 1 of any document that is missing, on
  boot, idempotently. It never touches a document that already exists, so an
  administrator's edits survive every deploy.
- **Existing accounts will meet the consent gate on their next launch**, because
  "never signed at all" counts as outstanding. That is intentional for a
  pre-launch platform — it ends with a consent on file for everybody — but it is
  the one behaviour to be aware of before deploying to a live user base.
- The `/policies` reads are cached for six hours, cache-first, keyed by locale,
  so the returns policy opens on a dead connection. `/policies/pending` and
  `/policies/acceptances` are explicitly excluded: one decides whether the app
  is usable and the other is a legal receipt.

---

## Authoring format

Policy bodies are a deliberately small Markdown subset, rendered by
`DsRichText`:

```
## Heading            a section title
### Heading           a sub-heading
- item                a bullet
1. item               a numbered item
| a | b |             a table row; a row of dashes is the header rule
---                   a horizontal rule
**bold**              bold, inline, anywhere
(blank line)          a paragraph break
```

Anything else renders as a paragraph, which is the right failure: an editor who
types a `>` quote gets her text, not an error and not a missing clause.

The subset is a trust boundary, not a convenience. Whatever the renderer can
express, somebody with console access can put on a hundred thousand screens — a
general Markdown renderer expresses raw HTML, remote images and links, which is
a tracking pixel, an off-platform payment link or a spoofed sign-in form.
Nothing this one can draw fetches anything or goes anywhere.

The Arabic is the binding text and the English is a courtesy translation; the
documents say so themselves, because a marketplace whose customers and sellers
are Syrian is not entering an English contract with them.

## Deleting an account

What the content policy promises ("When your account is deleted…") is
implemented by `AccountDeletionService` behind `POST /auth/account/delete`.
It takes the enrolled device's signature, an AAL3 step-up (scope
`account_deletion`, so the 24-hour new-device cooldown applies) and
`confirm: true` in the body. The app reaches it from the bottom of the
security centre.

`GET /auth/account/deletion` is asked first, so she is never sent through a
second factor only to be refused. It is refused while deleting would strand
somebody: a parcel still moving to or from her, a wallet balance, a pending
payout, an upcoming appointment. Staff accounts are closed by an admin.

The `users` row is kept, because orders, invoices, the ledger and payouts
point at it, and emptied: name «حساب محذوف», no phone (free to register
again), email, photo, bio or password, `disabled_at` and `deleted_at` set. An
admin cannot re-enable or re-role it. Every session, device, credential and
push token goes. Addresses, saved payment methods, basket, favourites,
wishlists, search history, follows, notifications and the stylist profile are
deleted. Her posts are marked `DELETED` and comments `REMOVED`. Reviews she
wrote stay under the anonymous name. Chat messages she sent stay in the other
person's conversation. Audit and security logs are kept, under their own
retention.

Not yet covered: the files she uploaded (photos and videos behind her posts)
are no longer shown anywhere, but are not yet erased from storage.
