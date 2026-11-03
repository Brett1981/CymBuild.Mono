# CYB-323 — Fire Engineering Fee Proposal Document Auto-Population — Phase 1 Design Plan

Branch: `feature/CYB-323-fee-proposal-auto-population` (cut from `release/26.3`, fast-forwarded onto `release/26.4` 2026-09-28)

Full ticket: https://socotecuk.atlassian.net/browse/CYB-323

## Scope

**Phase 1 (this plan):** Consultant signature auto-population, confirming client info
auto-population, and the "Design Fire Safety Strategy" section (Table 1 + Table 2 invoicing
schedule) — including the Included(I)/Optional(O) scope logic, which only applies to this
one section of the template.

**Explicitly out of scope for Phase 1:** Tables 3–14 (EWS New/Existing, CFD, CFD third-party
review, CFSS/FRA, Authorising Engineer, Fire Safety Practice, Hourly Rates, Appendices). These
follow the same pattern established in Phase 1, as later phases.

## Background / current-state findings

- Merge engine: `services\Concursus.API\Classes\WordDocumentService.cs` + EF types under
  `libs\Concursus.EF\Types\MergeDocument*.cs`. Four `MergeDocumentItemType`s exist: Data Table,
  Image Table, Includes, Signature.
- The live "Fire Engineering UK - Fee Proposal" `MergeDocument` (ID 122, Guid
  `c26adae4-cbd1-44a6-876a-1f51d7733ae6`) has **zero** `MergeDocumentItems` configured today
  (confirmed against both source control and the live DEV database) — it currently only does
  plain `«MergeField»` scalar substitution.
- Its data source is `SSop.FireEngineering_Fee_Proposal_MergeInfo` (EntityHoBT 161, EntityType
  204) — NOT literally `FE_Fee_Proposal_Merge_Info` as shorthand in the ticket.
- `SProd.Products.Code` in DEV has been aligned to the "Product Allocations for Proposals"
  spec doc (12 renames + 4 new products; 5 orphan products left untouched pending a business
  decision). Script: `Database\CymBuild_DB\Scripts\Upgrade Scripts\CYB-323_ProductCode_Alignment_for_LIVE.sql`
  (also at `%TEMP%\claude\CYB-323_ProductCode_Alignment_for_LIVE.sql` for running against LIVE).
