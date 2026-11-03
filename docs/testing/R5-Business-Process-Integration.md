# R5 (in progress) — Business-process SQL integration: Account → Enquiry → Quote → Job

## Status

- **Done:** slice 1, the QuoteItems → Job outbox-enqueue trigger test (see "Recommended
  incremental order" below). `SSop.tr_QuoteItems_EnqueueJobCreatedFromProposal`,
  `SCore.IntegrationOutbox_EnqueueJobCreatedFromProposal`, and `SCore.GetCurrentUserId` are now
  real canonical manifest entries (required two new `Invoke-ManifestSource` batch kinds,
  `Trigger` and `Function`, added to `Initialize-CymBuildSqlTestDatabase.ps1`). `SSop.Projects`
  is a new compatibility stub; `SJob.Jobs` gained `ClientAccountID`/`ProjectId`/`CreatedOn`;
  `SSop.Quotes` gained `Number`/`QuotingConsultantId`. Two new tests in
  `tests/CymBuild.Database.IntegrationTests/Outbox/QuoteItemJobCreatedOutboxTests.cs`. R4's case
  count is now 32 (was 30) — `Assert-ProvisioningState`, `Invoke-CymBuildSqlIntegrationTests.ps1`,
  and the R4 doc's coverage table were all updated in lockstep. Verified against a real LocalDB
  `CymBuild_Test_R4` database: `-ValidateSourceOnly`, `-Apply`, `-VerifyOnly`, and the full
  `dotnet test` run all pass (32/32).
- **Not started:** slices 2-7 below (Account creation, the Sequence batch kind, and the full
  Enquiry/Quote/Job upsert chain).

## Purpose

R4 (see `R4-SQL-Server-Integration.md`) proves generic DataObjects/workflow/outbox invariants
against a stand-in entity (`SCore.NonActivityEvents`). R5 extends the same real-LocalDB,
canonical-source-of-truth approach to the actual CRM/Sales-Ops/Job business entities, so the
suite can assert real behaviour for Account creation, the Enquiry → Quote → Job process, and the
workflow transitions each entity goes through — not just a proxy entity.

This document is a **dependency map and incremental plan**, not an implementation. Nothing here
has been added to the manifest, compatibility SQL, fixtures, or the PS1 provisioner yet.

## How the R4 harness applies here (recap)

- `tools/Testing/R4-Sql-Test-Schema.json` registers real, hash-verified DDL **batches** one at a
  time by regex, matched against the canonical source under `Database/CymBuild_DB/Schema`. A
  batch not registered (a trigger, an index, a full-text index, an FK) is simply never applied,
  even if it lives in the same source file as a registered batch — no explicit exclusion syntax
  needed.
- `tests/CymBuild.Database.IntegrationTests/Database/R4-Test-Compatibility.sql` hand-writes
  minimal stub tables/columns for objects that real, exercised procedures reference but that R5
  does not intend to test in their own right.
- `tools/Testing/Initialize-CymBuildSqlTestDatabase.ps1`'s `Assert-ProvisioningState` hardcodes
  exact object/table/index/compatibility/fixture **counts**. Every manifest, compatibility, or
  fixture addition must bump the matching literal or provisioning fails even when the change is
  otherwise correct.
- `Invoke-ManifestSource`'s batch-kind switch currently supports only:
  `Schema | Table | PrimaryKey | Index | UniqueColumn | ForeignKey | DisableConstraint | Procedure | View`.
  There is **no `Sequence` kind** yet (see Enquiry/Quote/Job below).

## Findings per entity

### CRM Account (`SCrm.AccountsUpsert`, `Tables/SCrm.Accounts.sql`) — moderate scope

- Real `Accounts` table's two triggers (`tg_Accounts_RecordHistory`,
  `tr_Accounts_CreditHold_InvoiceModeSync`) and its full-text index are each separate `GO`
  batches — safe to leave unregistered in the manifest, same as R4 does for other tables.
  `tg_Accounts_RecordHistory` also self-guards on `S_disable_triggers` (already set by the
  provisioner) as a second line of defence; `tr_Accounts_CreditHold_InvoiceModeSync` does **not**
  self-guard and calls two `SFin.JobInvoiceProcessingMode_*` procs that don't exist in the test
  DB — it must stay unregistered, not just rely on the session flag.
- FK-resolution in `AccountsUpsert` does **not** gracefully fall back to `-1` on a miss — an
  unmatched `@AccountStatusGuid`/`@ParentAccountGuid`/etc. leaves the resolved `@...ID` variable
  `NULL`, which then violates the target column's `NOT NULL` constraint on `INSERT`. A real
  `SCrm.AccountStatus` fixture row (none exists today) is required for any test that calls
  `AccountsUpsert` successfully.
- `AccountsUpsert` unconditionally calls `EXEC SOffice.TargetObjectUpsert` for SharePoint filing,
  reading `SCore.ObjectSharePointFolder`/`SCore.SharepointSites`. Exact minimal stub shape for
  these is an **open item** — not yet confirmed against `SOffice.TargetObjectUpsert.sql`.
