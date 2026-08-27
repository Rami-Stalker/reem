# Reem

Women-focused social-commerce platform. A Flutter client at the repository
root, a NestJS + PostgreSQL API in [`backend/`](backend/).

## Repository layout

```text
lib/                 Flutter client (see docs/ARCHITECTURE.md)
  main.dart            entry point
  app/                 MyApp + AppBootstrap
  core/                cross-cutting: design system, network, router, DI, ...
  features/            feature modules, each with data/ domain/ presentation/
  l10n/                generated localization output
assets/fonts/        bundled Cairo + Playfair Display
test/                widget, visual-preview, and API contract tests
backend/             NestJS API, Prisma schema, migrations, seed
docs/                architecture, database, API, and client-requirement docs
tools/architecture/  structural checks that the analyzer cannot express
```

## Running the client

Requires the Dart SDK matching `environment.sdk` in `pubspec.yaml` (`^3.11.5`).

```bash
flutter pub get
```

```bash
flutter run
```

## Running the API

From `backend/`. The first command brings up PostgreSQL in Docker; the second
applies migrations, generates the Prisma client, and seeds the demo dataset.

```bash
npm install && npm run db:up
```

```bash
npm run db:setup && npm run dev
```

See [`backend/README.md`](backend/README.md) for the endpoint surface, auth
model, and database operations.

## Checks

```bash
flutter analyze
```

```bash
flutter test
```

Two structural checks guard the layout. Both exit non-zero on failure.

```bash
node tools/architecture/check-flutter-boundaries.mjs
```

Fails when a `domain/` library imports Flutter, Riverpod, Dio, `go_router`, or
a `data/`/`presentation/` sibling; also prints advisory debt queues.

```bash
node tools/architecture/find-unreachable-dart.mjs
```

Fails when a library under `lib/` is reachable from neither `main.dart` nor a
test.

## Documentation

| Document | Covers |
| --- | --- |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Client layering, where shared code lives, structural checks, known debt |
| [DATABASE.md](docs/DATABASE.md) | Schema and data model |
| [BACKEND_API.md](docs/BACKEND_API.md) | Endpoint surface |
| [identity-authorization-architecture.md](docs/identity-authorization-architecture.md) | Identity, OTP, devices, roles |
| [docs/client/](docs/client/) | Client requirement questionnaires |
