/* =====================================================================================
   Duplicate Products and EntityProperties: merge into one survivor, retire the other
   26.4 data fix, 2026-10-14. Branch chore/SB_26.4-dev-sql-sync

   WHY
     The 26.4 schema source has two unique indexes that cannot be created while
     duplicates exist (they are missing on CymBuild_Dev and Cymbuild_UAT_Test):
       IX_UQ_Products_Code                (SProd.Products.Code)
       IX_UQ_EntityProperties_Hobt_Name   (EntityHoBTID, Name, RowStatus; active rows only)

   WHAT
     For each TRUE duplicate pair below, every reference to the retired copy is moved to
     the survivor, then the retired copy is soft-deleted (RowStatus = 254) using the
     standard pattern (SCore.DeleteDataObject / SCore.EntityPropertiesDelete).
     Rows are matched by Guid, which is the same in every environment, so the same script
     runs on DEV, QA, UAT and LIVE.

     Products  (verified identical apart from ID/Guid on CymBuild_Dev and Cymbuild_UAT_Test)
       BRAC HRB ADVISORY  keep 93D70C9B (ID 3140)  retire D14DC458 (ID 3141)
       FIRE-DFS           keep 7634469A (ID 82)    retire 80256A38 (ID 3179)
       IRE-FTC            keep A44F876D (ID 3208)  retire 97BAEEC3 (ID 3209)
     EntityProperties  (survivor = the copy shipped to LIVE in "UAT to Live_202607072109"; the
                        retired copy came only from "UAT to UAT_TEST_202605061037")
       SCrm.Accounts.DefaultCreditTermsId          keep 0DD414A3 (2817)  retire 1E6F6DE6 (2821)
       SFin.InvoiceRequests.FinanceBillingNotes    keep 054E10CC (2819)  retire 70AC79E4 (2822)
       SFin.InvoiceRequests.JobBillingNotes        keep 8FE7DE6C (2820)  retire 62B5AE7E (2824)

     NOT merged: FIRE-SIT (IDs 76 / 3262). These are two different products that share a code:
       76 creates job type 68 "Fire Engineering UK"; 3262 creates 46 "Fire Modelling", with a
       different RIBA stage. One needs a new Code (business decision) before IX_UQ_Products_Code
       can be created.

   REFERENCES MOVED
     Products:          SSop.QuoteItems, SSop.QuoteTemplateItems, SSop.PriceListProducts,
                        SJob.ProductJobActivities, SCore.MergeDocumentItemGatingProducts
                        (unique on Item+Product+RibaStage: if the survivor already gates the
                        same item and stage, the duplicate gating row is retired instead).
     EntityProperties:  SCore.EntityQueryParameters, SCore.EntityPropertyActions,
                        SCore.MergeDocumentItemIncludes (both columns),
                        SCore.EntityPropertyDependants (unique Parent+Dependant: a clash is
                        retired instead). RecordHistory/SynchronisationErrors keep their
                        historic link (the retired row still exists).

   HOW TO RUN (SSMS or sqlcmd), per environment:
     1. Run as-is: @Apply = 0 PREVIEWS. Everything runs inside a transaction that is rolled
        back, and the counts are printed.
     2. Check the counts, then set @Apply = 1 and run again to COMMIT.
     Re-runnable: pairs that are already retired are skipped.
     Then, on CymBuild_Dev only, create IX_UQ_EntityProperties_Hobt_Name (section at the end,
     it only runs when @Apply = 1 and no duplicates remain) so the next -SyncSource keeps it.
     Metadata note: the QA/UAT metadata migration copies the retired EntityProperties as
     retirements only if retirements are selected (opt-in). Running this script in each
     environment is the simpler route.
   ===================================================================================== */
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @Apply BIT = 1;   -- 0 = preview (rolled back), 1 = commit

DECLARE @Pairs TABLE
(
    Seq        INT IDENTITY PRIMARY KEY,
    Kind       CHAR(1)          NOT NULL,   -- P = SProd.Products, E = SCore.EntityProperties
    Label      NVARCHAR(200)    NOT NULL,
    KeepGuid   UNIQUEIDENTIFIER NOT NULL,
    RetireGuid UNIQUEIDENTIFIER NOT NULL
);

