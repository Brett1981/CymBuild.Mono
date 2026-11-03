# CymBuild architecture and data rules

These rules apply to production code, generated tests, fixtures, test utilities,
SQL setup, and agent-authored changes.

## Application boundary

The required route is:

```text
Blazor PWA UI → FormHelper/API client → gRPC API → EF/repository → SQL Server
```

Tests may isolate a layer with a fake or mock at that layer's public boundary,
but production code must not bypass the route. In particular:

- Razor/components own presentation state and user interaction, not business
  decisions.
- FormHelper owns client-side coordination and gRPC invocation.
- gRPC services own server-side validation and orchestration.
- EF/repositories or controlled SQL own persistence.
- A component test that calls a fake FormHelper is valid; production UI code
  that calls a generated gRPC client directly is not.

Architecture tests should detect newly introduced direct UI-to-gRPC/API/EF/SQL
dependencies and server/business dependencies added to the PWA layer.

## Managed entities and DataObjects

Every managed entity insert must atomically create its `SCore.DataObjects` row
with the correct `EntityTypeId`.

Any integration test that creates a managed entity must assert both outcomes:

1. the entity row exists with the expected business values;
2. exactly one matching active DataObject exists with the correct entity type.

The test must fail for an orphan entity, an orphan DataObject, a duplicate active
DataObject, or a mismatched entity type. Do not hide these failures in fixture
cleanup.

## Workflow state

Workflow status must never be updated directly. All state changes use
`SCore.DataObjectTransitionUpsert`; the latest transition represents current
state.

Tests for a state-changing operation must verify:

- the transition operation was used through the supported server/SQL route;
- a new valid transition exists;
- earlier history was preserved;
- the latest transition resolves to the expected state;
- retrying an idempotent request does not create an invalid duplicate or corrupt
  history.

Tests and data builders must not use direct status updates as a shortcut.

## Integration events

Use `SCore.IntegrationOutbox`. Tests for an integration-producing operation must
prove that the business update and outbox write are atomic. Consumer tests must
cover idempotent reprocessing, retryable failure, permanent failure/reporting,
and correlation/diagnostic data without exposing secrets.

External services are not called from unit or component tests. Integration
boundaries use fakes or controlled contract environments. Older retained
services, such as the legacy Sage microservice, are not accidentally restored
to the active deployment or test matrix; current Sage integration uses the Sage
Wrapper boundary.

## Schema and metadata

- SQL schema changes are source-controlled and idempotent.
- Metadata definitions are source-controlled manifests and applied by stable
  Guid.
- Database contents are evidence for controlled verification, never the source
  from which an agent silently manufactures a production fix.
- No manual database promotion.
- No migrations during PWA/API/worker startup.
- Metadata apply respects dependencies and prevents duplicates.

Test fixtures should use stable Guids or controlled natural keys. Do not encode
environment-specific numeric IDs in tests, scripts, or manifests.

## SQL contracts

- Schema-qualify objects and use explicit columns.
- Never add `SELECT *`.
- Active-row predicates use `RowStatus NOT IN (0,254)` unless preserving an
  exact existing contract requires otherwise.
- Creation and deployment scripts are repeatable and fail with diagnosable
  errors.
- Schema tests run against an isolated/disposable or explicitly controlled test
  database, never by altering LIVE.
- Verify a migration twice where repeatability matters: first apply and second
  no-op/convergent apply.

## Preservation rule

Before changing a legacy contract, identify its current consumers and tests.
Column names, lengths, ordering, nullability, validation, metadata bindings, and
workflow guards may be compatibility contracts even when they look accidental.
Preserve them unless the requested behaviour explicitly changes them.
