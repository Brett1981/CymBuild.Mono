# R3 API orchestration and worker tests

## Purpose

R3 adds fast behavioural coverage for CymBuild's highest-risk API orchestration paths while preserving the mandatory production flow:

```text
Blazor PWA -> FormHelper/API.Client -> gRPC API -> EF -> SQL Server
```

The tests use controlled interfaces and configuration objects. They do not call a live Sage endpoint, Kafka broker, SQL Server, shared environment, or production database.

## Transaction-to-Sage submission

`TransactionToSageSubmissionServiceTests` covers:

- empty, invalid, and non-deserializable outbox payloads;
- missing approved-transaction read models;
- eligibility rejection before claim or outbound submission;
- already-completed status and claim results;
- active claim contention and retry classification;
- successful wrapper submission, idempotency completion, and diagnostics updates;
- Sage transaction-reference read-back when the create response omits it;
- malformed success responses with no order identifier;
- HTTP failure classification for validation, timeout, conflict, rate limiting, and server errors;
- non-retryable mapping failures and retryable transport exceptions.

These tests verify that no outbound call occurs before eligibility and claim checks succeed, and that acquired claims are completed or failed through `ITransactionToSageIdempotencyService`.

## Sage inbound payment synchronization

`SageInboundPaymentSyncServiceTests` covers:

- missing sync targets as non-retryable failures;
- successful empty responses and attempt recording;
- account/document fallback mapping;
- numeric, boolean, and date conversion from wrapper dictionaries;
- reconciliation and receipt materialisation conditions;
- paid, partially paid, and polling decisions;
- retryable exception recording after a sync claim;
- enqueue and force-requeue contracts.

## Hosted worker and configuration contracts

R3 adds safe lifecycle tests for disabled Sage workers and construction/configuration coverage for the invoice automation worker. Disabled Sage paths must start and stop without resolving scoped services; invoice automation construction must not open SQL connections.

Configuration tests cover:

- Sage worker polling, attempts, stale-claim, and event-type defaults;
- inbound worker interval, batch-size, and stale-claim defaults;
- invoice automation requester, lock, interval, notes, and sweep defaults;
- Sage API URL, HTTPS, timeout, API-key, environment, and localhost validation.

## Outbox and invoice automation contracts

R3 verifies:

- workflow status canonical-field fallback;
- JobCreatedFromProposal and JobClosureDecision JSON contracts;
- case-insensitive payload parsing and invalid payload failure behaviour;
- invoice automation connection-string fail-fast behaviour;
- rejection of an empty requester identity before any SQL connection is opened.

## Deliberate exclusions

R3 does not replace SQL Server integration tests. Claim atomicity, `SCore.IntegrationOutbox` updates, `SCore.DataObjectTransitionUpsert`, invoice trigger-ledger idempotency, application locks, and stored-procedure behaviour remain in the planned database integration tranche.

R3 also does not publish to Kafka or call Sage. Those boundaries are represented by interfaces and controlled test doubles.

## Acceptance criteria

R3 is accepted when:

1. the root solution builds in Release configuration;
2. the fast runner still discovers seven test projects;
3. `Concursus.API.Tests` executes exactly 100 passing cases;
4. all other established fast-test projects remain green;
5. every project produces TRX and Cobertura results;
6. no production C#, Razor, SQL, metadata, workflow, DataObjects, outbox, or deployment files change.
