# Reem — Application Architecture

## Overview

Flutter client for a **Node.js REST API**, organized by **feature-first clean architecture** with three layers per module.

```
lib/
├── core/           # Shared infra (network, errors, DI, design system, l10n)
├── features/       # Feature modules (auth, home, catalog, …)
└── l10n/           # Generated localizations (en, ar)
```

## Layer rules

| Layer | Responsibility | Depends on |
|-------|----------------|------------|
| **Presentation** | UI, `StateNotifier`, Riverpod providers | Domain use cases only |
| **Domain** | Entities, repository contracts, use cases | Nothing in features/data |
| **Data** | Datasources, models, repository implementations | Domain + core |

## Cross-cutting patterns

- **`Result<T>`** — `Success` / `Error(Failure)` at repository boundaries
- **`RepositoryHandler.guard()`** — maps `AppException` → `Failure`
- **`BaseRemoteDataSource`** — HTTP helpers + Dio error mapping
- **`ApiEndpoints`** — paths aligned with Node.js modules
- **`dioProvider`** — single Dio instance with `AuthInterceptor`
- **`AppEnv.baseUrl`** — `--dart-define=API_BASE_URL=...` for environments

## Features

| Module | Domain focus |
|--------|----------------|
| `auth` | Login, register, session, forgot password |
| `home` | Feed posts, stories |
| `catalog` | Products, trending, product details |
| `profile` | User profile, favorites, orders |
| `settings` | Addresses, coupons, notifications, rewards |
| `chat` | Threads, messages, send |
| `create` | Create post, create story |
| `admin` | Dashboard stats |
| `onboarding` | First-run flag (local) |

## State management

- **Riverpod 3** — `Provider` for DI graph, `StateNotifierProvider` for feature state
- **`ProviderScope`** in `main.dart`
- **`goRouterProvider`** — auth-aware redirects

## Backend contract

See [BACKEND_API.md](./BACKEND_API.md) for REST paths and JSON shapes (snake_case).

## Running against local Node API

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

(Use your machine IP on physical devices.)
