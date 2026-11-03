/*
    CymBuild 26.4 - all manual SQL after the release, in one script (UAT_TEST, then LIVE).

      Section 1  CYB-585  SJob.FeeAmendmentStatus reference rows (Pending / Agreed / Rejected)
      Section 2  CYB-569  EXEC SCore.WorkflowStatusMergeDuplicates (release step: merge the
                          duplicate New / Quoting / Declined statuses)
      Section 3  CYB-553  Shore legacy tidy-up + the 24 listed quotes to Building Control Consultancy
      Section 4  CYB-553  Record Status grid (RECORDSTATUS) shows system-written statuses such as
                          the automatic "Expired" (LEFT JOIN the identity lookups); a no-op if the
                          metadata workbench already promoted it
      Section 5  Read-only check that every 26.4 change is present (expect 1 on every row)

    Every section is idempotent and comes unchanged from Upgrade Scripts / the procedure in
    release/26.4; only its own "preview/apply" switch is wired to the one setting below.

    HOW TO RUN (SSMS or sqlcmd -b)
      1. As is (@Apply = 0): a full preview. Nothing is changed.
      2. Set @Apply = 1 and @ActingUserID = your SCore.Identities.ID in THIS database:
             SELECT ID, FullName FROM SCore.Identities WHERE EmailAddress = N'you@socotec.co.uk';
         then run the whole script again.
      3. Run it once more with @Apply = 0: sections 1-4 report nothing left to do and
         section 5 shows 1 on every row.
    If a section fails, the later sections skip themselves; fix the cause and re-run the lot.
    Large environments: sections 2 and 3 keep record history on and can take a long time on
    slow disks (UAT_TEST took over an hour for section 3). Run LIVE out of hours.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO
-------------------------------------------------------------------------------
-- Settings (the only two lines to edit)
-------------------------------------------------------------------------------
DECLARE @Apply BIT = 0;              -- 0 = preview everything, 1 = apply everything
DECLARE @ActingUserID INT = NULL;    -- your SCore.Identities.ID in this database (required to apply)

EXEC sys.sp_set_session_context @key = N'CYB264.Stage', @value = NULL;

IF @Apply = 1 AND NOT EXISTS (SELECT 1 FROM SCore.Identities AS i WHERE i.ID = @ActingUserID AND i.ID > 0 AND i.RowStatus NOT IN (0, 254))
BEGIN
    RAISERROR(N'Set @ActingUserID to your active SCore.Identities.ID in this database before applying.', 16, 1);
    RETURN;
END;

EXEC sys.sp_set_session_context @key = N'CYB264.Apply', @value = @Apply;
EXEC sys.sp_set_session_context @key = N'CYB264.ActingUserID', @value = @ActingUserID;
-- Section 2's record-history audit is attributed to the acting user.
IF @ActingUserID IS NOT NULL
    EXEC sys.sp_set_session_context @key = N'user_id', @value = @ActingUserID;

SELECT Section = N'Settings', Database_ = DB_NAME(), Mode = CASE WHEN @Apply = 1 THEN N'APPLY' ELSE N'PREVIEW' END,
       ActingUser = (SELECT i.FullName FROM SCore.Identities AS i WHERE i.ID = @ActingUserID);
EXEC sys.sp_set_session_context @key = N'CYB264.Stage', @value = 0;
GO
-------------------------------------------------------------------------------
-- Section 1: CYB-585 (from Upgrade Scripts/CYB-585_26.4_FeeAmendmentStatus_ReferenceRows.sql)
-------------------------------------------------------------------------------
-- Section guard: skip if an earlier section did not finish (SSMS runs later batches after an error).
IF ISNULL(CONVERT(INT, SESSION_CONTEXT(N'CYB264.Stage')), -1) <> 0
BEGIN
    RAISERROR(N'Section skipped: the settings or an earlier section did not complete. Fix that and run the whole script again.', 16, 1);
    RETURN;
END;
/*
    CYB-585 (26.4): SJob.FeeAmendmentStatus reference rows.

    The automated deploy creates a new table with only its -1 row; reference rows are copied by hand
    after deployment. Without these rows the Fee Amendment Status list is blank, a new amendment
    cannot be saved ("The value is compulsory"), and SJob.FeeAmendmentsUpsert, SJob.FeeAmendmentsValidate,
    SJob.ActivityFeeAmendmentEnsure and SJob.Job_FeeDrawdown cannot find the statuses they key on by Guid.

    Rows match CymBuild_Dev and CymBuild_QA (16 Oct 2026): same Guid, Name, SortOrder and, where free, ID.

    Run after the 26.4 deployment, on any environment. Safe to re-run.
      1. Preview (default): @Apply = 0 does everything inside a transaction and rolls it back.
      2. Apply:             set @Apply = 1 and run again.
    It stops (THROW) instead of guessing if the table, its entity type or a conflicting row is not as expected.

    sqlcmd -S <server> -d <database> -E -C -b -f 65001 -i "CYB-585_26.4_FeeAmendmentStatus_ReferenceRows.sql"
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Apply BIT = ISNULL(CONVERT(BIT, SESSION_CONTEXT(N'CYB264.Apply')), 0);   -- from the settings at the top

DECLARE @Rows TABLE (ID INT NOT NULL, Guid UNIQUEIDENTIFIER NOT NULL, Name NVARCHAR(150) NOT NULL, SortOrder INT NOT NULL);
INSERT @Rows (ID, Guid, Name, SortOrder)
VALUES  (1, '68C95270-1BB9-4E8B-BE4C-38746C4661BB', N'Pending',  1),
        (2, '215F258A-CF79-468F-9EB8-A84481F7F8AF', N'Agreed',   2),
        (3, '3D66CEDB-A2FB-48CF-BAA3-69B728F374DA', N'Rejected', 3);

IF OBJECT_ID(N'SJob.FeeAmendmentStatus', N'U') IS NULL
    THROW 60585, N'SJob.FeeAmendmentStatus does not exist - deploy the 26.4 schema first.', 1;

-- A row with one of these names under a different Guid would break the unique name index; decide by hand.
IF EXISTS (SELECT 1 FROM SJob.FeeAmendmentStatus AS fas JOIN @Rows AS r ON (r.Name = fas.Name AND r.Guid <> fas.Guid))
    THROW 60586, N'SJob.FeeAmendmentStatus already has a Pending/Agreed/Rejected row under a different Guid - stop and inspect.', 1;

-- DataObjects rows take the entity type registered for the table (as SCore.UpsertDataObject does).
-- SJob.FeeAmendmentStatus has no HoBT in DEV or QA (16 Oct 2026): their status rows use the
-- zero-Guid entity type (ID -1), so that is used here too, matched by Guid rather than by ID.
DECLARE @EntityTypeId INT =
(
    SELECT TOP (1) eh.EntityTypeID
    FROM   SCore.EntityHobts AS eh
    WHERE  eh.SchemaName = N'SJob' AND eh.ObjectName = N'FeeAmendmentStatus' AND eh.RowStatus NOT IN (0, 254)
    ORDER BY eh.ID
);

IF @EntityTypeId IS NULL
    SELECT @EntityTypeId = et.ID
    FROM   SCore.EntityTypes AS et
    WHERE  et.Guid = '00000000-0000-0000-0000-000000000000';

IF @EntityTypeId IS NULL
   AND EXISTS (SELECT 1 FROM @Rows AS r WHERE NOT EXISTS (SELECT 1 FROM SCore.DataObjects AS d WHERE d.Guid = r.Guid))
    THROW 60587, N'No SJob.FeeAmendmentStatus HoBT and no zero-Guid SCore.EntityTypes row, so the DataObjects entity type is unknown - stop and inspect.', 1;

BEGIN TRANSACTION;

INSERT INTO SCore.DataObjects (Guid, RowStatus, EntityTypeId)
SELECT  r.Guid, 1, @EntityTypeId
FROM    @Rows AS r
WHERE   NOT EXISTS (SELECT 1 FROM SCore.DataObjects AS d WHERE d.Guid = r.Guid);

PRINT CONCAT(N'DataObjects rows added: ', @@ROWCOUNT);

-- Keep DEV's ID where it is free, so IDs line up across environments.
SET IDENTITY_INSERT SJob.FeeAmendmentStatus ON;

INSERT INTO SJob.FeeAmendmentStatus (ID, RowStatus, Guid, Name, SortOrder)
SELECT  r.ID, 1, r.Guid, r.Name, r.SortOrder
FROM    @Rows AS r
WHERE   NOT EXISTS (SELECT 1 FROM SJob.FeeAmendmentStatus AS fas WHERE fas.Guid = r.Guid)
  AND   NOT EXISTS (SELECT 1 FROM SJob.FeeAmendmentStatus AS fas WHERE fas.ID = r.ID);

PRINT CONCAT(N'Status rows added with DEV IDs: ', @@ROWCOUNT);

SET IDENTITY_INSERT SJob.FeeAmendmentStatus OFF;

INSERT INTO SJob.FeeAmendmentStatus (RowStatus, Guid, Name, SortOrder)
SELECT  1, r.Guid, r.Name, r.SortOrder
FROM    @Rows AS r
WHERE   NOT EXISTS (SELECT 1 FROM SJob.FeeAmendmentStatus AS fas WHERE fas.Guid = r.Guid);

PRINT CONCAT(N'Status rows added with new IDs (DEV ID already taken): ', @@ROWCOUNT);

-- An existing row keeps its ID but is brought back to the source values.
UPDATE  fas
SET     fas.Name = r.Name, fas.SortOrder = r.SortOrder, fas.RowStatus = 1
FROM    SJob.FeeAmendmentStatus AS fas
JOIN    @Rows AS r ON (r.Guid = fas.Guid)
WHERE   fas.Name <> r.Name OR fas.SortOrder <> r.SortOrder OR fas.RowStatus <> 1;

PRINT CONCAT(N'Status rows corrected: ', @@ROWCOUNT);

-- Verification - every row should read OK.
SELECT  r.Name AS Status,
        CASE WHEN fas.ID IS NOT NULL AND d.Guid IS NOT NULL THEN N'OK' ELSE N'FAIL' END AS Result,
        fas.ID, fas.Guid, fas.SortOrder
FROM    @Rows AS r
LEFT JOIN SJob.FeeAmendmentStatus AS fas ON (fas.Guid = r.Guid AND fas.RowStatus NOT IN (0, 254))
LEFT JOIN SCore.DataObjects AS d ON (d.Guid = r.Guid)
ORDER BY r.SortOrder;

IF @Apply = 1
BEGIN
    COMMIT TRANSACTION;
    PRINT N'Applied.';
END
ELSE
BEGIN
    ROLLBACK TRANSACTION;
    PRINT N'Preview only - rolled back. Set @Apply = 1 to apply.';
END;

EXEC sys.sp_set_session_context @key = N'CYB264.Stage', @value = 1;
GO
-------------------------------------------------------------------------------
-- Section 2: CYB-569 merge duplicate workflow statuses (release step)
-------------------------------------------------------------------------------
-- Section guard: skip if an earlier section did not finish (SSMS runs later batches after an error).
IF ISNULL(CONVERT(INT, SESSION_CONTEXT(N'CYB264.Stage')), -1) <> 1
BEGIN
    RAISERROR(N'Section skipped: the settings or an earlier section did not complete. Fix that and run the whole script again.', 16, 1);
    RETURN;
END;
DECLARE @WhatIf BIT = CASE WHEN ISNULL(CONVERT(BIT, SESSION_CONTEXT(N'CYB264.Apply')), 0) = 1 THEN 0 ELSE 1 END;
IF OBJECT_ID(N'SCore.WorkflowStatusMergeDuplicates', N'P') IS NULL
BEGIN
    RAISERROR(N'SCore.WorkflowStatusMergeDuplicates is missing: the 26.4 schema did not deploy.', 16, 1);
    RETURN;
END;
EXEC SCore.WorkflowStatusMergeDuplicates @WhatIf = @WhatIf;
EXEC sys.sp_set_session_context @key = N'CYB264.Stage', @value = 2;
GO
-------------------------------------------------------------------------------
-- Section 3: CYB-553 (from Upgrade Scripts/CYB-553_ShoreLegacy_ExpireAndDefaultOrgUnit.sql)
-------------------------------------------------------------------------------
-- Section guard: skip if an earlier section did not finish (SSMS runs later batches after an error).
IF ISNULL(CONVERT(INT, SESSION_CONTEXT(N'CYB264.Stage')), -1) <> 2
BEGIN
    RAISERROR(N'Section skipped: the settings or an earlier section did not complete. Fix that and run the whole script again.', 16, 1);
    RETURN;
END;
/*
    CYB-553: tidy up Shore CDM legacy enquiries, quotes and jobs.

    Business decision (Dorothy Osubor / Jo-Ann Porter, Oct 2026): no development
    fix for historical jobs; instead IT bulk-updates the Shore CDM records that
    were migrated into CymBuild before February 2024:

      1. Enquiries and quotes that were never converted to a job are marked as
         expired, so they can be left out of reporting. CDM admins keep access:
         an Expired quote is read-only except for quote superusers (CYB-461).
      2. Enquiries, quotes and jobs with no Org/BU get one, without changing any
         Org/BU that is already set.

    What this script does
    ---------------------
    Shore record = SSop.Quotes.LegacySystemID / SJob.Jobs.LegacySystemID =
    @ShoreLegacySystemID (SCore.LegacySystems "Shore CDM"), dated before
    @MigratedBefore. A Shore enquiry is the enquiry of a Shore quote
    (Quotes.EnquiryServiceID -> EnquiryServices.EnquiryId; one quote each).

    Part 1 - expire (status changes go through SCore.DataObjectTransitionUpsert,
    never directly, exactly as SSop.ExpireOverdueQuotesAndEnquiries does):
      - Quotes: never converted (no quote item has a CreatedJobId) and still
        open, i.e. the latest saved status is NOT one of the closed statuses
        below. Already Expired, Rejected, Declined, Dead, Withdrawn or Complete
        quotes are left alone - their status is still true.
      - Enquiries: still open, and every quote on the enquiry is (or is about
        to be) Expired and was never converted. Expiring the quote may already
        have synced the enquiry, so each enquiry is re-checked before writing.
      - The change is silent (no notifications, no RecordHistory), like the
        CYB-461 backlog, and carries a comment naming this change.
    Part 2 - default Org/BU (only where OrganisationalUnitID = -1):
      - Quotes: the Org/BU of a job created from the quote if it has one,
        otherwise @DefaultOrgUnitGuid (CDM Consulting).
      - Enquiries: the Org/BU their quote ends up with.
      - Jobs: @DefaultOrgUnitGuid.
      Notifications are suppressed; RecordHistory triggers still audit the
      change under @ActingUserID.
    Part 3 - quotes listed by the business to move to Building Control
    Consultancy (Dorothy, CYB-553, 2026-10-20; meeting decision "update
    organisational units for the identified quotes to Building Control
    Consultancy"). These are current CymBuild quotes, not Shore records: they
    sit on "Building & Real Estate Admin" (the parent of Building Control
    Consultancy, same security group) while their enquiries are already on
    Building Control Consultancy. Matched by quote number + revision; a quote
    moves only while it is still on Building & Real Estate Admin, so nothing
    else is overridden. Jobs created from them are not changed.

    Closed statuses (by name, as SSop.Quote_CalculatedFields reports them):
      Expired, Quote Expired, Rejected, Declined, Declined To Quote, Dead,
      Withdrawn, Complete, Part Complete.

    @DryRun = 1 (default) only reads: it lists what would change, with counts.
    @DryRun = 0 writes. Run on LIVE out of hours, after QA2.
    Safe to re-run: expired records and filled Org/BUs no longer qualify.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_WARNINGS ON;
SET ANSI_NULLS ON;          -- sqlcmd defaults QUOTED_IDENTIFIER OFF; the filtered
SET QUOTED_IDENTIFIER ON;   -- indexes on the updated tables need both ON (Msg 1934)

DECLARE @DryRun BIT = CASE WHEN ISNULL(CONVERT(BIT, SESSION_CONTEXT(N'CYB264.Apply')), 0) = 1 THEN 0 ELSE 1 END;   -- from the settings at the top
DECLARE @ActingUserID INT = CONVERT(INT, SESSION_CONTEXT(N'CYB264.ActingUserID'));   -- from the settings at the top                 -- SCore.Identities.ID of the person running this (audit trail)
DECLARE @ShoreLegacySystemID INT = 1;              -- SCore.LegacySystems: Shore CDM
DECLARE @MigratedBefore DATE = '20240201';
DECLARE @DefaultOrgUnitGuid UNIQUEIDENTIFIER = '2C9489BD-EAE8-4703-90D7-56C94E802EDA';   -- CDM Consulting
DECLARE @ExpiredStatusGuid UNIQUEIDENTIFIER = 'E6FAC201-F98B-4B3A-AB55-83DC9F802D00';    -- Expired (CYB-461)
DECLARE @BatchSize INT = 1000;                    -- Org/BU updates per transaction
DECLARE @BccFromOrgUnitGuid UNIQUEIDENTIFIER = 'F233BB03-3181-49AE-B331-39C58F328457';   -- Building & Real Estate Admin
DECLARE @BccOrgUnitGuid UNIQUEIDENTIFIER = '0125329F-003B-4CE4-A2C9-8C6DCC1A4DFF';       -- Building Control Consultancy

-- Part 3: the quotes the business listed (number, revision).
DECLARE @BccQuotes TABLE (Number NVARCHAR(50) NOT NULL, RevisionNumber INT NOT NULL, PRIMARY KEY (Number, RevisionNumber));
INSERT INTO @BccQuotes (Number, RevisionNumber)
VALUES (N'2940', 0), (N'2323', 0), (N'2320', 0), (N'2133', 0), (N'2123', 1), (N'2132', 0),
       (N'2130', 0), (N'2129', 0), (N'2125', 0), (N'2123', 0), (N'2121', 0), (N'2119', 0),
       (N'2118', 0), (N'2117', 0), (N'2116', 0), (N'2115', 0), (N'2114', 0), (N'2112', 0),
       (N'2106', 0), (N'2101', 0), (N'2100', 0), (N'2099', 0), (N'2098', 0), (N'2095', 0);

DECLARE @Comment NVARCHAR(MAX) =
    N'CYB-553: Shore CDM record migrated before February 2024 and never converted to a job; expired in bulk at the business''s request so it can be left out of reporting.';
DECLARE @EmptyGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';

-------------------------------------------------------------------------------
-- Preconditions
-------------------------------------------------------------------------------
IF @@TRANCOUNT > 0
BEGIN
    ;THROW 60000, N'Run this script outside a transaction.', 1;
END;

DECLARE @ActingUserGuid UNIQUEIDENTIFIER =
(
    SELECT i.Guid
    FROM SCore.Identities AS i
    WHERE i.ID = @ActingUserID
      AND i.ID > 0
      AND i.RowStatus NOT IN (0, 254)
);

IF @DryRun = 0 AND @ActingUserGuid IS NULL
BEGIN
    ;THROW 60000, N'Set @ActingUserID to your active SCore.Identities.ID before running with @DryRun = 0.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM SCore.LegacySystems AS ls
    WHERE ls.ID = @ShoreLegacySystemID
      AND ls.Name = N'Shore CDM'
)
BEGIN
    ;THROW 60000, N'SCore.LegacySystems @ShoreLegacySystemID is not "Shore CDM" in this database.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM SCore.WorkflowStatus AS ws
    WHERE ws.Guid = @ExpiredStatusGuid
      AND ws.RowStatus NOT IN (0, 254)
      AND ws.Enabled = 1
      AND ws.ShowInQuotes = 1
      AND ws.ShowInEnquiries = 1
)
BEGIN
    ;THROW 60000, N'The "Expired" workflow status (E6FAC201-...) is missing or not enabled for quotes and enquiries.', 1;
END;

DECLARE @DefaultOrgUnitID INT =
(
    SELECT ou.ID
    FROM SCore.OrganisationalUnits AS ou
    WHERE ou.Guid = @DefaultOrgUnitGuid
      AND ou.RowStatus NOT IN (0, 254)
);

IF @DefaultOrgUnitID IS NULL OR @DefaultOrgUnitID <= 0
BEGIN
    ;THROW 60000, N'The default Org/BU (CDM Consulting, 2C9489BD-...) is missing or inactive.', 1;
END;

DECLARE @ClosedStatuses TABLE (Name NVARCHAR(250) NOT NULL PRIMARY KEY);
INSERT INTO @ClosedStatuses (Name)
VALUES (N'Expired'), (N'Quote Expired'), (N'Rejected'), (N'Declined'), (N'Declined To Quote'),
       (N'Dead'), (N'Withdrawn'), (N'Complete'), (N'Part Complete');

-------------------------------------------------------------------------------
-- What qualifies
-------------------------------------------------------------------------------
DROP TABLE IF EXISTS #ShoreQuotes;

SELECT
    q.ID,
    q.Guid,
    q.Number,
    q.Date,
    q.OrganisationalUnitID,
    EnquiryID          = ISNULL(es.EnquiryId, -1),
    HasJob             = CASE WHEN job.JobOrgUnitID IS NOT NULL OR job.AnyJob = 1 THEN 1 ELSE 0 END,
    JobOrgUnitID       = job.JobOrgUnitID,
    LatestStatusGuid   = latest.StatusGuid,
    LatestStatusName   = ISNULL(latest.StatusName, N'(none)'),
    IsOpen             = CASE WHEN latest.StatusName IN (SELECT cs.Name FROM @ClosedStatuses AS cs) THEN 0 ELSE 1 END
INTO #ShoreQuotes
FROM SSop.Quotes AS q
LEFT JOIN SSop.EnquiryServices AS es
    ON es.ID = q.EnquiryServiceID
   AND es.RowStatus NOT IN (0, 254)
OUTER APPLY
(
    SELECT
        AnyJob = MAX(CASE WHEN qi.CreatedJobId > 0 THEN 1 ELSE 0 END),
        JobOrgUnitID = MAX(CASE WHEN j.OrganisationalUnitID > 0 THEN j.OrganisationalUnitID END)
    FROM SSop.QuoteItems AS qi
    LEFT JOIN SJob.Jobs AS j
        ON j.ID = qi.CreatedJobId
       AND j.RowStatus NOT IN (0, 254)
    WHERE qi.QuoteId = q.ID
      AND qi.RowStatus NOT IN (0, 254)
      AND qi.CreatedJobId > 0
) AS job
OUTER APPLY
(
    SELECT TOP (1)
        StatusGuid = ws.Guid,
        StatusName = ws.Name
    FROM SCore.DataObjectTransition AS dot
    JOIN SCore.WorkflowStatus AS ws
        ON ws.ID = dot.StatusID
    WHERE dot.DataObjectGuid = q.Guid
      AND dot.RowStatus NOT IN (0, 254)
    ORDER BY dot.ID DESC
) AS latest
WHERE q.RowStatus NOT IN (0, 254)
  AND q.LegacySystemID = @ShoreLegacySystemID
  AND q.Date < @MigratedBefore;

-- Quotes to expire: never converted and still open.
DROP TABLE IF EXISTS #QuotesToExpire;

SELECT sq.ID, sq.Guid, sq.Number, OldStatusGuid = ISNULL(sq.LatestStatusGuid, @EmptyGuid), sq.LatestStatusName
INTO #QuotesToExpire
FROM #ShoreQuotes AS sq
WHERE sq.HasJob = 0
  AND sq.IsOpen = 1;

-- Enquiries to expire: still open, and every quote on them is never converted
-- and either already Expired or about to be.
DROP TABLE IF EXISTS #EnquiriesToExpire;

SELECT
    e.ID,
    e.Guid,
    e.Number,
    OldStatusGuid    = ISNULL(latest.StatusGuid, @EmptyGuid),
    LatestStatusName = ISNULL(latest.StatusName, N'(none)')
INTO #EnquiriesToExpire
FROM SSop.Enquiries AS e
OUTER APPLY
(
    SELECT TOP (1)
        StatusGuid = ws.Guid,
        StatusName = ws.Name
    FROM SCore.DataObjectTransition AS dot
    JOIN SCore.WorkflowStatus AS ws
        ON ws.ID = dot.StatusID
    WHERE dot.DataObjectGuid = e.Guid
      AND dot.RowStatus NOT IN (0, 254)
    ORDER BY dot.ID DESC
) AS latest
WHERE e.RowStatus NOT IN (0, 254)
  AND e.ID IN (SELECT sq.EnquiryID FROM #ShoreQuotes AS sq WHERE sq.HasJob = 0)
  AND ISNULL(latest.StatusName, N'') NOT IN (SELECT cs.Name FROM @ClosedStatuses AS cs)
  AND NOT EXISTS
  (
        -- every active quote on the enquiry must be a Shore quote that ends up Expired
        SELECT 1
        FROM SSop.EnquiryServices AS es
        JOIN SSop.Quotes AS q
            ON q.EnquiryServiceID = es.ID
           AND q.RowStatus NOT IN (0, 254)
        LEFT JOIN #ShoreQuotes AS sq
            ON sq.ID = q.ID
        WHERE es.EnquiryId = e.ID
          AND es.RowStatus NOT IN (0, 254)
          AND NOT
          (
                sq.ID IS NOT NULL
            AND sq.HasJob = 0
            AND (sq.LatestStatusName = N'Expired' OR sq.ID IN (SELECT qe.ID FROM #QuotesToExpire AS qe))
          )
  );

-- Org/BU to fill.
DROP TABLE IF EXISTS #QuoteOrgUnits;

SELECT sq.ID, NewOrgUnitID = ISNULL(sq.JobOrgUnitID, @DefaultOrgUnitID), FromJob = CASE WHEN sq.JobOrgUnitID IS NULL THEN 0 ELSE 1 END
INTO #QuoteOrgUnits
FROM #ShoreQuotes AS sq
WHERE sq.OrganisationalUnitID = -1;

DROP TABLE IF EXISTS #EnquiryOrgUnits;

SELECT e.ID, NewOrgUnitID = MAX(ISNULL(qou.NewOrgUnitID, CASE WHEN sq.OrganisationalUnitID > 0 THEN sq.OrganisationalUnitID ELSE @DefaultOrgUnitID END))
INTO #EnquiryOrgUnits
FROM SSop.Enquiries AS e
JOIN #ShoreQuotes AS sq
    ON sq.EnquiryID = e.ID
LEFT JOIN #QuoteOrgUnits AS qou
    ON qou.ID = sq.ID
WHERE e.RowStatus NOT IN (0, 254)
  AND e.OrganisationalUnitID = -1
GROUP BY e.ID;

DROP TABLE IF EXISTS #JobOrgUnits;

SELECT j.ID
INTO #JobOrgUnits
FROM SJob.Jobs AS j
WHERE j.RowStatus NOT IN (0, 254)
  AND j.LegacySystemID = @ShoreLegacySystemID
  -- Most migrated Shore jobs have no CreatedOn; every Shore job came through the migration.
  AND (j.CreatedOn < @MigratedBefore OR j.CreatedOn IS NULL)
  AND j.OrganisationalUnitID = -1;

-- Part 3: listed quotes still on Building & Real Estate Admin.
DECLARE @BccFromOrgUnitID INT = (SELECT ou.ID FROM SCore.OrganisationalUnits AS ou WHERE ou.Guid = @BccFromOrgUnitGuid AND ou.RowStatus NOT IN (0, 254));
DECLARE @BccOrgUnitID INT = (SELECT ou.ID FROM SCore.OrganisationalUnits AS ou WHERE ou.Guid = @BccOrgUnitGuid AND ou.RowStatus NOT IN (0, 254));

IF @BccFromOrgUnitID IS NULL OR @BccOrgUnitID IS NULL
BEGIN
    ;THROW 60000, N'Building & Real Estate Admin (F233BB03-...) or Building Control Consultancy (0125329F-...) is missing or inactive.', 1;
END;

DROP TABLE IF EXISTS #BccQuotes;

SELECT
    bq.Number,
    bq.RevisionNumber,
    QuoteID      = q.ID,
    CurrentOrgUnit = ou.Name,
    WillMove     = CASE WHEN q.OrganisationalUnitID = @BccFromOrgUnitID THEN 1 ELSE 0 END
INTO #BccQuotes
FROM @BccQuotes AS bq
LEFT JOIN SSop.Quotes AS q
    ON q.Number = bq.Number
   AND ISNULL(q.RevisionNumber, 0) = bq.RevisionNumber
   AND q.RowStatus NOT IN (0, 254)
LEFT JOIN SCore.OrganisationalUnits AS ou
    ON ou.ID = q.OrganisationalUnitID;

-------------------------------------------------------------------------------
-- Report
-------------------------------------------------------------------------------
SELECT
    Section = N'Summary',
    ShoreQuotes             = (SELECT COUNT(1) FROM #ShoreQuotes),
    ShoreQuotesNeverConverted = (SELECT COUNT(1) FROM #ShoreQuotes WHERE HasJob = 0),
    QuotesToExpire          = (SELECT COUNT(1) FROM #QuotesToExpire),
    EnquiriesToExpire       = (SELECT COUNT(1) FROM #EnquiriesToExpire),
    QuotesOrgUnitFromJob    = (SELECT COUNT(1) FROM #QuoteOrgUnits WHERE FromJob = 1),
    QuotesOrgUnitDefault    = (SELECT COUNT(1) FROM #QuoteOrgUnits WHERE FromJob = 0),
    EnquiriesOrgUnit        = (SELECT COUNT(1) FROM #EnquiryOrgUnits),
    JobsOrgUnitDefault      = (SELECT COUNT(1) FROM #JobOrgUnits),
    DefaultOrgUnit          = (SELECT ou.Name FROM SCore.OrganisationalUnits AS ou WHERE ou.ID = @DefaultOrgUnitID),
    ListedQuotesToBcc       = (SELECT COUNT(1) FROM #BccQuotes WHERE WillMove = 1),
    ListedQuotesNotFound    = (SELECT COUNT(1) FROM #BccQuotes WHERE QuoteID IS NULL),
    DryRun                  = @DryRun;

SELECT Section = N'Listed quotes to Building Control Consultancy', bq.Number, bq.RevisionNumber,
       CurrentOrgUnit = ISNULL(bq.CurrentOrgUnit, N'(quote not found)'), bq.WillMove
FROM #BccQuotes AS bq
ORDER BY bq.Number DESC, bq.RevisionNumber;

SELECT Section = N'Never-converted Shore quotes by current status', sq.LatestStatusName, Quotes = COUNT(1),
       WillExpire = SUM(CASE WHEN sq.IsOpen = 1 THEN 1 ELSE 0 END)
FROM #ShoreQuotes AS sq
WHERE sq.HasJob = 0
GROUP BY sq.LatestStatusName
ORDER BY COUNT(1) DESC;

SELECT Section = N'Enquiries to expire by current status', ee.LatestStatusName, Enquiries = COUNT(1)
FROM #EnquiriesToExpire AS ee
GROUP BY ee.LatestStatusName
ORDER BY COUNT(1) DESC;

SELECT TOP (20) Section = N'Sample quotes to expire', qe.Number, qe.LatestStatusName
FROM #QuotesToExpire AS qe
ORDER BY qe.ID;

IF @DryRun = 1
BEGIN
    PRINT N'Dry run: nothing was changed. Set @DryRun = 0 and @ActingUserID to apply.';
    EXEC sys.sp_set_session_context @key = N'CYB264.Stage', @value = 3;
    RETURN;
END;

-------------------------------------------------------------------------------
-- Apply
-------------------------------------------------------------------------------
DECLARE @PreviousUserID SQL_VARIANT = SESSION_CONTEXT(N'user_id');
DECLARE @PreviousDisableTriggers SQL_VARIANT = SESSION_CONTEXT(N'S_disable_triggers');
DECLARE @PreviousDisableNotificationTriggers SQL_VARIANT = SESSION_CONTEXT(N'S_disable_notification_triggers');

EXEC sys.sp_set_session_context @key = N'user_id', @value = @ActingUserID, @read_only = 0;

DECLARE @Failures TABLE (RecordType NVARCHAR(20) NOT NULL, RecordGuid UNIQUEIDENTIFIER NOT NULL, ErrorMessage NVARCHAR(4000) NOT NULL);
DECLARE @QuotesExpired INT = 0, @EnquiriesExpired INT = 0, @EnquiriesAlreadySynced INT = 0;
DECLARE @RecordGuid UNIQUEIDENTIFIER, @OldStatusGuid UNIQUEIDENTIFIER, @RecordID BIGINT, @TransitionGuid UNIQUEIDENTIFIER;

BEGIN TRY
    -- Part 1: expire, silently (as the CYB-461 backlog was).
    EXEC sys.sp_set_session_context @key = N'S_disable_triggers', @value = 1, @read_only = 0;
    EXEC sys.sp_set_session_context @key = N'S_disable_notification_triggers', @value = 1, @read_only = 0;

    SET @RecordID = 0;
    WHILE 1 = 1
    BEGIN
        SELECT TOP (1) @RecordID = qe.ID, @RecordGuid = qe.Guid, @OldStatusGuid = qe.OldStatusGuid
        FROM #QuotesToExpire AS qe
        WHERE qe.ID > @RecordID
        ORDER BY qe.ID;

        IF @@ROWCOUNT = 0 BREAK;

        BEGIN TRY
            SET @TransitionGuid = NEWID();
            EXEC SCore.DataObjectTransitionUpsert
                @Guid              = @TransitionGuid,
                @OldStatusGuid     = @OldStatusGuid,
                @StatusGuid        = @ExpiredStatusGuid,
                @Comment           = @Comment,
                @CreatedByUserGuid = @ActingUserGuid,
                @SurveyorUserGuid  = NULL,
                @DataObjectGuid    = @RecordGuid,
                @IsImported        = 0;

            SET @QuotesExpired += 1;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() = -1 THROW;
            INSERT INTO @Failures (RecordType, RecordGuid, ErrorMessage) VALUES (N'Quote', @RecordGuid, LEFT(ERROR_MESSAGE(), 4000));
        END CATCH;
    END;

    SET @RecordID = 0;
    WHILE 1 = 1
    BEGIN
        SELECT TOP (1) @RecordID = ee.ID, @RecordGuid = ee.Guid
        FROM #EnquiriesToExpire AS ee
        WHERE ee.ID > @RecordID
        ORDER BY ee.ID;

        IF @@ROWCOUNT = 0 BREAK;

        -- Expiring its quote may already have synced the enquiry; re-read its status.
        SET @OldStatusGuid = NULL;
        SELECT TOP (1) @OldStatusGuid = ws.Guid
        FROM SCore.DataObjectTransition AS dot
        JOIN SCore.WorkflowStatus AS ws
            ON ws.ID = dot.StatusID
        WHERE dot.DataObjectGuid = @RecordGuid
          AND dot.RowStatus NOT IN (0, 254)
        ORDER BY dot.ID DESC;

        IF @OldStatusGuid = @ExpiredStatusGuid
        BEGIN
            SET @EnquiriesAlreadySynced += 1;
            CONTINUE;
        END;

        BEGIN TRY
            SET @TransitionGuid = NEWID();
            SET @OldStatusGuid = ISNULL(@OldStatusGuid, @EmptyGuid);
            EXEC SCore.DataObjectTransitionUpsert
                @Guid              = @TransitionGuid,
                @OldStatusGuid     = @OldStatusGuid,
                @StatusGuid        = @ExpiredStatusGuid,
                @Comment           = @Comment,
                @CreatedByUserGuid = @ActingUserGuid,
                @SurveyorUserGuid  = NULL,
                @DataObjectGuid    = @RecordGuid,
                @IsImported        = 0;

            SET @EnquiriesExpired += 1;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() = -1 THROW;
            INSERT INTO @Failures (RecordType, RecordGuid, ErrorMessage) VALUES (N'Enquiry', @RecordGuid, LEFT(ERROR_MESSAGE(), 4000));
        END CATCH;
    END;

    -- Part 2: default Org/BU. RecordHistory audits it; notifications stay off.
    EXEC sys.sp_set_session_context @key = N'S_disable_triggers', @value = @PreviousDisableTriggers, @read_only = 0;

    DECLARE @QuotesOrgUnitUpdated INT = 0, @EnquiriesOrgUnitUpdated INT = 0, @JobsOrgUnitUpdated INT = 0, @Rows INT;
    DECLARE @QuotesMovedToBcc INT = 0;

    WHILE 1 = 1
    BEGIN
        BEGIN TRANSACTION;
        UPDATE TOP (@BatchSize) q
        SET OrganisationalUnitID = qou.NewOrgUnitID
        FROM SSop.Quotes AS q
        JOIN #QuoteOrgUnits AS qou
            ON qou.ID = q.ID
        WHERE q.OrganisationalUnitID = -1;
        SET @Rows = @@ROWCOUNT;
        COMMIT TRANSACTION;
        SET @QuotesOrgUnitUpdated += @Rows;
        IF @Rows < @BatchSize BREAK;
    END;

    WHILE 1 = 1
    BEGIN
        BEGIN TRANSACTION;
        UPDATE TOP (@BatchSize) e
        SET OrganisationalUnitID = eou.NewOrgUnitID
        FROM SSop.Enquiries AS e
        JOIN #EnquiryOrgUnits AS eou
            ON eou.ID = e.ID
        WHERE e.OrganisationalUnitID = -1;
        SET @Rows = @@ROWCOUNT;
        COMMIT TRANSACTION;
        SET @EnquiriesOrgUnitUpdated += @Rows;
        IF @Rows < @BatchSize BREAK;
    END;

    WHILE 1 = 1
    BEGIN
        BEGIN TRANSACTION;
        UPDATE TOP (@BatchSize) j
        SET OrganisationalUnitID = @DefaultOrgUnitID
        FROM SJob.Jobs AS j
        JOIN #JobOrgUnits AS jou
            ON jou.ID = j.ID
        WHERE j.OrganisationalUnitID = -1;
        SET @Rows = @@ROWCOUNT;
        COMMIT TRANSACTION;
        SET @JobsOrgUnitUpdated += @Rows;
        IF @Rows < @BatchSize BREAK;
    END;

    -- Part 3: the listed quotes, only while still on Building & Real Estate Admin.
    BEGIN TRANSACTION;
    UPDATE q
    SET OrganisationalUnitID = @BccOrgUnitID
    FROM SSop.Quotes AS q
    JOIN #BccQuotes AS bq
        ON bq.QuoteID = q.ID
    WHERE bq.WillMove = 1
      AND q.OrganisationalUnitID = @BccFromOrgUnitID;
    SET @QuotesMovedToBcc = @@ROWCOUNT;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    EXEC sys.sp_set_session_context @key = N'S_disable_triggers', @value = @PreviousDisableTriggers, @read_only = 0;
    EXEC sys.sp_set_session_context @key = N'S_disable_notification_triggers', @value = @PreviousDisableNotificationTriggers, @read_only = 0;
    EXEC sys.sp_set_session_context @key = N'user_id', @value = @PreviousUserID, @read_only = 0;
    THROW;
END CATCH;

EXEC sys.sp_set_session_context @key = N'S_disable_triggers', @value = @PreviousDisableTriggers, @read_only = 0;
EXEC sys.sp_set_session_context @key = N'S_disable_notification_triggers', @value = @PreviousDisableNotificationTriggers, @read_only = 0;
EXEC sys.sp_set_session_context @key = N'user_id', @value = @PreviousUserID, @read_only = 0;

SELECT
    Section = N'Applied',
    QuotesExpired           = @QuotesExpired,
    EnquiriesExpired        = @EnquiriesExpired,
    EnquiriesSyncedByQuote  = @EnquiriesAlreadySynced,
    QuotesOrgUnitUpdated    = @QuotesOrgUnitUpdated,
    EnquiriesOrgUnitUpdated = @EnquiriesOrgUnitUpdated,
    JobsOrgUnitUpdated      = @JobsOrgUnitUpdated,
    QuotesMovedToBcc        = @QuotesMovedToBcc,
    Failed                  = (SELECT COUNT(1) FROM @Failures);

SELECT f.RecordType, f.RecordGuid, f.ErrorMessage
FROM @Failures AS f;

EXEC sys.sp_set_session_context @key = N'CYB264.Stage', @value = 3;
GO
-------------------------------------------------------------------------------
-- Section 4: CYB-553 Record Status grid (RECORDSTATUS, F28988DD-755A-473F-A12A-6D9931B1B7D8)
-- The grid INNER JOINed SCore.Identities on CreatedByUserId and SurveyorUserId, so
-- transitions written without a surveyor (CYB-461 auto-expiry, CYB-553 Shore expiry,
-- quote -> enquiry sync) were hidden: the "Expired" pill showed but the Record Status
-- list still ended on "Sent". LEFT JOIN both. Metadata only; no record data changes.
-- Same change as applied to CymBuild_Dev on 2026-10-28; nothing to do if the metadata
-- workbench has already promoted it.
-------------------------------------------------------------------------------
-- Section guard: skip if an earlier section did not finish (SSMS runs later batches after an error).
IF ISNULL(CONVERT(INT, SESSION_CONTEXT(N'CYB264.Stage')), -1) <> 3
BEGIN
    RAISERROR(N'Section skipped: the settings or an earlier section did not complete. Fix that and run the whole script again.', 16, 1);
    RETURN;
END;
DECLARE @Apply BIT = ISNULL(CONVERT(BIT, SESSION_CONTEXT(N'CYB264.Apply')), 0);
DECLARE @GridViewGuid UNIQUEIDENTIFIER = 'F28988DD-755A-473F-A12A-6D9931B1B7D8';
DECLARE @InnerCreatedBy NVARCHAR(200) = N'JOIN SCore.Identities AS CreatedBy ON (CreatedBy.ID = root_hobt.CreatedByUserId)';
DECLARE @InnerSurveyor  NVARCHAR(200) = N'JOIN SCore.Identities AS Surveyor ON (Surveyor.ID = root_hobt.SurveyorUserId)';

IF NOT EXISTS
(
    SELECT 1
    FROM SUserInterface.GridViewDefinitions AS gv
    WHERE gv.Guid = @GridViewGuid
      AND gv.Code = N'RECORDSTATUS'
      AND gv.RowStatus NOT IN (0,254)
)
BEGIN
    RAISERROR(N'RECORDSTATUS grid view (F28988DD-755A-473F-A12A-6D9931B1B7D8) not found or inactive in this database.', 16, 1);
    RETURN;
END;

DECLARE @CreatedByToFix BIT, @SurveyorToFix BIT;
SELECT
    @CreatedByToFix = CASE WHEN CHARINDEX(N'LEFT ' + @InnerCreatedBy, gv.SqlQuery) = 0 AND CHARINDEX(@InnerCreatedBy, gv.SqlQuery) > 0 THEN 1 ELSE 0 END,
    @SurveyorToFix  = CASE WHEN CHARINDEX(N'LEFT ' + @InnerSurveyor,  gv.SqlQuery) = 0 AND CHARINDEX(@InnerSurveyor,  gv.SqlQuery) > 0 THEN 1 ELSE 0 END
FROM SUserInterface.GridViewDefinitions AS gv
WHERE gv.Guid = @GridViewGuid;

SELECT Section = N'4 CYB-553 RECORDSTATUS', CreatedByJoinToFix = @CreatedByToFix, SurveyorJoinToFix = @SurveyorToFix,
       Mode = CASE WHEN @Apply = 1 THEN N'APPLY' ELSE N'PREVIEW' END;

IF @Apply = 1 AND (@CreatedByToFix = 1 OR @SurveyorToFix = 1)
BEGIN
    BEGIN TRANSACTION;

    UPDATE gv
    SET gv.SqlQuery = REPLACE(gv.SqlQuery, @InnerCreatedBy, N'LEFT ' + @InnerCreatedBy)
    FROM SUserInterface.GridViewDefinitions AS gv
    WHERE gv.Guid = @GridViewGuid
      AND CHARINDEX(N'LEFT ' + @InnerCreatedBy, gv.SqlQuery) = 0
      AND CHARINDEX(@InnerCreatedBy, gv.SqlQuery) > 0;

    UPDATE gv
    SET gv.SqlQuery = REPLACE(gv.SqlQuery, @InnerSurveyor, N'LEFT ' + @InnerSurveyor)
    FROM SUserInterface.GridViewDefinitions AS gv
    WHERE gv.Guid = @GridViewGuid
      AND CHARINDEX(N'LEFT ' + @InnerSurveyor, gv.SqlQuery) = 0
      AND CHARINDEX(@InnerSurveyor, gv.SqlQuery) > 0;

    COMMIT TRANSACTION;
    PRINT N'RECORDSTATUS grid: identity joins changed to LEFT JOIN.';
END
ELSE IF @CreatedByToFix = 0 AND @SurveyorToFix = 0
    PRINT N'RECORDSTATUS grid: already LEFT JOIN - nothing to do.';
ELSE
    PRINT N'Preview only - set @Apply = 1 to apply.';

EXEC sys.sp_set_session_context @key = N'CYB264.Stage', @value = 4;
GO
-------------------------------------------------------------------------------
-- 26.4 schema check (read-only): every object from this work must be present
-- with its change. Expected HasChange = 1 on every row.
-------------------------------------------------------------------------------
SET NOCOUNT ON;
SELECT Section = N'26.4 schema check', Ticket, Obj, HasChange
FROM (VALUES
    (N'CYB-555', N'SFin.SageExternalTransaction_Upsert',            CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'SFin.SageExternalTransaction_Upsert')) LIKE N'%V2-ACCOUNT-ZEROS%' THEN 1 ELSE 0 END),
    (N'CYB-555', N'SFin.SageInbound_RecordAllocation',              CASE WHEN OBJECT_ID(N'SFin.SageInbound_RecordAllocation') IS NOT NULL THEN 1 ELSE 0 END),
    (N'CYB-555', N'SFin.SageInboundReceiptAndAllocation_Materialise', CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'SFin.SageInboundReceiptAndAllocation_Materialise')) LIKE N'%CYB-555-PAIR-MODE%' THEN 1 ELSE 0 END),
    (N'CYB-555', N'SFin.SageInbound_ReconcileAllocations',          CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'SFin.SageInbound_ReconcileAllocations')) LIKE N'%RECONCILE-PAIR-MODE%' THEN 1 ELSE 0 END),
    (N'CYB-555', N'SFin.tvf_SageInboundDiagnostics',                CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'SFin.tvf_SageInboundDiagnostics')) LIKE N'%AS settled%' THEN 1 ELSE 0 END),
    (N'CYB-555', N'SFin.SageInboundDiagnostics_GetSummary',         CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'SFin.SageInboundDiagnostics_GetSummary')) LIKE N'%CreditNotesCreatedCount%' THEN 1 ELSE 0 END),
    (N'CYB-555', N'SFin.SageInboundDiagnostics_Get',                CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'SFin.SageInboundDiagnostics_Get')) LIKE N'%CreditNotes%' THEN 1 ELSE 0 END),
    (N'CYB-553', N'SSop.Quotes_DWETL',                              CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'SSop.Quotes_DWETL')) LIKE N'%CYB-553-SHORE-LEGACY-EXCLUSION%' THEN 1 ELSE 0 END),
    (N'CYB-553', N'SSop.Enquiries_DWETL',                           CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'SSop.Enquiries_DWETL')) LIKE N'%CYB-553-SHORE-LEGACY-EXCLUSION%' THEN 1 ELSE 0 END),
    (N'CYB-553', N'RECORDSTATUS grid LEFT JOINs identities',        CASE WHEN EXISTS (SELECT 1 FROM SUserInterface.GridViewDefinitions WHERE Guid = 'F28988DD-755A-473F-A12A-6D9931B1B7D8' AND RowStatus NOT IN (0,254) AND SqlQuery LIKE N'%LEFT JOIN SCore.Identities AS CreatedBy%' AND SqlQuery LIKE N'%LEFT JOIN SCore.Identities AS Surveyor%') THEN 1 ELSE 0 END),
    (N'CYB-588', N'SCore.IntegrationOutboxNotificationRecipients',  CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'SCore.IntegrationOutboxNotificationRecipients')) LIKE N'%CYB-588-BID-REQUESTER%' THEN 1 ELSE 0 END),
    -- Earlier 26.4 scripts (CYB-515 schema, CYB-496 metadata, CYB-585 reference data):
    -- a 0 here means run that script from Upgrade Scripts (each is idempotent).
    (N'CYB-515', N'Enqueue proc @OutcomeCode OUTPUT',               CASE WHEN EXISTS (SELECT 1 FROM sys.parameters WHERE object_id = OBJECT_ID(N'SCore.IntegrationOutbox_EnqueueWorkflowStatusNotification') AND name = N'@OutcomeCode' AND is_output = 1) THEN 1 ELSE 0 END),
    (N'CYB-515', N'tr_DataObjectTransition_EnqueueWorkflowStatusNotification', CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'SCore.tr_DataObjectTransition_EnqueueWorkflowStatusNotification')) LIKE N'%@OutcomeCode = @OutcomeCode OUTPUT%' AND OBJECT_DEFINITION(OBJECT_ID(N'SCore.tr_DataObjectTransition_EnqueueWorkflowStatusNotification')) LIKE N'%WorkflowNotificationQueueErrorLog%' THEN 1 ELSE 0 END),
    (N'CYB-515', N'tr_DataObjectTransition_QueueWorkflowNotifications', CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'SCore.tr_DataObjectTransition_QueueWorkflowNotifications')) LIKE N'%Diagnostics when nothing queued%' THEN 1 ELSE 0 END),
    (N'CYB-496', N'Merge Documents Active property + parameter',   CASE WHEN EXISTS (SELECT 1 FROM SCore.EntityProperties WHERE Guid = '4AFA8E03-6D1F-4AF0-827A-2D3D647D4532' AND RowStatus NOT IN (0,254)) AND EXISTS (SELECT 1 FROM SCore.EntityQueryParameters WHERE Guid = 'F3473DE2-18BF-4EC2-B29A-F5DB06130A49' AND RowStatus NOT IN (0,254)) THEN 1 ELSE 0 END),
    (N'CYB-585', N'SJob.FeeAmendmentStatus Pending/Agreed/Rejected', CASE WHEN (SELECT COUNT(1) FROM SJob.FeeAmendmentStatus WHERE RowStatus NOT IN (0,254) AND Guid IN ('68C95270-1BB9-4E8B-BE4C-38746C4661BB','215F258A-CF79-468F-9EB8-A84481F7F8AF','3D66CEDB-A2FB-48CF-BAA3-69B728F374DA')) = 3 THEN 1 ELSE 0 END),
    (N'CYB-569', N'Duplicate New/Quoting/Declined statuses merged',  CASE WHEN NOT EXISTS (SELECT 1 FROM SCore.WorkflowStatus WHERE RowStatus NOT IN (0,254) AND Guid IN ('9e0a10c7-94a0-4e25-afb1-14240d906c12','b88f95c2-41c9-4cc6-ad9f-d9223c4e852a','b9ba4510-6358-4c0a-bba1-5feb33c54f84')) THEN 1 ELSE 0 END)
) v(Ticket, Obj, HasChange)
ORDER BY Ticket, Obj;
GO
EXEC sys.sp_set_session_context @key = N'CYB264.Stage', @value = NULL;
GO
