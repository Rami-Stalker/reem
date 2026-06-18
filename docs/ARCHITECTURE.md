# Reem Application Architecture

## Overview

The Flutter client uses feature-first Clean Architecture. Each feature owns its
domain contracts, data adapters, and presentation state, while `core/` provides
cross-cutting primitives that are stable enough for every feature to share.

```text
lib/
  core/              Shared platform, network, result, cache, sync, state, DI
  features/          Feature modules: auth, discovery, checkout, profile, ...
  l10n/              Generated localization output
```

## Layer Rules

| Layer | Responsibility | May depend on | Must not depend on |
| --- | --- | --- | --- |
| Presentation | Widgets, Riverpod providers, UI state, navigation events | Domain use cases, core presentation primitives | Dio, remote data sources, data models |
| Domain | Entities, value objects, repository contracts, use cases | `core/result`, `core/domain` | Flutter, Riverpod, Dio, storage, data layer |
| Data | Remote/local data sources, DTO parsing, repository implementations | Domain contracts, core network/cache/sync | Widgets, provider state, route objects |

## Core Contracts

- `Result<T>` is the only expected success/failure boundary between repositories,
  use cases, and presentation controllers.
- `Failure` carries user-safe messages plus production metadata: error code,
  HTTP status, retryability, severity, cause, and stack trace.
- `RepositoryHandler.guard()` maps `AppException` into `Failure` and shields
  presentation code from thrown infrastructure exceptions.
- `BaseRemoteDataSource` centralizes Dio calls, error mapping, typed decoding,
  and paginated response parsing.
- `PageRequest`, `PageInfo`, and `PaginatedData<T>` define reusable pagination
  contracts for large lists and infinite scrolling.
- `PaginatedNotifier<T>` and `PaginatedState<T>` implement reusable load,
  refresh, and load-more state transitions with rebuild-friendly immutable
  state.
- `CacheStore`, `MemoryCacheStore`, `CachePolicy`, `RetryPolicy`, and
  `DataSynchronizer` provide cache-first, network-first, network-only,
  cache-only, and stale-while-revalidate strategies.

## Dependency Direction

```text
UI widget
  -> Riverpod provider/notifier
    -> use case
      -> repository contract
        <- repository implementation
          <- remote/local data sources
            <- Dio, cache, storage, connectivity
```

Dependencies point inward. Data implements domain contracts; domain never knows
which backend, database, cache, or state-management tool is being used.

## Repository Standard

Repository implementations should:

- return `Future<Result<T>>`, never throw into presentation;
- wrap remote/local work in `guard(operation: 'clear operation name')`;
- choose a cache/sync strategy explicitly for read-heavy data;
- keep mutation side effects small and deterministic;
- convert DTOs to domain entities before returning data;
- hide retry, token refresh, response-shape normalization, and storage details.

## Provider Standard

Providers should:

- expose dependencies from the narrowest useful abstraction;
- prefer `.select(...)` for UI selectors that read small state fragments;
- use `autoDispose` for route-scoped screens and keep app-wide session/cart
  state alive intentionally;
- keep controllers focused on state transitions and user intents;
- reuse `PaginatedNotifier<T>` for large lists instead of reimplementing paging.

## Current Refactor Notes

The current codebase already had useful clean-architecture seeds: feature
folders, repository contracts, use cases, `Result<T>`, and Dio error mapping.
The main scalability risks were repeated provider wiring, thin failure models,
feature-specific pagination contracts, weak cache/offline foundations, and
connectivity code that did not match the installed `connectivity_plus` API.

The refactor introduced shared enterprise primitives without forcing a risky
rewrite of every feature at once. Discovery/search pagination now runs on the
generic core pagination state machine while preserving the public provider API
that screens already use. Future features should adopt these core contracts as
they are built or touched.

## Migration Path

1. New paginated screens should return `PaginatedData<T>` from use cases and use
   `PaginatedNotifier<T>` in presentation.
2. Existing feature-specific page entities can add a mapper like
   `toPaginatedData()` until their repository contracts are migrated.
3. Read-heavy repositories should call `DataSynchronizer.resolve()` with an
   explicit `CachePolicy`.
4. DTOs that currently extend entities should gradually move to composition and
   mapper methods when those files are already being changed.
5. Add focused tests around repository failure mapping, cache policy behavior,
   and notifier state transitions as each feature migrates.
