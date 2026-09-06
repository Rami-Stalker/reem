# Resilience

How the app behaves when something goes wrong: who is told, what she sees, and
what happens to the tap that did not arrive.

```bash
flutter test test/observability_test.dart test/outbox_test.dart
```

---

## Error reporting

The app had **no** top-level error handling. A `RangeError` in a card's `build`
painted a grey box in release and was never heard of again; an unawaited future
that threw took the isolate down in silence.

`CrashGuard.run` wraps `main` and installs all four channels — Flutter genuinely
has four, and missing any one of them loses a whole class of failure:

| Channel | Catches |
| --- | --- |
| `FlutterError.onError` | anything inside the framework: build, layout, gesture callbacks |
| `PlatformDispatcher.instance.onError` | errors that escape to the engine, where unawaited futures land |
| `runZonedGuarded` | everything else asynchronous in our own code |
| `Isolate.current.addErrorListener` | background isolates, which none of the above can see |

### Where reports go

`ErrorSink` is an interface with a debug-console default. There is deliberately
no vendor here: the app needed the *spine* — handlers installed, breadcrumbs
kept, PII stripped — before it needed a Sentry account, and picking one is a
commercial decision. Adding Crashlytics later is a class implementing
`ErrorSink` and one line in `main`:

```dart
ErrorReporter.configure([const DebugConsoleSink(), CrashlyticsSink()]);
```

The default sink is **silent in release** rather than printing, because on some
Android builds the device log is readable by other applications.

### Redaction is not optional

This app serves women shopping in Syria. A crash report carrying a phone
number, an address or a bearer token is a safety problem, not a privacy
footnote. `ErrorRedaction` runs on every report, breadcrumb and extra on the way
out — bearer tokens, JWTs, Syrian mobile numbers in all three written forms,
emails, and the values of any query parameter or map key named `token`, `otp`,
`code`, `password`, `phone`, `address`, `card`.

It runs **once, centrally**. Making each caller remember is how a leak happens.

### Breadcrumbs

Twenty slots, oldest evicted. A stack trace tells you the line; the trail tells
you she came from the cart, the network dropped, and the third read failed.

| Source | Records |
| --- | --- |
| `NavigationBreadcrumbs` (GoRouter observer) | route pushes, pops, replacements — names only |
| `TelemetryInterceptor` (Dio) | method, path and status of every request |
| `ProviderBreadcrumbs` (Riverpod observer) | provider failures only |
| `Outbox` | queued, settled and abandoned intents |

None of them records a value. There is no path by which her data reaches a
report.

### What she sees

`ReemErrorWidget` replaces Flutter's release grey box. Flutter already contains
the damage — a failed `build` is swapped for an error widget and the rest of the
page carries on — so this only makes the substitute presentable: a tinted block
with an icon in a small slot, a short Arabic line where there is room. Debug
keeps Flutter's red box, which names the widget and the constraint and is worth
more to whoever is fixing it.

Nothing is reported from that widget: `FlutterError.onError` already fired
before it was built, and reporting again would double-count every failure.

---

## The offline write queue

`Outbox` holds what she asked for while the network was not listening.

### What belongs in it

Engagement — a like, a save, a favourite. Frequent, tapped while scrolling on a
bad connection, costs nothing if it lands a minute late, and her intent is
unambiguous.

**Nothing that moves money.** Not a cart line, a checkout, a payment or a
refund. Those need a live confirmation, because the honest answer to "did my
order go through" is yes or no, never "probably, later". Queuing them would let
the app tell a woman she had bought something she had not.

### Why it stores intent, not requests

`POST /posts/:id/like` is a **toggle**. Storing the failed request and replaying
it would un-like a post whose like actually landed and whose response was merely
lost — a plausible outcome on exactly the connection that caused the queueing.

So an `OutboxIntent` records the *end state she wanted*. On drain, the handler
reads where the server stands and toggles only if it disagrees. That turns a
dangerous replay into a safe no-op, and it makes coalescing correct for free:
five taps on one heart are one intent whose `desired` is the fifth tap.

### Drain policy

* Runs on app start, and on the offline → online transition only. Draining on
  every connectivity emission would re-run the queue each time the radio
  flickers between wifi and mobile.
* Concurrent calls share one pass.
* A connection failure **defers**; anything else **abandons** — retrying a
  request the server has refused will not make it succeed.
* An unreadable current state defers rather than assuming `false`. Guessing
  here would silently flip her post.
* Gives up after 5 attempts or 3 days, and leaves a breadcrumb saying so.
* Bounded at 200 intents, oldest dropped, persisted to the app support
  directory so a queue survives the app being killed in her pocket — which is
  the commonest way to lose a connection.

### Adding a kind

Implement `OutboxHandler` — `readState` and `toggle` — and register it in
`outboxProvider`. Add the reconciliation cases to `test/outbox_test.dart` in the
same change.

### What she sees

Nothing, on the happy path. A network failure on a like leaves the heart filled
and says nothing: she did the thing, the app is holding it, and telling her
about our transport problem is our anxiety rather than her business. A
*refusal* — the post was deleted — still reverts and says so, because leaving it
filled would be a lie she discovers weeks later.

`Outbox.isPending` and `Outbox.desiredState` are there for a screen that wants
to mark an unsent tap explicitly. Nothing uses them yet.