- The "PRODUCT ALLOCATIONS FOR PROPOSALS" doc and a worked full example
  (`XXXXXX-XXX-FP-Project Name-Template (2026) v0.1 dAK.docx`) confirm: Included(I)/Optional(O)
  columns exist **only** in Table 1. Optional rows never vary per quote (fixed text, "users can
  manually delete if not required") — these can ship as static template content, no merge logic
  needed. Included rows are conditional on a specific product (or small set of products) being
  on the quote.

## Design

### 1. Consultant signature

- `Quotes.QuotingConsultantId → SCore.Identities.{FullName, JobTitle, Signature}` — data path
  already correct; text fields already registered as merge fields.
- **Gap:** the only existing signature-image lookup (`EF.Core.GetSignatoryInfo` →
  `SJob.GetJobSignatoryInfo`) is rooted at `SJob.Jobs` and keyed off the Enquiry's
  `SignatoryIdentityId` — returns nothing pre-Job, which is exactly the fee-proposal scenario.
- **Fix:** additive fallback branch in `EF.Core.GetSignatoryInfo` — when called with a
  `quoteGuid` and the Job-rooted query returns no rows, resolve directly via
  `Quotes.QuotingConsultantId → SCore.Identities`. Must not change existing Job-signatory
  behaviour (regression test required).
- New `SCore.MergeDocumentItems` row on MergeDocument 122, type = Signature, tagged
  `ConsultantSignature`.
- **Template decision (confirmed with user):** replace the static ~15-person consultant roster
  in "Yours sincerely" with a single dynamic block (name/quals/job title/phone/email +
  signature image).

### 2. Client info

Already fully working — `FireEngineering_Fee_Proposal_MergeInfo` already has `ClientPostcode`
etc. registered. Action: one real test-quote generation to confirm end-to-end; extend only if
an actual gap is found.

### 3. Design Fire Safety Strategy — Stage/Deliverables/Fee + Scope I/O

- Table 1 is a fixed set of ~9 row slots grouped by RIBA stage (Concept Design / RIBA2,
  Spatial Coordination / RIBA3, Technical Design / RIBA4), not a flat "one row per quote item"
  table.
- **Mechanism:** reuse the existing "Includes" `MergeDocumentItemType`, not "Data Table" (Data
  Table only renders flat auto-generated tables — no stage grouping, no subtotals, no bespoke
  combined-row text). Each Included row becomes its own tagged `Includes` content control.
  Today, `Includes` processing (`WordDocumentService.cs`'s own inline copy — confirmed the one
  actually called, not the parallel `DocumentIncludeHelper.cs`) is unconditional splice-in.
  **New logic needed:** a conditional-keep predicate — splice in only if the row's gating
  product code(s) are present as quote line items.
- **New data:** a mapping from each Include row to its gating product code(s). Recommendation:
  new explicit column(s)/table rather than repurposing `MergeDocumentItemInclude`'s existing
  dormant `SourceDocumentEntityProperty`/`SourceSharePointItemEntityProperty` fields.
- **Fee values:** each Include's own sub-document resolves its own merge fields independently
  (confirmed in the engine) — Fee cells resolve from `SSop.QuoteItems_MergeInfo` filtered to
  the row's product code(s), summed when a row covers more than one product.
- **Subtotals — already built:** `SSop.tvf_QuoteFeeDrawdown` already pivots by RIBA stage and
  `FireEngineering_Fee_Proposal_MergeInfo` already exposes `Stage1Net`…`Stage7Net`,
  `PreConstruction`, `Construction`, `TotalNetFees`, all already registered as merge fields.
  Table 1/2's subtotal and grand-total cells just need `«Stage2Net»`/`«Stage3Net»`/
  `«Stage4Net»`/`«TotalNetFees»` placeholders in the template — **no new schema/metadata work**.
- Table 2 (invoicing schedule) rows map 1:1 to the same Included deliverables — treated as
  part of the same Phase 1 slice.

### 4. Template editing

In the SharePoint template (Document Id `01OGW3DZUHLDNQD3BUKJGY7IYVSFUNOKL3`):
- `ConsultantSignature` content control near "Yours sincerely" (after roster redesign).
- One tagged `Includes` content control per Table 1 Included row (~9).
- Replace literal placeholder subtotal text with `«Stage2Net»` etc. merge fields.
- Replace `£X,XXX` Fee cells in Included/Optional rows per the resolution mechanism above.

### 5. Testing

- Regression test for `GetSignatoryInfo`'s existing Job-rooted behaviour + new test for the
  Quote-Consultant fallback.
- New unit test(s) for the Include conditional-keep predicate (highest-risk new logic).
- SQL integration test(s) for the extended merge-info view / new metadata.
- End-to-end manual generation against real test quotes (with/without gating products) —
  confirm rows appear/disappear correctly and output still passes `WordDocumentPackageValidator`.
- Follows `cymbuild-add-tests` conventions.

## Progress log

- [x] Branch created: `feature/CYB-323-fee-proposal-auto-population` (off `release/26.3`).
- [x] DEV product-code alignment applied and verified (`CYB-323_ProductCode_Alignment.sql`).
- [x] `SSop.FireEngineering_Fee_Proposal_MergeInfo` extended with `QuotingConsultantPhone` /
      `QuotingConsultantMobile`; registered as merge fields (94 → 96) via
      `CYB-323_FireEngineeringFeeProposal_ConsultantPhoneMobile.sql`. Applied to DEV, verified
      idempotent (safe re-run, no duplicates).
- [x] Consultant-signature resolution: new isolated `EF.Core.GetQuoteConsultantSignatoryInfo`
      (Quotes.QuotingConsultantId -> SCore.Identities), wired into `WordDocumentService.cs`
      only for MergeDocument Guid `c26adae4-cbd1-44a6-876a-1f51d7733ae6` (this template).
      `GetSignatoryInfo`/`SJob.GetJobSignatoryInfo` untouched. Builds clean.
- [x] Include→ProductCode gating: new table `SCore.MergeDocumentItemGatingProducts`
      (`MergeDocumentItemId` + `ProductId`, empty = unconditional/always-included), new
      `EF.Core.GetGatingProductIdsForMergeDocumentItem` / `GetActiveProductIdsForQuote`.
- [x] **Design correction found while implementing:** the actually-called Includes pipeline
      (`WordDocumentService.ProcessIncludesRecursively` / `InsertContentAtBookmarkExtended`)
      only resolves real Word bookmarks (`w:bookmarkStart`), not content-control tags, and is
      built for splicing whole separate sub-documents in - not lightweight per-row
      show/hide. Reusing it for Table 1's rows would have meant fighting a mechanism built for
      a different job. Built a new, isolated mechanism instead: a new `MergeDocumentItemType`
      "Conditional Row" (ID 5) + a new engine step
      (`WordDocumentService.ProcessConditionalRowsAsync` / `RemoveTableRowAtBookmark`) that
      finds a real bookmark placed inside an already-static template table row and deletes the
      whole row when none of its gating products are on the quote. Completely separate from the
      "Includes" splice step - no existing merge document has "Conditional Row" items, so this
      is a no-op everywhere except this template. Builds clean.
      **Consequence for template design:** Table 1's rows should now be authored as real,
      static table rows with the correct fixed text already in place (matching the worked
      example) plus a per-row `«...Fee»` merge field in the Fee cell - not as separate spliced
      sub-documents. Optional rows need nothing beyond this. Included rows additionally get one
      real Word bookmark placed inside the row, matched to a "Conditional Row" item + its
      gating product(s).
- [x] Tests added and passing for everything above that's currently testable without a live
      Quote/QuoteItems SQL fixture (none exist yet in `CymBuild.Database.IntegrationTests` -
      see gap below):
      - `tests/Concursus.EF.Tests/CYB323MergeDocumentQueryGuardTests.cs` - guard-clause
        coverage (default/empty Guid short-circuits before any SQL connection opens) for all
        three new `EF.Core` methods.
      - `tests/Concursus.API.Tests/Documents/WordDocumentServiceConditionalRowTests.cs` -
        `IsFireEngineeringFeeProposalDocument` routing (6 cases incl. case-insensitivity/invalid
        input), and `RemoveTableRowAtBookmark` against a real in-memory OpenXML table (removes
        only the bookmarked row; leaves the document untouched if the bookmark is missing).
        Required making `RemoveTableRowAtBookmark`/`FindBookmarkInDocument` `internal static`
        (pure functions, no instance state) so they're callable from
        `Concursus.API.Tests` without needing a real `GraphServiceClient`.
      - `dotnet test tests/Concursus.EF.Tests/Concursus.EF.Tests.csproj`: 23/23 passed (20
        pre-existing + 3 new, no regressions).
      - `dotnet test tests/Concursus.API.Tests/Concursus.API.Tests.csproj`: 181/181 passed (173
        pre-existing + 8 new, no regressions).
      - Manual smoke test against DEV (insert + join query + trigger fire, then rolled back):
        confirmed `SCore.MergeDocumentItemGatingProducts` inserts, its FK joins to
        `SCore.MergeDocumentItems`/`SProd.Products` resolve correctly, and its RecordHistory
        audit trigger fires without error. No data left behind.
      - **Named gap:** no SQL integration test exercises the real query bodies of
        `GetQuoteConsultantSignatoryInfo` / `GetGatingProductIdsForMergeDocumentItem` /
        `GetActiveProductIdsForQuote` (the actual `SELECT`s against
        `Quotes`/`Identities`/`QuoteItems`/the new gating table) - `CymBuild.Database.IntegrationTests`'
        R4 fixture set only stubs `SCore.Identities`, not `Quotes`/`QuoteItems`/`EnquiryServices`/
        `Enquiries`, and building that fixture chain (Quotes alone has ~10 FK dependencies) is a
        large undertaking of its own. The manual DEV smoke test above is the only real-SQL
        verification these paths have had so far. Recommend either a follow-up task to build
        that fixture chain, or verifying end-to-end via a real test Quote once the template/seed
        data exists (see below).
      - **No regression test needed for `GetSignatoryInfo`/`SJob.GetJobSignatoryInfo`**: zero
        lines of either were changed, so there is no code-level regression surface to test - the
        isolation is structural (a different, new method), not behavioural (an if-branch inside
        the old one).
- [x] **2026-09-28 - stage-aware gating + per-row fields (replaces the "per-row Fee merge
      fields on the view" item).** Per-row fields on `FireEngineering_Fee_Proposal_MergeInfo`
      would have needed two new registered columns per row, per table (Tables 3-14 too).
      Instead the Conditional Row step now emits them itself:
      - `SCore.MergeDocumentItemGatingProducts.RibaStageId` (NOT NULL, default -1 = any
        stage, FK `SJob.RibaStages`); unique index widened to (Item, Product, RibaStage).
        **Not yet in source:** `Schema/Tables|Indexes|Constraints` files for this table are
        workbench-generated from DEV (`-SyncSource`) and hash-verified, so they must not be
        hand-edited. Route: run the DEV-only script `CYB-323_DEV_GatingProducts_RibaStageId.sql`
        (session scratchpad; column + named default, FK, widened index, trigger block) against
        CymBuild_Dev -> Compare -> save selection -> `-SyncSource` -> review/commit the
        generated table-convergence, IndexReplace, FK and default files.
      - `EF.Core.GetGatingRulesForMergeDocumentItem` / `GetQuoteItemMergeLines` replace
        `GetGatingProductIdsForMergeDocumentItem` / `GetActiveProductIdsForQuote`. Quote lines
        carry product, normalised stage (ProvideAtStageID -1 -> stage ID 2, as
        `tvf_QuoteFeeDrawdown`), `LineNet`, and deliverable text (`QuoteItems.Details`,
        falling back to the product Description when blank).
      - `ConditionalRowMergeEvaluator` (pure, unit tested): keep/remove decision; for each kept
        row `«{Bookmark}_Fee»` (sum of matched lines, `£#,##0.00`) and
        `«{Bookmark}_Deliverables»` (distinct text in quote order, joined with "; ");
        `«FeeProposal_Stage{N}Subtotal»` (stages 1-7 zero-filled, plus any other stage number
        on the quote) and `«FeeProposal_TotalNet»`. Pre-formatted because the merge engine
        ignores MERGEFIELD `\#` switches - so the template should use these, **not**
        `«Stage2Net»`/`«TotalNetFees»` (those render as raw `12345.5`).
      - `WordDocumentService.ProcessConditionalRowsAsync` returns those fields; they are
        appended to the merge data before Step 7.
      - Tests: `ConditionalRowMergeEvaluatorTests` (9 new); EF guard tests renamed.
        Concursus.API.Tests 221/221, Concursus.EF.Tests 23/23.
- [x] Seed script written (not yet applied anywhere):
      `Database/CymBuild_DB/Scripts/Upgrade Scripts/CYB-323_FireEngineeringFeeProposal_MergeDocumentItems.sql`
      - 1 Signature item + 16 Conditional Row items + 23 gating rules, fixed Guids, via
      `SCore.MergeDocumentItemsUpsert` (creates DataObjects). Validates dependencies and
      throws before changing anything. Parse-checked only.

  Bookmark map (place each bookmark inside its row in the template):

  | Bookmark | Row | Gating (product @ RIBA stage) |
  |---|---|---|
  | `FP_T1_QDR` | T1 QDR | QDR @ any |
  | `FP_T1_S2_MKD` | T1 Stage 2 marked-up drawings | MKD @ 2 |
  | `FP_T1_S2_GW1D12` | T1 Stage 2 Gateway One + D12 | GW1 @ 2, D12 @ 2 |
  | `FP_T1_S2_MTG` | T1 Stage 2 meetings | MKD/GW1/D12 @ 2 |
  | `FP_T1_S3_DFS` / `FP_T1_S3_MTG` | T1 Stage 3 strategy / meetings | DFS @ 3, MKD @ 3 |
  | `FP_T1_S4_DFS` / `FP_T1_S4_MTG` | T1 Stage 4 strategy / meetings | DFS @ 4, MKD @ 4 |
  | `FP_T2_QDR_KEEP` | T2 Stage 2 QDR report | QDR @ any (fee only) |
  | `FP_T2_S2_MKD_KEEP` / `_GW1_KEEP` | T2 Stage 2 drawings / Gateway One | that product @ 2 (fee only) |
  | `FP_T2_S2_D12_KEEP` | T2 Stage 2 D12 | D12 @ 2 (fee only) |
  | `FP_T2_S3_MKD_KEEP` / `_DFS_KEEP` | T2 Stage 3 markups / strategy | that product @ 3 (fee only) |
  | `FP_T2_S4_MKD_KEEP` / `_DFS_KEEP` | T2 Stage 4 markups / strategy | that product @ 4 (fee only) |

  Every Table 2 row is `_KEEP`: always shown, fee blank unless that item is quoted
  (Jira 810439, AC9).
  | `ConsultantSignature` | Signature (content control) | - |

  Static (no item): PI insurance, all Optional rows, mobilisation fee rows (left as `£X,XXX`
  for manual entry), subtotal rows, Stage 5 support, Recommended Additional Services.
- [x] **2026-10-01 - environments + seed fix.** DEV and CymBuild_QA2 (QA; not CymBuild_QA)
      both have RibaStageId and are seeded. QA2 is a LIVE replica with duplicate active
      products (FIRE-DFS 82/3179, FIRE-SIT 76/3262). The seed now gates every active product
      per code, matched on (item, product, stage) (`315476ba`). QA2: 30 rows; DEV unchanged at 24.
- [x] **2026-10-01 - vertical-merge handover.** Removing a conditional row that starts a
      vertical merge (the Table 1 stage label, the Table 2 "Stage 3/4 fire strategy" label,
      the Stage 3/4 fee cell) now hands the content and the restart down to the next row
      (`WordDocumentService.HandOverVerticalMergeRestarts`). Without it, the stage label was
      deleted whenever the stage's first row was removed. 3 new tests; Concursus.API.Tests
      224/224.
- [x] **2026-10-01 - template edited (local copy, for review).** A scripted OpenXML SDK edit
      of the 15 Sep extract (`EditTemplate.cs`, session scratchpad): 17 bookmarks (Table 1 in
      the Deliverables cell, Table 2 in the Invoice schedule cell, never a merged cell);
      `_Fee`/`_Deliverables` fields; stage 2/3/4 subtotals and `FeeProposal_TotalNet`.
      The 18-person roster (and its 17 images and the obsolete "Put your signature" comment
      thread) is replaced by a `ConsultantSignature` content control plus
      `QuotingConsultant{PostNominals,JobTitle,Mobile,Phone,Email}`. Schema validation is
      unchanged vs the original (2 pre-existing style errors). A simulation through the
      engine's real row-removal and merge code resolved all 19 fields.
      **Found in the template:** 88 tracked insertions and 189 tracked deletions, never
      accepted (mostly Ashish Kirori). They will appear in every generated proposal until
      the template owner accepts or rejects them.
- [x] **2026-10-01 - client/project details (correction to Design §2).** The template's 14
      "Company Name"/"Project Name"/"16XXXX"/"Issue X"/date boxes were Word document-property
      content controls (bound to Company/Subject/Title/Status/PublishDate). No merge field
      matched them, so they would never populate. The editor now unbinds and retags them:
      `ClientName`, `ProjectName`, `QuoteNumber`, `FeeProposal_GeneratedDate`, and
      "Issue «FeeProposal_IssueNumber»". The two new fields are computed in the API for this
      document only (`ConditionalRowMergeEvaluator.BuildDocumentMergeFields`). Issue =
      `SSop.Quotes.RevisionNumber`, or 1 when it is 0 or less (user decision). The date is the
      UK generation date, dd/MM/yyyy. 7 new tests; Concursus.API.Tests 231/231. A review copy
      (`FeeProposal_CYB-323_REVIEW.docx`) highlights automatic content yellow and gated rows
      green.
- [x] **2026-10-05 - QA2 end-to-end, quotes 3724 / 3757 / 3930** (local API on this branch,
      CymBuild_QA2, merge document 122 pointed at the test template):
      - Gating, fees, deliverables (with line breaks), subtotals, totals, the vertical-merge
        handover, cover controls (client, project, quote number, Issue 1, date), consultant name
        and title, and signature-box removal all worked. No `«»` left in any document.
      - 3724 matched the prediction exactly: 11 gated rows kept and 5 removed; £6,500 / £6,500 /
        £4,500; total £21,800.
      - **Not yet verified:** project address, letter recipient block and "Dear «ClientFirstName»".
        All three documents still show "Address", "Name Surname ... POST CODE", "Dear Name," and
        "Located at xxxxx". The SharePoint test file is an older build; the current
        `EditTemplate.cs` output contains those fields.
      - New BA questions: (a) stage subtotals count every quote item at that stage, including
        ones with no row of their own. On 3757 the Stage 2 subtotal of £5,800 includes FIRE-SIT
        "Site Visit" (£1,800), but only a £4,000 row is shown. (b) A stage with no gated items
        still shows its label and a £0.00 subtotal (3930, which has only a CDM-H&S stage 5 item).
        (c) In Table 2, "(minus mobilisation fee)" is the D12 row's own schedule text in the
        template, so it disappears whenever D12 is not quoted (3757).
- [x] **2026-10-06 - letter fields verified.** After the current build was uploaded to the test
      file, regenerated 3724 shows "915 Parsons Street" (cover and project overview), the
      "Cherlyn Humphrey / Marantz (22) / 137-145 Church Road, / Harold Wood / RM3 0SH" block and
      "Dear Obdulia,". The cover controls carry the client, project, quote number, Issue 1 and
      date, with no "Company Name"/"16XXXX"/"Issue X" text left. The tables are unchanged
      (£21,800).
- [x] **2026-10-08 - BA answer to Q2 (Jira 809134), option C implemented.** Included rows only
      when quoted (already the gating behaviour); Optional rows always shown (already static).
      Her reply also listed B (hide the stage), but every stage has Optional rows, so we read it
      as C. Our confirmation and a check on "I in the scope column" were posted as Jira 809155
      (quote items have no I/O field; we assume she means the template's Table 1 Included column).
      `BuildStageSubtotalMergeFields` now emits a blank subtotal for a stage with no quote lines
      (still £0.00 when lines exist but net to zero; the grand total is unchanged). 2 new tests;
      Concursus.API.Tests 241/241. Q1, Q3 and Q4 are still open.
- [x] **2026-10-09 - BA answers to Q1, Q3, Q4 (Jira 809245); follow-ups posted (Jira 809875).**
      Q1 = B: every quote item gets a row and the totals match the quote (new engine work:
      a per-stage catch-all row cloned once per quote line that no Conditional Row matches,
      plus a new Stage 1 section; not started). Q4 = A: PI stays out of the grand total (no
      change). Q3: the Table 2 D12 row now reads "Upon delivery of initial issue of D12 Fire
      Statement (minus mobilisation fee)" (`EditTemplate.cs` `ScheduleText`, set before the
      bookmark goes in the cell). Simulated with D12 quoted and no drawings: the D12 row reads
      in full. The drawings row keeps its old text until the BA answers 809875 Q4.
      Open in 809875: unmatched rows in Table 2 too?; stage 5-7 placement; FIRE-SIT vs the
      optional Site Visit row; drawings row wording; hide an empty Stage 1.
- [x] **2026-10-09 - Q1 option B implemented (BA follow-ups, Jira 809875 answered: Table 1
      only; a section per stage that has items; optional Site Visit row and Table 2 drawings
      wording unchanged; hide an empty Stage 1).**
      - Engine: a gating rule with ProductId -1 is a catch-all. It matches quote lines no
        product rule in the document claims - at its RIBA stage, or (stage -1) whatever no stage
        catch-all takes - so every line is shown once and the rows add up to the quote total.
        A Conditional Row whose bookmark ends `_EACH` is repeated once per matched line
        (`WordDocumentService.RepeatTableRowAtBookmark`); copy n reads `«{bookmark}_Fee_n»` /
        `«{bookmark}_Deliverables_n»`, and a vertically merged label continues through the copies.
      - Template (`EditTemplate.cs`): `FP_T1_S2/S3/S4_EACH` above each stage subtotal; new
        sections for Stages 0, 1, 5, 6, 7 and "Other fees" (non-RIBA stages such as 999
        Construction and 105 Other Fees, seen on QA2 Fire Engineering quotes) - label + `_EACH`,
        `_SUB` subtotal (`«{bookmark}_Fee»`), `_GAP` spacer - removed when nothing is quoted
        there. Cloned rows drop the template's old tracked-change markup (schema errors stay at
        the original 2).
      - Seed: 21 new items and catch-all rules (ProductCode NULL = ProductId -1); compiles on
        Dev264 under NOEXEC (not applied).
      - `SimulateMerge.cs` now drives the real evaluator: sample total £19,550 equals the
        Table 1 grand total; Stage 1 (£4,300), Stage 5 and Other sections shown; 0/6/7 hidden.
      - Tests: 13 new; Concursus.API.Tests 256/256, Architecture 255/255.
      - Known quirk (unchanged): the QDR row sits above Stage 2 but its fee counts in the
        Stage 2 subtotal, so Stage 2's subtotal exceeds the rows inside the Stage 2 section.
- [x] **2026-10-12 - Table 2 D12 row always shown (Jira 810439).** Dorothy checked the 3757
      PDF: everything fine except the Table 2 D12 row ("... (minus mobilisation fee)") was
      hidden; it is part of the invoice schedule, so it must always appear. A bookmark ending
      `_KEEP` is now always kept; its rules only fill `«{bookmark}_Fee»`, and a fee with no
      matched lines is blank instead of £0.00 (user decision). `FP_T2_S2_D12` is renamed
      `FP_T2_S2_D12_KEEP` in the template and the seed (same item Guid, so re-running the seed
      renames the existing item). `SimulateMerge.cs <outDir> 3757` now reproduces quote 3757:
      the D12 row stays with a blank amount. Tests: 3 new; Concursus.API.Tests 288/288.
      Needs: seed re-run on Dev264 and QA2, new template upload to the SharePoint test file.
- [x] **2026-10-12 - every Table 2 row always shown (Jira 810439, option A).** Dorothy
      confirmed AC9: the whole invoicing schedule is generated, and users delete the rows they
      don't need. The other seven Table 2 bookmarks are renamed to `_KEEP` in the template and
      the seed (same item Guids, renamed in place). `SimulateMerge.cs <outDir> 3757` shows all
      Table 2 rows; unquoted ones (QDR, D12, Gateway One, Stage 3/4 markups) have a blank fee.
      Needs: seed re-run on Dev264 and QA2, template upload to the SharePoint test file.
- [ ] Business sign-off on the template wording and the open BA questions, then upload the
      final template over the live file and revert merge document 122 on DEV and QA2.

## Paused 2026-09-29 - resume here

Committed and pushed on this branch: `3d30dc21` (code, tests, seed script, plan) and the schema
sync in `20f90463` "SQL Migration to QA2" (generated `RibaStageId` table alter, default, FK,
3-column unique index).

1. Trigger: `tg_MergeDocumentItemGatingProducts_RecordHistory` has the `RibaStageId` block in
   DEV only - the canonical Tables file was not regenerated. Include the table's trigger in the
   next Compare/`-SyncSource` selection (small audit-history gap until then).
2. The default was synced as `DF_SCore_MergeDocumentItemGatingProducts_RibaStageId`, not
   renamed first. Leave it as is - a rename would need its own migration.
3. Confirm which environments have the schema (commit says QA2) and whether the seed script
   `CYB-323_FireEngineeringFeeProposal_MergeDocumentItems.sql` has been run on DEV - not
   confirmed. Check its verify output against the bookmark map.
4. Template editing - the 15 Sep extract (`%TEMP%\claude\template2026_extract`) is confirmed
   current; no original .docx saved there.
5. End-to-end test against a real quote.

Do not deploy the code to an environment before its schema has `RibaStageId`.

## Decisions made

1. **PI insurance row:** always shown, unconditional. No "Conditional Row" item needed for it
   at all - ships as plain static content.
2. **Combined-product rows** (e.g. Gateway One + D12 in one line): shown if *either* gating
   product is present; Fee = sum of whichever are actually on the quote.
3. **Template editing:** Claude scripts it against a local copy of the template for review,
   rather than the user hand-editing in Word or Claude touching the live SharePoint file
   directly.
4. **(2026-09-28) Rendering approach:** stay with the Word-template merge engine; runtime
   HTML-to-docx generation rejected (Word output quality, business ownership of template wording,
   second rendering pipeline).
5. **(2026-09-28) Gating is product + RIBA stage** (DFS appears in Stage 3 and Stage 4).
6. **(2026-09-28) Meetings rows follow their stage's main rows.**
7. **(2026-09-28) Deliverables come from the quote item** (Jira AC3), not fixed template text.
8. **(2026-09-28) Mobilisation fees stay `£X,XXX`** for manual entry.

## Open items still needing a decision

1. 5 orphan products in `SProd.Products` (not in the spec doc) — keep, retire, or spec needs
   updating?
2. Align `CymBuild_QA` product codes now, or leave to user alongside LIVE?
3. Assumptions to confirm with the BA: Stage 3/4 strategy rows also gate on (and sum) FIRE-MKD
   at that stage; QDR is not counted as a "Stage 2" row for the Stage 2 meetings row;
   "Description" in AC3 means the quote item's Details text.