INSERT @Pairs (Kind, Label, KeepGuid, RetireGuid)
VALUES
    ('P', N'Product BRAC HRB ADVISORY', '93D70C9B-EBDC-4BC7-BB33-1220EF978667', 'D14DC458-73B1-4DAF-B6EF-F41DB0E3E232'),
    ('P', N'Product FIRE-DFS',          '7634469A-DF33-402D-B3D7-BF5B851AA19A', '80256A38-4733-4C1E-B966-BDCFFF19ADBE'),
    ('P', N'Product IRE-FTC',           'A44F876D-9608-4DBB-BFB4-454A4EE30AFC', '97BAEEC3-78C1-4221-BC93-1541E306F590'),
    ('E', N'SCrm.Accounts.DefaultCreditTermsId',       '0DD414A3-9D97-4BF3-A204-1F51F1AC7BFE', '1E6F6DE6-D70C-4CC4-B46B-C4FDDB903BBA'),
    ('E', N'SFin.InvoiceRequests.FinanceBillingNotes', '054E10CC-AE5F-4974-9DFC-E3AD796DB33B', '70AC79E4-3904-43FD-89B5-7597D56C1AAA'),
    ('E', N'SFin.InvoiceRequests.JobBillingNotes',     '8FE7DE6C-0347-440C-BBBE-4C35B7902367', '62B5AE7E-48E4-4C66-BF94-ACF7EB238063');

DECLARE @Log TABLE (Seq INT, Label NVARCHAR(200), Step NVARCHAR(200), Rows INT);

PRINT N'Database: ' + DB_NAME() + N'   Mode: ' + CASE WHEN @Apply = 1 THEN N'APPLY (commit)' ELSE N'PREVIEW (rollback)' END;

BEGIN TRANSACTION;

DECLARE @Seq INT = 0, @Kind CHAR(1), @Label NVARCHAR(200), @KeepGuid UNIQUEIDENTIFIER, @RetireGuid UNIQUEIDENTIFIER,
        @KeepId INT, @RetireId INT, @RetireStatus TINYINT, @n INT;

