# Agent-assisted test-case generation

## Governing principle

The agent may propose and scaffold tests; it must not make CI or production
behaviour depend on nondeterministic generation. Test intent, inputs, expected
outcomes, and environment permissions are source-controlled and reviewable.

The initial portable representation is a JSON test-case manifest validated by
`test-cases/schema/cymbuild-test-case.schema.json`. A later repository-native
.NET generator can convert approved cases into the actual existing test
framework or use them as data for parameterised tests.

## Authoritative inputs

Generate a candidate only from inspected evidence:

- requested behaviour and acceptance criteria;
- Jira work item when supplied;
- the actual Git diff and affected consumers;
- current source-controlled metadata manifests;
- `.proto` and request/response contracts;
- EF mappings/repositories and SQL source;
- existing tests, fixtures, helpers, and known regression cases;
- deployment/environment policy.

Do not derive production tests by querying a LIVE database. A controlled export
used to reconcile source-controlled metadata is a separate audited migration
activity, not test generation.

## Generation workflow

1. **Describe behaviour** — translate the request into observable outcomes and
   explicit non-goals. Do not convert an implementation detail into a business
   requirement without evidence.
2. **Trace sources** — record code paths, metadata manifest paths/Guids, SQL
   objects, contracts, and ticket references in `sources`.
3. **Classify impact** — choose every relevant layer from the matrix in
   `testing-strategy.md`.
4. **Select data policy** — read-only, synthetic transactional, seeded
   disposable, or no data. LIVE can only be read-only or no-data.
5. **Create cases** — cover positive behaviour, validation/error paths,
   permissions, idempotency/retry, and architectural invariants where relevant.
6. **De-duplicate** — update an existing stable case when intent is unchanged;
   do not create a second case because a caption or numeric database ID changed.
7. **Review** — verify every source reference and expected result against current
   code/contracts. Candidate status is not implementation status.
8. **Scaffold** — only after confirming the target test project's real patterns.
9. **Execute and report** — record implemented test path, result, and residual
   manual or environment-only coverage.

## Stable identity

Use a stable case ID such as `CYB-TC-<area>-<behaviour>` with an optional Jira
key. Identity is based on behavioural intent, not test method name, UI caption,
DOM path, row ID, or database environment.

Metadata sources use their controlled manifest path and stable Guid when that
Guid exists. Never use an environment-specific numeric metadata ID as identity.

## Required case content

Each case records:

- requirement and rationale;
- source references;
- test layer;
- allowed environments;
- data creation/cleanup policy;
- preconditions;
- actions using the permitted architecture route;
- observable assertions;
- managed-entity and workflow implications;
- automation status and target test location;
- traceability tags.

## Generation rules by change type

### Metadata form or field

Generate or update cases for manifest validity, field rendering, default/read-
only/required behaviour, visibility and permission rules, validation, action
binding, and any affected critical journey. Do not generate one Playwright test
per field when a component contract plus manifest validation gives stronger and
faster coverage.

### Grid/view/column metadata

Validate dependency order **Grid → View → Columns**, stable identity, unique
definitions, referenced source columns, formatting/type compatibility,
filter/sort/page contracts, security, and active-row behaviour. Add browser
coverage only for high-risk or business-critical interactions.

### FormHelper or gRPC change

Generate mapping, validation, authorization, cancellation/error, and backward-
compatibility cases. Confirm UI still calls through FormHelper and that business
rules were not moved into UI code.

### Entity or workflow change

Add DataObject atomicity, transition history/current state, invalid transition,
retry/idempotency, concurrency when relevant, and rollback assertions.

### SQL object change

Assert explicit result shape, filtering, null/length/type compatibility,
idempotent deployment, consumer compatibility, and second-run convergence. A
function or view used by dynamic grid metadata needs both SQL contract and
metadata consumer coverage.

### Integration change

Add atomic outbox write, duplicate delivery, retryable failure, terminal
failure/diagnostics, ordering where required, and external contract cases.

## Test impact gate

The proposed future generator should emit a machine-readable impact report:

- changed source;
- inferred affected contracts;
- existing matching cases/tests;
- new or updated case manifests;
- uncovered risk with a reason;
- suites required in CI and deployed environments.

The gate must not demand meaningless tests. A documentation-only or mechanical
change may record `no-test-required` with a verified reason. Any behaviour,
contract, SQL, metadata, workflow, or integration change requires coverage or an
explicit reviewed risk decision.

## What the agent must never do

- invent metadata properties, schema, API routes, or expected values;
- use LIVE data to discover or train test cases;
- create direct API calls from UI test helpers that disguise a production
  architecture violation;
- seed state by directly updating workflow status;
- omit DataObject assertions for managed inserts;
- delete or mutate shared UAT/LIVE data for cleanup;
- regenerate approved cases differently on each CI run;
- mark a scaffold or unexecuted manual case as passing.
