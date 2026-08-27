# Enterprise Architecture Roadmap

## Current Findings

The project already has useful Clean Architecture foundations: feature folders,
domain entities, repository contracts, use cases, central network/error mapping,
NestJS modules, Prisma repositories, and focused backend tests. The next level
of maturity is enforcement and consistency.

Highest-priority issues found in the audit:

- Domain purity leaks: a few domain files still import Flutter UI types, and
  onboarding use cases depended directly on a local data source.
- Presentation composition roots are mixed with feature providers, so many
  presentation provider files instantiate data sources and repository
  implementations directly.
- DTOs and models often extend domain entities. This is convenient, but it
  couples wire formats to domain semantics and makes schema evolution riskier.
- Several files exceed 500 lines, including orchestration services, route/app
  shell code, settings screens, and dashboard screens.
- Debug prints remain in application code and should move to structured
  logging or be removed.
- Backend modules vary between repository/service separation and large service
  classes with direct Prisma usage.
- The existing worktree is heavily modified, so architectural migration must be
  incremental, tested, and scoped by feature.

## Target Architecture

Flutter feature modules should keep this dependency direction:

```text
presentation -> application/use cases -> domain contracts <- data adapters
```

Backend modules should evolve toward:

```text
controller -> application service -> domain policy/entity -> repository port
                                                <- Prisma adapter
```

Cross-cutting capabilities belong in stable shared modules:

- configuration and environment validation
- logging and observability
- error mapping and failure envelopes
- authorization and policy checks
- caching and synchronization
- pagination and query contracts
- test builders and architecture fitness checks

## Non-Negotiable Rules

- Domain code must not import UI frameworks, state management, HTTP clients,
  storage, generated DTOs, or infrastructure adapters.
- Presentation code may depend on domain use cases and presentation state, but
  infrastructure construction should gradually move into composition-root
  modules.
- Data models should map to domain entities through constructors or mapper
  methods, not inheritance, when files are already being touched.
- Large classes should split by policy, query, command, serializer, and adapter
  responsibility.
- Every new architectural rule should be enforced by a script, lint, test, or
  build step once the current baseline is clean enough.

## Migration Sequence

1. Establish architecture fitness checks with a baseline for known debt.
2. Remove direct domain-to-data dependencies feature by feature.
3. Move feature dependency wiring out of presentation providers into
   composition-root provider modules.
4. Replace DTO/model inheritance with explicit mappers as each feature changes.
5. Split large services and screens along command/query/presentation boundaries.
6. Add focused unit tests around policies, mappers, repositories, and state
   transitions before deeper rewrites.
7. Convert advisory architecture checks into enforced checks as each debt class
   reaches zero.

## First Enforced Check

Run:

```bash
node tools/architecture/check-flutter-boundaries.mjs
```

The script currently enforces new domain-layer boundary violations and reports
advisory debt queues for presentation infrastructure imports, debug prints,
model inheritance, and large files.