WHILE 1 = 1
BEGIN
    SELECT TOP (1) @Seq = Seq, @Kind = Kind, @Label = Label, @KeepGuid = KeepGuid, @RetireGuid = RetireGuid
    FROM @Pairs WHERE Seq > @Seq ORDER BY Seq;
    IF @@ROWCOUNT = 0 BREAK;

    SELECT @KeepId = NULL, @RetireId = NULL, @RetireStatus = NULL;

    IF @Kind = 'P'
    BEGIN
        SELECT @KeepId = k.ID, @RetireId = r.ID, @RetireStatus = r.RowStatus
        FROM SProd.Products AS k
        JOIN SProd.Products AS r ON r.Guid = @RetireGuid
        WHERE k.Guid = @KeepGuid
          AND k.RowStatus NOT IN (0, 254)
          AND r.Code = k.Code;                                   -- same product code or nothing happens
    END
    ELSE
    BEGIN
        SELECT @KeepId = k.ID, @RetireId = r.ID, @RetireStatus = r.RowStatus
        FROM SCore.EntityProperties AS k
        JOIN SCore.EntityProperties AS r ON r.Guid = @RetireGuid
        WHERE k.Guid = @KeepGuid
          AND k.RowStatus NOT IN (0, 254)
          AND r.EntityHoBTID = k.EntityHoBTID
          AND r.Name = k.Name;                                   -- same table + column or nothing happens
    END;

    IF @KeepId IS NULL
    BEGIN
        INSERT @Log VALUES (@Seq, @Label, N'SKIPPED - pair not found / survivor inactive / not the same record', 0);
        CONTINUE;
    END;
    IF @RetireStatus IN (0, 254)
    BEGIN
        INSERT @Log VALUES (@Seq, @Label, N'already retired - nothing to do', 0);
        CONTINUE;
    END;

    IF @Kind = 'P'
    BEGIN
        UPDATE SSop.QuoteItems          SET ProductId = @KeepId WHERE ProductId = @RetireId; INSERT @Log VALUES (@Seq, @Label, N'QuoteItems repointed', @@ROWCOUNT);
        UPDATE SSop.QuoteTemplateItems  SET ProductId = @KeepId WHERE ProductId = @RetireId; INSERT @Log VALUES (@Seq, @Label, N'QuoteTemplateItems repointed', @@ROWCOUNT);
        UPDATE SSop.PriceListProducts   SET ProductId = @KeepId WHERE ProductId = @RetireId; INSERT @Log VALUES (@Seq, @Label, N'PriceListProducts repointed', @@ROWCOUNT);
        UPDATE SJob.ProductJobActivities SET ProductId = @KeepId WHERE ProductId = @RetireId; INSERT @Log VALUES (@Seq, @Label, N'ProductJobActivities repointed', @@ROWCOUNT);

        -- Gating: unique (MergeDocumentItemId, ProductId, RibaStageId) regardless of RowStatus.
        UPDATE g SET RowStatus = 254
        FROM SCore.MergeDocumentItemGatingProducts AS g
        WHERE g.ProductId = @RetireId
          AND g.RowStatus NOT IN (0, 254)
          AND EXISTS (SELECT 1 FROM SCore.MergeDocumentItemGatingProducts AS s
                      WHERE s.ProductId = @KeepId AND s.MergeDocumentItemId = g.MergeDocumentItemId
                        AND ISNULL(s.RibaStageId, -1) = ISNULL(g.RibaStageId, -1));
        INSERT @Log VALUES (@Seq, @Label, N'Gating rows retired (survivor already gates the item)', @@ROWCOUNT);

        UPDATE g SET ProductId = @KeepId
        FROM SCore.MergeDocumentItemGatingProducts AS g
        WHERE g.ProductId = @RetireId
          AND NOT EXISTS (SELECT 1 FROM SCore.MergeDocumentItemGatingProducts AS s
                          WHERE s.ProductId = @KeepId AND s.MergeDocumentItemId = g.MergeDocumentItemId
                            AND ISNULL(s.RibaStageId, -1) = ISNULL(g.RibaStageId, -1));
        INSERT @Log VALUES (@Seq, @Label, N'Gating rows repointed', @@ROWCOUNT);

        UPDATE SProd.Products SET RowStatus = 254 WHERE ID = @RetireId;
        SET @n = @@ROWCOUNT;
        EXEC SCore.DeleteDataObject @Guid = @RetireGuid;
        INSERT @Log VALUES (@Seq, @Label, N'Product retired (RowStatus 254 + DataObject)', @n);
    END
    ELSE
    BEGIN
        UPDATE SCore.EntityQueryParameters SET MappedEntityPropertyID = @KeepId WHERE MappedEntityPropertyID = @RetireId; INSERT @Log VALUES (@Seq, @Label, N'EntityQueryParameters repointed', @@ROWCOUNT);
        UPDATE SCore.EntityPropertyActions SET EntityPropertyID = @KeepId WHERE EntityPropertyID = @RetireId;            INSERT @Log VALUES (@Seq, @Label, N'EntityPropertyActions repointed', @@ROWCOUNT);
        UPDATE SCore.MergeDocumentItemIncludes SET SourceDocumentEntityPropertyId = @KeepId WHERE SourceDocumentEntityPropertyId = @RetireId; INSERT @Log VALUES (@Seq, @Label, N'MergeDocumentItemIncludes (document) repointed', @@ROWCOUNT);
        UPDATE SCore.MergeDocumentItemIncludes SET SourceSharePointItemEntityPropertyId = @KeepId WHERE SourceSharePointItemEntityPropertyId = @RetireId; INSERT @Log VALUES (@Seq, @Label, N'MergeDocumentItemIncludes (SharePoint) repointed', @@ROWCOUNT);

        -- Dependants: unique (ParentEntityPropertyID, DependantPropertyID).
        UPDATE d SET RowStatus = 254
        FROM SCore.EntityPropertyDependants AS d
        WHERE (d.ParentEntityPropertyID = @RetireId OR d.DependantPropertyID = @RetireId)
          AND d.RowStatus NOT IN (0, 254)
          AND EXISTS (SELECT 1 FROM SCore.EntityPropertyDependants AS s
                      WHERE s.ParentEntityPropertyID = CASE WHEN d.ParentEntityPropertyID = @RetireId THEN @KeepId ELSE d.ParentEntityPropertyID END
                        AND s.DependantPropertyID   = CASE WHEN d.DependantPropertyID   = @RetireId THEN @KeepId ELSE d.DependantPropertyID END);
        INSERT @Log VALUES (@Seq, @Label, N'EntityPropertyDependants retired (clash)', @@ROWCOUNT);

        UPDATE d SET ParentEntityPropertyID = CASE WHEN d.ParentEntityPropertyID = @RetireId THEN @KeepId ELSE d.ParentEntityPropertyID END,
                     DependantPropertyID   = CASE WHEN d.DependantPropertyID   = @RetireId THEN @KeepId ELSE d.DependantPropertyID END
        FROM SCore.EntityPropertyDependants AS d
        WHERE (d.ParentEntityPropertyID = @RetireId OR d.DependantPropertyID = @RetireId)
          AND NOT EXISTS (SELECT 1 FROM SCore.EntityPropertyDependants AS s
                          WHERE s.ParentEntityPropertyID = CASE WHEN d.ParentEntityPropertyID = @RetireId THEN @KeepId ELSE d.ParentEntityPropertyID END
                            AND s.DependantPropertyID   = CASE WHEN d.DependantPropertyID   = @RetireId THEN @KeepId ELSE d.DependantPropertyID END);
        INSERT @Log VALUES (@Seq, @Label, N'EntityPropertyDependants repointed', @@ROWCOUNT);

        EXEC SCore.EntityPropertiesDelete @Guid = @RetireGuid;   -- RowStatus 254 + DataObject
        INSERT @Log VALUES (@Seq, @Label, N'EntityProperty retired (RowStatus 254 + DataObject)',
                            CASE WHEN EXISTS (SELECT 1 FROM SCore.EntityProperties WHERE ID = @RetireId AND RowStatus = 254) THEN 1 ELSE 0 END);
    END;