- Registering just the `Table` + `PrimaryKey` batches (skip indexes/FKs, mirroring R4's existing
  minimalism for other tables) is enough for a DataObjects-atomicity test.
- `SCrm.AccountContacts` is not currently stubbed; only needed if `MainAccountContactId`'s FK is
  registered (it can be safely omitted instead, like the other Account FKs).

### Enquiry → Quote → Job real upserts — large scope, not attempted yet

- `SSop.EnquiriesUpsert` resolves ~15 unconditional FK lookups (auto-creates a Project via
  `SSop.ProjectsUpsert` if none supplied, plus `SJob.Assets`, `SCrm.Accounts`/`AccountAddresses`/
  `AccountContacts` ×3 roles, `SJob.RibaStages`, `SSop.QuoteSources`, `SCrm.Counties`/`Countries`,
  `SCrm.ContactDetailTypes`), consumes `NEXT VALUE FOR SSop.EnquiryNumber`, and unconditionally
  calls `SOffice.TargetObjectUpsert`.
- `SSop.QuotesUpsert` follows the same pattern (`NEXT VALUE FOR SSop.QuoteNumber`, unconditional
  `SOffice.TargetObjectUpsert`).
- `SJob.JobsUpsert` calls `SCore.UpsertDataObject @SchemeName='SJob' @ObjectName='Jobs'` — this
  already matches the EntityHobts/EntityType fixture Guid
  (`63542427-46AB-4078-ABD1-1D583C24315C`) seeded for the existing JobClosureDecision work — but
  the real `Jobs` table has ~30 FK columns vs. the current 12-column compatibility stub, and pulls
  `NEXT VALUE FOR SJob.JobNumber`.
- All three real tables almost certainly carry the same ~500-line RecordHistory trigger pattern
  seen on `SCrm.Accounts` (not yet confirmed per-entity).
- **A new `Sequence` manifest batch kind must be added to `Invoke-ManifestSource` before any of
  these three upserts can be tested for real** (existence-check via `sys.sequences` or
  `OBJECT_ID(..., 'SO')`, analogous to the existing `Table`/`Procedure` handling).
- Both independent research passes that produced these findings assessed the full chain as
  multi-week scope: a new PS1 capability plus on the order of 15 new/extended stub tables, each
  needing the same triggers-and-FKs judgement call already made for Accounts.

### Quote → Job link: the cheap, precedented slice

- `Programmability/Triggers/SSop.tr_QuoteItems_EnqueueJobCreatedFromProposal.sql` is an
  `AFTER UPDATE` trigger on `SSop.QuoteItems` that fires when `CreatedJobId` moves from
  unset/negative to a real Job ID, dedups per Job ID, and calls
  `EXEC SCore.IntegrationOutbox_EnqueueJobCreatedFromProposal` once per distinct Job ID.
- The existing minimal `SSop.QuoteItems` compatibility stub (`R4-Test-Compatibility.sql`) already
  has the exact columns (`QuoteId`, `CreatedJobId`) this trigger needs — no new stub table
  required.
- Structurally identical to the already-tested `JobClosureDecisionOutboxAtomicityTests` pattern:
  register the trigger, write a test that updates `CreatedJobId` and asserts an outbox row
  appears. This is the smallest real "Quote leads to Job" assertion available, and does not touch
  the Sequence-kind gap at all.
- Still to confirm before implementing: what `SCore.IntegrationOutbox_EnqueueJobCreatedFromProposal`
  itself requires.

## Recommended incremental order

1. **QuoteItems → Job outbox-enqueue trigger test** — DONE (see Status above).
2. **CRM Account creation (DataObjects-atomicity) test** — moderate; resolve the
   `SOffice.TargetObjectUpsert` stub question and add an `SCrm.AccountStatus` fixture row first.
3. **Add the `Sequence` batch kind to `Invoke-ManifestSource`** — prerequisite for any real
   Enquiry/Quote/Job upsert test; unblocks the rest of the chain.
4. **`SSop.EnquiriesUpsert` real creation test** — largest FK surface; needs a deliberate
   register-vs-omit decision per FK, following the Accounts precedent.
5. **`SSop.QuotesUpsert` real creation test** — depends on step 4's Enquiry/EnquiryServices work.
6. **`SJob.JobsUpsert` real creation test** — Jobs entity/EntityType groundwork already partly
   seeded by the JobClosureDecision work.
7. **Workflow-transition tests per entity** — effectively free once an entity's EntityHobts/
   EntityType rows exist, since `SCore.DataObjectTransitionUpsert` is already generic and tested;
   add one per entity as each entity lands rather than as a separate effort.

## Maintenance note

Every step above that touches the manifest, compatibility SQL, or fixtures must also update the
hardcoded counts in `Assert-ProvisioningState` (`Initialize-CymBuildSqlTestDatabase.ps1`) and the
case-count table in this doc set (see R4's "Coverage" table) — provisioning hard-fails on a count
mismatch even when the underlying change is correct.
