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

DECLARE @Apply BIT = 0;   -- 0 = preview (rolled back), 1 = apply

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
