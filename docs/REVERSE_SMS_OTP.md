# Reverse-SMS one-time codes (SYROTP)

The platform's primary proof of a phone number is now a message she **sends**,
not one she receives. This describes the rail, why it is first, what it costs,
and what is still true of the old one.

## The problem it solves

`OtpDeliveryStatus` in `schema.prisma` already names the failure this market
turns on:

> `SENT` means the provider accepted the message. `DELIVERED` means a receipt
> said it reached the handset. The gap between those two is the dominant Syrian
> failure mode — accepted, never delivered.

No transport can close that gap, because the loss happens downstream of every
transport the platform could contract. A reverse ceremony removes the outbound
leg altogether: there is nothing to accept and lose. It also needs no
aggregator contract, which under sanctions is the other thing that can be
taken away — and it ends the attack `matchCode` was standing in for, because a
code that travels *from* her handset cannot be recited to her by somebody
claiming to be support.

## How a ceremony runs

[SYROTP](https://github.com/SYR-ROOT/syrotp) is self-hosted: a Node/Postgres
server plus a receiver gateway, which is an Android phone with a local SIM or a
USB GSM modem. The platform talks to the server; the gateway forwards inbound
messages to it.

1. `OtpService.request` asks `ReverseSmsService` to open a ceremony.
2. The provider answers a receiver number and an exact body —
   `VERIFY 763PM5`, or `BIND <nonce>` the first time a number is seen.
3. The challenge row is written with `delivery_mode = REVERSE_SMS` and the
   provider's `vrf_…` / `pbn_…` id. Nothing is queued: the outbox is for
   outbound messages and there is no outbound message.
4. She sends that body from her handset. The gateway forwards it. The provider
   checks the inbound sender against the number she claimed.
5. The client polls `POST /auth/otp/reverse/status`, then settles the challenge
   with `POST /auth/otp/login/reverse` — which takes no code, because there is
   none to take.

### Why a binding comes first

Since the provider's v0.8 a verification needs a `verified` phone-binding row
for `(app, phone)` and refuses `phone_not_bound` otherwise, with no soft mode.
So the first reverse challenge a number ever sees is a binding, and every later
one is a verification. Both are settled by one inbound message whose sender is
checked, so they establish the same fact — which is why a binding is allowed to
settle the challenge that opened it rather than asking her to send a second
message for no extra assurance.

## What keeps it safe

- **The row cannot be settled by a code.** `codeHash` on a reverse row is a
  digest of 256 random bits that are discarded immediately, and `verify` filters
  reverse rows out of its query. There is no code that satisfies it.
- **One ceremony, one challenge.** `reverse_ref` is unique in the database.
- **Spent once.** The claim is a conditional `updateMany` on
  `status = PENDING`, so two requests racing on one verified ceremony cannot
  both come away with a session.
- **The nonce still applies.** A verified ceremony presented by an install that
  cannot produce the challenge's `client_nonce` is refused and counted.
- **Polling costs nothing.** `reverseStatus` spends no attempt, so a client on
  a timer cannot exhaust the budget that protects the challenge.
- **A provider outage never tears a ceremony down.** An unreachable provider
  reads as `pending`, not as expired.

## Where it is not first

- **Named test accounts** keep their fixed codes: the point of those is to sign
  in with no provider in the loop.
- **A provider that cannot be reached at request time** falls through to the
  transport chain, so an outage is a slower sign-in rather than a refused one.
  `SYROTP_PRIMARY=false` makes that the standing arrangement without a code
  change.
- **TOTP and recovery codes** are unchanged. Those are secrets she holds, and
  `consumeFactor` still refuses an absent code for both.

Every flow that consumes a challenge — login, phone change, password reset,
step-up, account recovery, COD order confirmation — goes through
`consumeAny` / `verifyAny`, which branch on the row rather than on
configuration. A fallback can happen between the request and the consumption,
and no flow has to know.

## What it costs, honestly

- **She pays for one local SMS**, and leaves the app to send it. That is the
  trade for a rail that cannot silently fail to deliver, and it is why the
  screen says so.
- **The receiver is physical.** One phone with one SIM is a single point of
  failure and a throughput ceiling; run at least two receivers, and check what
  the operator's terms say about a line receiving verification traffic in
  volume.
- **The provider is young.** At the time of writing it is v0.1.0 by its own
  `KNOWN-LIMITATIONS.md`, with one maintainer, and its Flutter SDK is beta —
  which is why this integration speaks the REST contract directly rather than
  depending on that SDK. Its stated limits worth knowing: a compromised gateway
  signing key can forge an inbound for any number; verification codes are
  stored in plaintext for their TTL; there is no admin UI and no metrics
  endpoint yet.
- **Trust rests on the inbound sender header**, which is not cryptographically
  authenticated by the network. Inside one country's mobile network that is a
  reasonable assumption; it is weaker than a signature, and it is the thing to
  re-examine first if this rail is ever attacked.

## Configuration

| Variable | Meaning |
| --- | --- |
| `SYROTP_ENABLED` | `true` turns the rail on. |
| `SYROTP_BASE_URL` | The instance's address. Must be `https://` in production. |
| `SYROTP_SECRET_KEY` | `sk_live_…`. The publishable key is for browsers and is unused here. |
| `SYROTP_RECEIVER_ID` | `rcv_…`, the receiver a binding is opened against. |
| `SYROTP_PRIMARY` | `false` demotes the rail behind the transport chain. Default `true`. |
| `SYROTP_TIMEOUT_MS` | Per-request timeout. Default `8000`. |

All four of the first group are required together; a half-set group is refused
at boot, because the symptom otherwise — every sign-in silently taking the
fallback — is indistinguishable from a provider outage.

## Tests

- `backend/src/modules/auth/otp/syrotp/reverse-sms.spec.ts` — the rail's
  decisions against a scripted provider: which ceremony is opened, outage
  versus refusal, and that the provider's pending cap is not laundered by
  falling back.
- `backend/src/modules/auth/otp/syrotp/reverse-otp.integration.spec.ts` — the
  real `OtpService` against real Postgres with a stubbed provider: a reverse
  row is not settleable by a code, is settled only by `verified`, is settled
  once, and a provider that cannot open a ceremony becomes the old rail.
