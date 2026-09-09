# Delivery integration

Reem manages orders. A delivery company manages the journey.

That sentence is the whole design. The platform does not employ drivers, plan
routes, or run a fleet management system — a carrier already has one, and
building a second one inside a marketplace is building a business the client
decided not to be in. What Reem owns is the order: the money, the customer's
expectations, the return window, the seller's escrow. What a carrier owns is
the box, from the moment it is collected until it is delivered, refused or
returned.

Everything below exists to keep that line clean while making it possible to add
a carrier — or replace one — without touching the order system.

---

## Where things live

```
backend/src/modules/delivery/
├── providers/                       the carriers, behind one interface
│   ├── delivery-provider.interface.ts   createDelivery, cancelDelivery,
│   │                                    getDeliveryStatus, getTracking,
│   │                                    calculateDeliveryFee, handleWebhook
│   ├── delivery-provider.registry.ts    resolves an adapter by name
│   ├── delivery-status.map.ts           carrier words → Reem's lifecycle
│   ├── http-delivery.provider.ts        the generic HTTP adapter
│   ├── internal-courier.provider.ts     the in-house fleet, same interface
│   └── provider-credentials.service.ts  secrets, read from the environment
├── dispatch/                        choosing a carrier and living with one
│   ├── delivery-dispatch.service.ts     dispatch, cancel, refresh, apply
│   ├── delivery-webhook.controller.ts   POST /webhooks/delivery/:provider
│   ├── delivery-webhook.service.ts      record → verify → dedupe → apply
│   ├── delivery-admin.controller.ts     the operations desk
│   ├── delivery-admin.service.ts        carrier CRUD, without credentials
│   └── delivery-provider.bootstrap.ts   never be unable to move a parcel
├── shipments.service.ts             Reem's own record of the parcel
└── dto/delivery-provider.dto.ts     validation for the admin surface
```

The client's half is four fields on a screen: `lib/features/admin/.../admin_delivery_screen.dart`
for operations, and a carrier name plus tracking number on the buyer's order,
the tracking page and the seller's parcel. There is nothing else in the app —
no driver, no route, no carrier endpoint, no key.

## The data model

Three tables, deliberately separate from `shipments`:

| Table | Holds | Why separate |
| --- | --- | --- |
| `shipments` (existing) | Reem's record of the box: tracking code, cash due, proof, attempts, lifecycle | Everything downstream — returns, escrow, reviews, loyalty — already reads this. It must not change shape because a carrier did. |
| `delivery_provider_accounts` | A carrier: code, adapter, coverage, priority, capabilities, webhook scheme, non-secret config, **names** of credential variables | Changing carrier becomes a row, not a deploy |
| `delivery_dispatches` | One parcel with one carrier: their id, their tracking number, their fee, their timestamps, their failure, our idempotency key | Order data stays order data; a carrier's data can be dropped with the carrier |
| `delivery_webhook_events` | Every callback, verified or not, with its payload | Idempotency, and the answer when a carrier says "we told you" |

`delivery_dispatches.status` uses `ShipmentStatus` — the vocabulary the whole
platform already speaks — and `provider_status` keeps the carrier's own word
beside it. There is no second status enum to keep in step.

The canonical ladder is exactly the one the requirement names:

```
pending(CREATED) → assigned → picked_up → in_transit → out_for_delivery → delivered
                        ↘ failed ↘ returning → returned      ↘ cancelled
```

## The flow

1. **Checkout** opens a `Shipment` for every platform-carried parcel, as before.
2. **The seller marks it packed** (`POST /seller/orders/:id/ready`). That call
   now ends in `DeliveryDispatchService.dispatch()`.
3. **Dispatch chooses a carrier**: enabled, covering that governorate, lowest
   priority number, default breaking a tie. The dispatch row is written *before*
   the carrier is called and keyed on the shipment, so no double click, retry or
   redelivered job can create two parcels; the same key is sent as the carrier's
   idempotency header.
4. **The carrier reports back** to `POST /webhooks/delivery/:code`. The body is
   recorded first, then the signature is verified against the raw bytes, then
   the carrier's own event id is used to ignore redeliveries, and only then is
   the status applied.
5. **Applying a status** goes through `ShipmentsService.applyCarrierStatus`,
   which is the *same* code the courier screens use. A delivery reported by
   webhook books the cash, settles commission, opens the return window and
   closes the COD trust loop exactly as a rider's tap does.

A carrier being down never costs the seller anything: `ready()` succeeds, the
dispatch row records the error, and the parcel waits in the admin's retry queue.

## Production concerns, and where each is handled

| Concern | Where |
| --- | --- |
| Idempotency | `delivery_dispatches.idempotency_key`, unique, derived from the shipment; sent as the carrier's idempotency header |
| Duplicate callbacks | `(provider_code, external_event_id)` unique; plus a forward-only status guard for carriers that send no event id |
| Out-of-order callbacks | `isForwardDeliveryStatus` — a parcel never walks backwards on the customer's screen |
| Signature verification | Per account: HMAC-SHA256 over the raw body, or a shared secret, compared in constant time. Unsigned callbacks are refused unless an account opts in explicitly (sandbox only) |
| Timeouts | Per account (`config.timeoutMs`, default 10s), enforced with `AbortController` |
| Retries | Bounded, exponential with jitter, only on transport faults and 5xx/429 — a carrier's own refusal is never retried |
| Credentials | Named in the database, read from the environment, never returned by any route, never in the app |
| Logging | Request/response stored redacted; anything key-shaped is replaced before it is written or logged |
| Authorization | Admin routes require `order:manage` and SUPER_ADMIN/OPERATIONS_ADMIN; the webhook is public and authenticated by signature alone |
| Data consistency | Status changes go through the shipment's own transition table inside a transaction; money-moving side effects stay outside it and are idempotent |
| Graceful failure | Dispatch failure never rolls back a seller's "packed"; a status the parcel refuses is recorded on the dispatch for ops rather than thrown away |

## Adding a real carrier

Nothing in the code changes.

1. Put its credentials in the environment, under any names you like.
2. `POST /admin/delivery/providers` with `adapter: "http_generic"`, the base URL
   and paths in `config`, and those variable names in `credential_env_keys`.
3. Give the carrier the callback URL from the response
   (`/webhooks/delivery/<code>`) and its signing secret.
4. Enable it. The server refuses to enable a carrier it cannot actually reach.

If the carrier's payloads do not fit the generic adapter's shape, subclass
`HttpDeliveryProvider`, override the two or three methods that differ, and list
the class in `DeliveryModule`. Nothing outside `modules/delivery/` changes
either way.

## Proof

* `providers/delivery-status.map.spec.ts` — the mapping, including that an
  unknown word maps to *nothing* rather than to a guess.
* `providers/http-delivery.provider.spec.ts` — signature verification, batch
  payloads, carrier-specific status words.
* `dispatch/delivery-integration.integration.spec.ts` — a carrier's callbacks
  landing on a real order: delivery books the cash once, a redelivery changes
  nothing, a late event cannot walk the parcel backwards, a refusal restocks.
* `scripts/delivery-e2e.mjs` — the whole loop against a running API with a
  sandbox carrier: register, dispatch over HTTP, signed callbacks through to
  delivered, unsigned refused, duplicates ignored, ops queue readable.