END;

/* Results */
SELECT Seq, Label, Step, Rows FROM @Log ORDER BY Seq, Step;

SELECT N'Remaining active duplicate product codes' AS [Check], COUNT(*) AS Remaining,
       N'Expect 1 (FIRE-SIT, by design) unless it has been recoded' AS Note
FROM (SELECT Code FROM SProd.Products WHERE RowStatus NOT IN (0, 254) GROUP BY Code HAVING COUNT(*) > 1) AS x
UNION ALL
SELECT N'Remaining active duplicate entity properties', COUNT(*), N'Expect 0'
FROM (SELECT EntityHoBTID, Name FROM SCore.EntityProperties WHERE RowStatus NOT IN (0, 254) GROUP BY EntityHoBTID, Name HAVING COUNT(*) > 1) AS y;

IF @Apply = 1
BEGIN
    COMMIT TRANSACTION;
    PRINT N'COMMITTED.';
END
ELSE
BEGIN
    ROLLBACK TRANSACTION;
    PRINT N'PREVIEW ONLY - rolled back. Set @Apply = 1 to commit.';
END;
GO

/* Optional (CymBuild_Dev): create the 26.4 source index now that the metadata duplicates are gone,
   so the next -SyncSource keeps it. Skipped automatically if any active duplicate remains. */
IF DB_NAME() = N'CymBuild_Dev'
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_UQ_EntityProperties_Hobt_Name' AND object_id = OBJECT_ID(N'SCore.EntityProperties'))
   AND NOT EXISTS (SELECT 1 FROM SCore.EntityProperties WHERE RowStatus NOT IN (0, 254) GROUP BY EntityHoBTID, Name, RowStatus HAVING COUNT(*) > 1)
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_EntityProperties_Hobt_Name]
        ON [SCore].[EntityProperties] ([EntityHoBTID] ASC, [Name] ASC, [RowStatus] ASC)
        INCLUDE ([Guid])
        WHERE ([RowStatus] <> (0) AND [RowStatus] <> (254))
        WITH (PAD_INDEX = OFF, FILLFACTOR = 100, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY];
    PRINT N'IX_UQ_EntityProperties_Hobt_Name created.';
END
ELSE
    PRINT N'IX_UQ_EntityProperties_Hobt_Name: not created (not CymBuild_Dev, already exists, or duplicates remain - e.g. preview mode).';
GO
