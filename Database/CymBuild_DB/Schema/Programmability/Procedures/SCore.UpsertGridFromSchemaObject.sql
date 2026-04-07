SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
/* ============================================================
   Proc: SCore.UpsertGridFromSchemaObject
   Purpose:
     Create/update GridDefinitions + GridViewDefinitions + Columns
     + LanguageLabels + Translations + DataObjects

   Key rules:
     - DataObjects inserts always include EntityTypeId up-front
     - Reuse existing GUIDs where possible (stable)
     - Works with U (table), V (view), IF/TF (table-valued function)

   Notes:
     - @SqlQueryTemplate is stored into GridViewDefinitions.SqlQuery
       (your system expects [[UserId]] placeholder, etc.)
     - If @UseAutoColumns = 1, columns come from sys.columns
       for the supplied object.

    EXAMPLES:
    A) Auto-column mode (quick create from a view / table / TVF):
        BEGIN TRAN;

            DECLARE @Cols SCore.GridColumnSeedList; -- empty when auto

            EXEC SCore.UpsertGridFromSchemaObject
                @SourceSchema = N'SCore',
                @SourceObject = N'IntegrationOutboxNotificationRecipients',
                @SourceObjectType = N'V',            -- view
                @GridDefCode = N'OUTBOXRECIP',
                @PageUri = N'outbox',
                @TabName = N'Outbox',
                @GridLanguageLabelId = NULL,         -- existing label Id / OR NULL To Create
                @GridViewCode = N'ALLOUTBOXRECIP',
                @GridViewTypeId = 7,
                @DetailPageUri = N'',
                @EntityTypeID = -1,
                @DefaultSortColumnName = NULL,
                @IsDefaultSortDescending = 1,
                @SqlQueryTemplate = NULL,            -- proc will default to SELECT * FROM schema.object
                @UseAutoColumns = 1,
                @Columns = @Cols;

        -- ROLLBACK;
        COMMIT;
    B) Explicit-column mode
        BEGIN TRAN;

            DECLARE @Cols SCore.GridColumnSeedList;

            INSERT @Cols (Name, ColumnOrder, IsPrimaryKey, IsHidden, IsFiltered, DisplayFormat, Width, LabelText, LabelTextPlural)
            VALUES
             (N'EntityTypeName',           1, 0, 0, 1, N'',  N'160px', N'Type', N'Types'),
             (N'Number',                   2, 0, 0, 1, N'',  N'100px', N'#.',   N'#.' ),
             (N'LatestWorkflowStatusName', 3, 0, 0, 1, N'',  N'220px', N'Status', N'Statuses'),
             (N'DisciplineName',           4, 0, 0, 1, N'',  N'200px', N'Discipline', N'Disciplines'),
             (N'LatestTransitionUtc',      5, 0, 0, 1, N'',  N'170px', N'Last Updated', N'Last Updated'),

             (N'DisplayRef',               6, 0, 0, 1, N'',  N'180px', N'Reference', N'References'),
             (N'DisplayClientName',        7, 0, 0, 1, N'',  N'220px', N'Client Name', N'Client Names'),
             (N'DisplayAgentName',         8, 0, 0, 1, N'',  N'220px', N'Agent Name', N'Agent Names'),
             (N'DisplayAddress',           9, 0, 0, 1, N'',  N'320px', N'Address', N'Addresses'),

             (N'EnquiryTotalFee',         10, 0, 0, 1, N'C', N'140px', N'Enquiry Total Fee', N'Enquiry Total Fees'),
             (N'QuoteAgreedFee',          11, 0, 0, 1, N'C', N'140px', N'Quote Agreed Fee', N'Quote Agreed Fees'),
             (N'QuoteNet',                12, 0, 0, 1, N'C', N'140px', N'Quote Net', N'Quote Net'),
             (N'QuoteDateAccepted',       13, 0, 0, 1, N'',  N'160px', N'Quote Date Accepted', N'Quote Dates Accepted'),

             (N'JobTotalFee',             14, 0, 0, 1, N'C', N'140px', N'Job Total Fee', N'Job Total Fees'),
             (N'JobTotalInvoiced',        15, 0, 0, 1, N'C', N'140px', N'Job Total Invoiced', N'Job Totals Invoiced'),
             (N'JobOutstanding',          16, 0, 0, 1, N'C', N'140px', N'Job Outstanding', N'Job Outstanding'),

             (N'CanActionForUser',        90, 0, 1, 0, N'',  N'120px', N'Can Action', N'Can Action'),
             (N'DataObjectGuid',          91, 0, 1, 0, N'',  N'120px', N'Record Guid', N'Record Guids');

            EXEC SCore.UpsertGridFromSchemaObject
                @SourceSchema = N'SCore',
                @SourceObject = N'tvf_WF_AuthorisationQueue_Display',
                @SourceObjectType = N'TF',   -- TVF
                @GridDefCode = N'AUTHOREVIEW',
                @PageUri = N'authorisation',
                @TabName = N'Authorisation',
                @GridLanguageLabelId = 3563,
                @GridViewCode = N'ALLAUTHORISE',
                @GridViewTypeId = 7,
                @DetailPageUri = N'',
                @EntityTypeID = -1,
                @DefaultSortColumnName = N'LatestTransitionUtc',
                @IsDefaultSortDescending = 1,
                @SqlQueryTemplate = N'SELECT * FROM [SCore].[tvf_WF_AuthorisationQueue_Display]([[UserId]]) root_hobt',
                @UseAutoColumns = 0,
                @Columns = @Cols;

        -- ROLLBACK;
        COMMIT;
============================================================ */
CREATE PROCEDURE [SCore].[UpsertGridFromSchemaObject]
(
    /* Source object */
    @SourceSchema        SYSNAME,
    @SourceObject        SYSNAME,
    @SourceObjectType    NVARCHAR(10),  -- 'U','V','TF','IF'

    /* Grid definition */
    @GridDefCode         NVARCHAR(30),
    @PageUri             NVARCHAR(250),
    @TabName             NVARCHAR(100),
    @GridLanguageLabelId INT = NULL,    -- can be NULL (auto-create)

    /* Grid view definition */
    @GridViewCode        NVARCHAR(50),
    @GridViewTypeId      INT,
    @DetailPageUri       NVARCHAR(250) = N'',
    @EntityTypeID        INT = -1,
    @DefaultSortColumnName NVARCHAR(250) = NULL,
    @IsDefaultSortDescending BIT = 1,

    /* SQL query stored on GridViewDefinition */
    @SqlQueryTemplate    NVARCHAR(MAX) = NULL,

    /* Columns */
    @UseAutoColumns      BIT = 0,
    @Columns             [SCore].[GridColumnSeedList] READONLY,

    /* Language */
    @Locale              NVARCHAR(20) = N'en_GB',

    /* Behaviour */
    @EnsureRequiredSystemCols BIT = 1,   -- ID/Guid/RowStatus if missing
    @PrefixLabelsWithGridCode BIT = 1    -- LabelName: <GridDefCode>.<ColumnName>
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        /* ------------------------------------------------------------
           0) Resolve EntityType IDs for METADATA tables
        ------------------------------------------------------------ */
        DECLARE
            @Et_GridDefinitions             INT,
            @Et_GridViewDefinitions         INT,
            @Et_GridViewColumnDefs          INT,
            @Et_LanguageLabels              INT,
            @Et_LanguageLabelTranslations   INT,
            @Et_Languages                   INT;

        SELECT @Et_GridDefinitions = et.ID
        FROM SCore.EntityTypes et
        WHERE et.RowStatus NOT IN (0,254) AND et.Name = N'Grid Definitions';

        SELECT @Et_GridViewDefinitions = et.ID
        FROM SCore.EntityTypes et
        WHERE et.RowStatus NOT IN (0,254) AND et.Name = N'Grid View Definitions';

        SELECT @Et_GridViewColumnDefs = et.ID
        FROM SCore.EntityTypes et
        WHERE et.RowStatus NOT IN (0,254) AND et.Name = N'Grid View Column Definitions';

        SELECT @Et_LanguageLabels = et.ID
        FROM SCore.EntityTypes et
        WHERE et.RowStatus NOT IN (0,254) AND et.Name = N'Language Labels';

        SELECT @Et_LanguageLabelTranslations = et.ID
        FROM SCore.EntityTypes et
        WHERE et.RowStatus NOT IN (0,254) AND et.Name = N'Language Label Translations';

        SELECT @Et_Languages = et.ID
        FROM SCore.EntityTypes et
        WHERE et.RowStatus NOT IN (0,254) AND et.Name = N'Languages';

        IF @Et_GridDefinitions IS NULL THROW 50000, 'Seed failed: EntityType not found for "Grid Definitions"', 1;
        IF @Et_GridViewDefinitions IS NULL THROW 50000, 'Seed failed: EntityType not found for "Grid View Definitions"', 1;
        IF @Et_GridViewColumnDefs IS NULL THROW 50000, 'Seed failed: EntityType not found for "Grid View Column Definitions"', 1;
        IF @Et_LanguageLabels IS NULL THROW 50000, 'Seed failed: EntityType not found for "Language Labels"', 1;
        IF @Et_LanguageLabelTranslations IS NULL THROW 50000, 'Seed failed: EntityType not found for "Language Label Translations"', 1;
        IF @Et_Languages IS NULL THROW 50000, 'Seed failed: EntityType not found for "Languages"', 1;

        /* ------------------------------------------------------------
           0.1) Resolve LanguageId (create if missing)
        ------------------------------------------------------------ */
        DECLARE
            @LanguageId INT = NULL,
            @LanguageGuid UNIQUEIDENTIFIER = NULL;

        SELECT @LanguageId = l.ID
        FROM SCore.Languages l
        WHERE l.RowStatus NOT IN (0,254)
          AND l.Locale = @Locale;

        IF @LanguageId IS NULL
        BEGIN
            SET @LanguageGuid = NEWID();

            INSERT INTO SCore.DataObjects (Guid, RowStatus, EntityTypeId)
            VALUES (@LanguageGuid, 1, @Et_Languages);

            IF OBJECT_ID('tempdb..#NewLanguageIds') IS NOT NULL DROP TABLE #NewLanguageIds;
            CREATE TABLE #NewLanguageIds (ID INT NOT NULL);

            DECLARE @sqlLang NVARCHAR(MAX) = N'';
            DECLARE @colsLang NVARCHAR(MAX) = N'';
            DECLARE @valsLang NVARCHAR(MAX) = N'';

            /* RowStatus */
            IF COL_LENGTH('SCore.Languages', 'RowStatus') IS NOT NULL
            BEGIN
                SET @colsLang += CASE WHEN LEN(@colsLang) > 0 THEN N',' ELSE N'' END + N'[RowStatus]';
                SET @valsLang += CASE WHEN LEN(@valsLang) > 0 THEN N',' ELSE N'' END + N'1';
            END

            /* Guid */
            IF COL_LENGTH('SCore.Languages', 'Guid') IS NOT NULL
            BEGIN
                SET @colsLang += CASE WHEN LEN(@colsLang) > 0 THEN N',' ELSE N'' END + N'[Guid]';
                SET @valsLang += CASE WHEN LEN(@valsLang) > 0 THEN N',' ELSE N'' END + N'@LanguageGuid';
            END

            /* Locale (required) */
            IF COL_LENGTH('SCore.Languages', 'Locale') IS NOT NULL
            BEGIN
                SET @colsLang += CASE WHEN LEN(@colsLang) > 0 THEN N',' ELSE N'' END + N'[Locale]';
                SET @valsLang += CASE WHEN LEN(@valsLang) > 0 THEN N',' ELSE N'' END + N'@Locale';
            END
            ELSE
            BEGIN
                THROW 50000, 'Seed failed: SCore.Languages does not contain a Locale column.', 1;
            END

            /* Optional */
            IF COL_LENGTH('SCore.Languages', 'Name') IS NOT NULL
            BEGIN
                SET @colsLang += N',[Name]';
                SET @valsLang += N',@Locale';
            END

            IF COL_LENGTH('SCore.Languages', 'DisplayName') IS NOT NULL
            BEGIN
                SET @colsLang += N',[DisplayName]';
                SET @valsLang += N',@Locale';
            END

            SET @sqlLang = N'
                INSERT INTO SCore.Languages (' + @colsLang + N')
                OUTPUT inserted.ID INTO #NewLanguageIds(ID)
                VALUES (' + @valsLang + N');';

            EXEC sp_executesql
                @sqlLang,
                N'@Locale NVARCHAR(20), @LanguageGuid UNIQUEIDENTIFIER',
                @Locale = @Locale,
                @LanguageGuid = @LanguageGuid;

            SELECT TOP (1) @LanguageId = ID FROM #NewLanguageIds ORDER BY ID DESC;

            IF @LanguageId IS NULL
                THROW 50000, 'Seed failed: Could not create/resolve LanguageId for @Locale.', 1;
        END

        /* ------------------------------------------------------------
           0.2) Resolve source object id and validate
        ------------------------------------------------------------ */
        DECLARE @ObjectId INT = OBJECT_ID(QUOTENAME(@SourceSchema) + N'.' + QUOTENAME(@SourceObject));

        IF @ObjectId IS NULL
            THROW 50000, 'Seed failed: Source object not found (schema/object).', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM sys.objects o
            WHERE o.object_id = @ObjectId
              AND (
                    (@SourceObjectType IN (N'U',N'V') AND o.[type] = @SourceObjectType)
                 OR (@SourceObjectType IN (N'TF',N'IF') AND o.[type] IN (N'TF',N'IF'))
              )
        )
            THROW 50000, 'Seed failed: Source object type does not match supplied @SourceObjectType.', 1;

        /* ------------------------------------------------------------
           0.3) "Repair" step for older bad seeds (NULL EntityTypeId)
        ------------------------------------------------------------ */
        UPDATE d SET d.EntityTypeId = @Et_GridDefinitions
        FROM SCore.DataObjects d
        INNER JOIN SUserInterface.GridDefinitions gd ON gd.Guid = d.Guid
        WHERE d.EntityTypeId IS NULL AND gd.RowStatus NOT IN (0,254);

        UPDATE d SET d.EntityTypeId = @Et_GridViewDefinitions
        FROM SCore.DataObjects d
        INNER JOIN SUserInterface.GridViewDefinitions gvd ON gvd.Guid = d.Guid
        WHERE d.EntityTypeId IS NULL AND gvd.RowStatus NOT IN (0,254);

        UPDATE d SET d.EntityTypeId = @Et_GridViewColumnDefs
        FROM SCore.DataObjects d
        INNER JOIN SUserInterface.GridViewColumnDefinitions gvcd ON gvcd.Guid = d.Guid
        WHERE d.EntityTypeId IS NULL AND gvcd.RowStatus NOT IN (0,254);

        /* ------------------------------------------------------------
           0.4) Resolve effective Grid LanguageLabelId (create if NULL)
        ------------------------------------------------------------ */
        DECLARE
            @ExistingGridLanguageLabelId INT = NULL,
            @EffectiveGridLanguageLabelId INT = NULL,
            @GridLabelGuid UNIQUEIDENTIFIER = NULL,
            @GridLabelName NVARCHAR(250) = NULL,
            @GridLabelTranslationGuid UNIQUEIDENTIFIER = NULL;

        SELECT TOP (1) @ExistingGridLanguageLabelId = gd.LanguageLabelId
        FROM SUserInterface.GridDefinitions gd
        WHERE gd.RowStatus NOT IN (0,254)
          AND gd.Code = @GridDefCode;

        SET @EffectiveGridLanguageLabelId = COALESCE(@GridLanguageLabelId, @ExistingGridLanguageLabelId);

        IF @EffectiveGridLanguageLabelId IS NULL
        BEGIN
            SET @GridLabelGuid = NEWID();
            SET @GridLabelName = @GridDefCode;

            INSERT INTO SCore.DataObjects (Guid, RowStatus, EntityTypeId)
            VALUES (@GridLabelGuid, 1, @Et_LanguageLabels);

            INSERT INTO SCore.LanguageLabels (RowStatus, Guid, Name)
            VALUES (1, @GridLabelGuid, @GridLabelName);

            SET @EffectiveGridLanguageLabelId = SCOPE_IDENTITY();

            IF @EffectiveGridLanguageLabelId IS NULL
                THROW 50000, 'Seed failed: Could not create grid LanguageLabelId.', 1;

            SET @GridLabelTranslationGuid = NEWID();

            INSERT INTO SCore.DataObjects (Guid, RowStatus, EntityTypeId)
            VALUES (@GridLabelTranslationGuid, 1, @Et_LanguageLabelTranslations);

            IF COL_LENGTH('SCore.LanguageLabelTranslations', 'TextPlural') IS NOT NULL
            BEGIN
                INSERT INTO SCore.LanguageLabelTranslations
                    (RowStatus, Guid, [Text], TextPlural, LanguageLabelId, LanguageId, HelpText)
                VALUES
                    (1, @GridLabelTranslationGuid, @TabName, @TabName, @EffectiveGridLanguageLabelId, @LanguageId, N'');
            END
            ELSE
            BEGIN
                INSERT INTO SCore.LanguageLabelTranslations
                    (RowStatus, Guid, [Text], LanguageLabelId, LanguageId, HelpText)
                VALUES
                    (1, @GridLabelTranslationGuid, @TabName, @EffectiveGridLanguageLabelId, @LanguageId, N'');
            END
        END

        /* ------------------------------------------------------------
           1) GRID DEFINITION upsert
        ------------------------------------------------------------ */
        DECLARE @GridDefGuid UNIQUEIDENTIFIER = NULL;

        SELECT TOP(1) @GridDefGuid = gd.Guid
        FROM SUserInterface.GridDefinitions gd
        WHERE gd.RowStatus NOT IN (0,254)
          AND gd.Code = @GridDefCode;

        IF @GridDefGuid IS NULL
            SET @GridDefGuid = NEWID();

        IF NOT EXISTS (SELECT 1 FROM SCore.DataObjects d WHERE d.Guid = @GridDefGuid)
        BEGIN
            INSERT INTO SCore.DataObjects (Guid, RowStatus, EntityTypeId)
            VALUES (@GridDefGuid, 1, @Et_GridDefinitions);
        END
        ELSE
        BEGIN
            UPDATE SCore.DataObjects
               SET EntityTypeId = COALESCE(EntityTypeId, @Et_GridDefinitions)
             WHERE Guid = @GridDefGuid;
        END

        IF EXISTS (SELECT 1 FROM SUserInterface.GridDefinitions gd WHERE gd.Code = @GridDefCode AND gd.RowStatus NOT IN (0,254))
        BEGIN
            UPDATE gd
               SET gd.PageUri = @PageUri,
                   gd.TabName = @TabName,
                   gd.ShowAsTiles = 0,
                   gd.LanguageLabelId = @EffectiveGridLanguageLabelId,
                   gd.RowStatus = 1
            FROM SUserInterface.GridDefinitions gd
            WHERE gd.Code = @GridDefCode
              AND gd.RowStatus NOT IN (0,254);
        END
        ELSE
        BEGIN
            INSERT INTO SUserInterface.GridDefinitions
                (RowStatus, Guid, Code, PageUri, TabName, ShowAsTiles, LanguageLabelId)
            VALUES
                (1, @GridDefGuid, @GridDefCode, @PageUri, @TabName, 0, @EffectiveGridLanguageLabelId);
        END

        DECLARE @GridDefinitionId INT;
        SELECT @GridDefinitionId = gd.ID
        FROM SUserInterface.GridDefinitions gd
        WHERE gd.Code = @GridDefCode AND gd.RowStatus NOT IN (0,254);

        IF @GridDefinitionId IS NULL
            THROW 50000, 'Seed failed: Could not resolve GridDefinitionId after upsert.', 1;

        /* ------------------------------------------------------------
           2) GRID VIEW DEFINITION upsert
        ------------------------------------------------------------ */

        /* 2.A DefaultSortColumnName cannot be NULL */
        DECLARE
            @ExistingDefaultSortColumnName NVARCHAR(250) = NULL,
            @DerivedDefaultSortColumnName  NVARCHAR(250) = NULL,
            @EffectiveDefaultSortColumnName NVARCHAR(250) = NULL;

        SELECT TOP (1) @ExistingDefaultSortColumnName = gvd.DefaultSortColumnName
        FROM SUserInterface.GridViewDefinitions gvd
        WHERE gvd.RowStatus NOT IN (0,254)
          AND gvd.Code = @GridViewCode;

        SELECT @DerivedDefaultSortColumnName =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns c WHERE c.object_id = @ObjectId AND c.name = N'ID') THEN N'ID'
                WHEN EXISTS (SELECT 1 FROM sys.columns c WHERE c.object_id = @ObjectId AND c.name = N'Guid') THEN N'Guid'
                ELSE (SELECT TOP (1) c.name FROM sys.columns c WHERE c.object_id = @ObjectId ORDER BY c.column_id)
            END;

        SET @EffectiveDefaultSortColumnName =
            COALESCE(@DefaultSortColumnName, @ExistingDefaultSortColumnName, @DerivedDefaultSortColumnName, N'ID');

        DECLARE @GridViewGuid UNIQUEIDENTIFIER = NULL;

        SELECT TOP(1) @GridViewGuid = gvd.Guid
        FROM SUserInterface.GridViewDefinitions gvd
        WHERE gvd.RowStatus NOT IN (0,254)
          AND gvd.Code = @GridViewCode;

        IF @GridViewGuid IS NULL
            SET @GridViewGuid = NEWID();

        IF @SqlQueryTemplate IS NULL
        BEGIN
            IF @SourceObjectType IN (N'TF', N'IF')
                SET @SqlQueryTemplate =
                    N'SELECT * FROM ' + QUOTENAME(@SourceSchema) + N'.' + QUOTENAME(@SourceObject) + N'([[UserId]]) root_hobt';
            ELSE
                SET @SqlQueryTemplate =
                    N'SELECT * FROM ' + QUOTENAME(@SourceSchema) + N'.' + QUOTENAME(@SourceObject) + N' root_hobt';
        END

        IF NOT EXISTS (SELECT 1 FROM SCore.DataObjects d WHERE d.Guid = @GridViewGuid)
        BEGIN
            INSERT INTO SCore.DataObjects (Guid, RowStatus, EntityTypeId)
            VALUES (@GridViewGuid, 1, @Et_GridViewDefinitions);
        END
        ELSE
        BEGIN
            UPDATE SCore.DataObjects
               SET EntityTypeId = COALESCE(EntityTypeId, @Et_GridViewDefinitions)
             WHERE Guid = @GridViewGuid;
        END

        IF EXISTS (SELECT 1 FROM SUserInterface.GridViewDefinitions gvd WHERE gvd.Code = @GridViewCode AND gvd.RowStatus NOT IN (0,254))
        BEGIN
            UPDATE gvd
               SET gvd.GridDefinitionId = @GridDefinitionId,
                   gvd.SqlQuery = @SqlQueryTemplate,
                   gvd.DefaultSortColumnName = @EffectiveDefaultSortColumnName,
                   gvd.IsDefaultSortDescending = @IsDefaultSortDescending,
                   gvd.GridViewTypeId = @GridViewTypeId,
                   gvd.DetailPageUri = @DetailPageUri,
                   gvd.EntityTypeID = @EntityTypeID,
                   gvd.RowStatus = 1
            FROM SUserInterface.GridViewDefinitions gvd
            WHERE gvd.Code = @GridViewCode
              AND gvd.RowStatus NOT IN (0,254);
        END
        ELSE
        BEGIN
            INSERT INTO SUserInterface.GridViewDefinitions
            (
                RowStatus, Guid, Code, GridDefinitionId, DetailPageUri, SqlQuery, DefaultSortColumnName,
                SecurableCode, DisplayOrder, DisplayGroupName, MetricSqlQuery, ShowMetric, IsDetailWindowed,
                EntityTypeID, MetricTypeID, MetricMin, MetricMax, MetricMinorUnit, MetricMajorUnit,
                MetricStartAngle, MetricEndAngle, MetricReversed, MetricRange1Min, MetricRange1Max,
                MetricRange1ColourHex, MetricRange2Min, MetricRange2Max, MetricRange2ColourHex,
                IsDefaultSortDescending, AllowNew, AllowExcelExport, AllowPdfExport, AllowCsvExport,
                LanguageLabelId, DrawerIconId, GridViewTypeId, AllowBulkChange, ShowOnMobile,
                TreeListFirstOrderBy, TreeListSecondOrderBy, TreeListThirdOrderBy, TreeListOrderBy,
                TreeListGroupBy, ShowOnDashboard, FilteredListCreatedOnColumn,
                FilteredListRedStatusIndicatorTxt, FilteredListOrangeStatusIndicatorTxt,
                FilteredListGreenStatusIndicatorTxt, FilteredListGroupBy
            )
            VALUES
            (
                1, @GridViewGuid, @GridViewCode, @GridDefinitionId, @DetailPageUri, @SqlQueryTemplate, @EffectiveDefaultSortColumnName,
                N'', 0, N'', N'', 0, 0,
                @EntityTypeID, -1, 0,0,0,0,
                0,0,0, 0,0,N'',
                0,0,N'',
                @IsDefaultSortDescending, 0,0,0,0,
                @EffectiveGridLanguageLabelId, -1, @GridViewTypeId, 0, 0,
                N'',N'',N'',N'',N'', 0,
                N'',N'',N'',N'',N''
            );
        END

        DECLARE @GridViewDefinitionId INT;
        SELECT @GridViewDefinitionId = gvd.ID
        FROM SUserInterface.GridViewDefinitions gvd
        WHERE gvd.Code = @GridViewCode AND gvd.RowStatus NOT IN (0,254);

        IF @GridViewDefinitionId IS NULL
            THROW 50000, 'Seed failed: Could not resolve GridViewDefinitionId after upsert.', 1;

        /* ------------------------------------------------------------
           3) Build Desired column list (either TVP or auto from sys.columns)
        ------------------------------------------------------------ */
        DECLARE @Desired TABLE
        (
            Name NVARCHAR(250) NOT NULL PRIMARY KEY,
            ColumnOrder INT NOT NULL,
            IsPrimaryKey BIT NOT NULL,
            IsHidden BIT NOT NULL,
            IsFiltered BIT NOT NULL,
            DisplayFormat NVARCHAR(250) NOT NULL,
            Width NVARCHAR(50) NOT NULL,
            LabelText NVARCHAR(250) NULL,
            LabelTextPlural NVARCHAR(250) NULL
        );

        IF @UseAutoColumns = 1
        BEGIN
            INSERT INTO @Desired (Name, ColumnOrder, IsPrimaryKey, IsHidden, IsFiltered, DisplayFormat, Width, LabelText, LabelTextPlural)
            SELECT
                c.name,
                c.column_id,
                CASE WHEN c.name = N'ID' THEN 1 ELSE 0 END,
                CASE WHEN c.name IN (N'ID',N'Guid',N'RowStatus',N'RowVersion') THEN 1 ELSE 0 END,
                CASE WHEN c.name IN (N'ID',N'Guid',N'RowStatus',N'RowVersion') THEN 0 ELSE 1 END,
                N'',
                N'140px',
                NULL,
                NULL
            FROM sys.columns c
            WHERE c.object_id = @ObjectId
            ORDER BY c.column_id;
        END
        ELSE
        BEGIN
            INSERT INTO @Desired (Name, ColumnOrder, IsPrimaryKey, IsHidden, IsFiltered, DisplayFormat, Width, LabelText, LabelTextPlural)
            SELECT Name, ColumnOrder, IsPrimaryKey, IsHidden, IsFiltered, DisplayFormat, Width, LabelText, LabelTextPlural
            FROM @Columns;
        END

        IF @EnsureRequiredSystemCols = 1
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM @Desired WHERE Name = N'ID')
                INSERT INTO @Desired VALUES (N'ID', 992, 1, 1, 0, N'', N'120px', N'ID', N'IDs');

            IF NOT EXISTS (SELECT 1 FROM @Desired WHERE Name = N'Guid')
                INSERT INTO @Desired VALUES (N'Guid', 993, 0, 1, 0, N'', N'120px', N'Guid', N'Guids');

            IF NOT EXISTS (SELECT 1 FROM @Desired WHERE Name = N'RowStatus')
                INSERT INTO @Desired VALUES (N'RowStatus', 994, 0, 1, 0, N'', N'120px', N'Row Status', N'Row Statuses');
        END

        /* ------------------------------------------------------------
           3.A Resolve stable Column GUIDs (reuse existing else new)
        ------------------------------------------------------------ */
        DECLARE @ColumnKeys TABLE
        (
            Name NVARCHAR(250) NOT NULL PRIMARY KEY,
            ColumnGuid UNIQUEIDENTIFIER NOT NULL
        );

        INSERT INTO @ColumnKeys (Name, ColumnGuid)
        SELECT
            d.Name,
            COALESCE(existing.Guid, NEWID())
        FROM @Desired d
        OUTER APPLY
        (
            SELECT TOP (1) c.Guid
            FROM SUserInterface.GridViewColumnDefinitions c
            WHERE c.GridViewDefinitionId = @GridViewDefinitionId
              AND c.Name = d.Name
              AND c.RowStatus NOT IN (0,254)
            ORDER BY c.ID DESC
        ) existing;

        UPDATE ck
           SET ck.ColumnGuid = NEWID()
        FROM @ColumnKeys ck
        WHERE EXISTS (SELECT 1 FROM SUserInterface.GridViewColumnDefinitions x WHERE x.Guid = ck.ColumnGuid)
          AND NOT EXISTS
          (
              SELECT 1
              FROM SUserInterface.GridViewColumnDefinitions x
              WHERE x.Guid = ck.ColumnGuid
                AND x.GridViewDefinitionId = @GridViewDefinitionId
                AND x.Name = ck.Name
          );

        /* ------------------------------------------------------------
           3.B Ensure DataObjects exist for ALL Column GUIDs
        ------------------------------------------------------------ */
        INSERT INTO SCore.DataObjects (Guid, RowStatus, EntityTypeId)
        SELECT ck.ColumnGuid, 1, @Et_GridViewColumnDefs
        FROM @ColumnKeys ck
        LEFT JOIN SCore.DataObjects do1 ON do1.Guid = ck.ColumnGuid
        WHERE do1.Guid IS NULL;

        UPDATE do1
           SET do1.EntityTypeId = COALESCE(do1.EntityTypeId, @Et_GridViewColumnDefs)
        FROM SCore.DataObjects do1
        JOIN @ColumnKeys ck ON ck.ColumnGuid = do1.Guid
        WHERE do1.EntityTypeId IS NULL;

        /* ------------------------------------------------------------
           3.C Create LanguageLabels + Translations for each column
        ------------------------------------------------------------ */
        DECLARE @ColLabels TABLE
        (
            ColumnName NVARCHAR(250) NOT NULL PRIMARY KEY,
            LabelName  NVARCHAR(250) NOT NULL,
            LabelGuid  UNIQUEIDENTIFIER NOT NULL,
            LabelId    INT NULL
        );

        INSERT INTO @ColLabels (ColumnName, LabelName, LabelGuid)
        SELECT
            d.Name,
            CASE WHEN @PrefixLabelsWithGridCode = 1
                 THEN CONCAT(@GridDefCode, N'.', d.Name)
                 ELSE d.Name
            END,
            COALESCE(ll.Guid, NEWID())
        FROM @Desired d
        OUTER APPLY
        (
            SELECT TOP(1) ll.Guid
            FROM SCore.LanguageLabels ll
            WHERE ll.RowStatus NOT IN (0,254)
              AND ll.Name =
                    CASE WHEN @PrefixLabelsWithGridCode = 1
                         THEN CONCAT(@GridDefCode, N'.', d.Name)
                         ELSE d.Name
                    END
        ) ll;

        INSERT INTO SCore.DataObjects (Guid, RowStatus, EntityTypeId)
        SELECT cl.LabelGuid, 1, @Et_LanguageLabels
        FROM @ColLabels cl
        LEFT JOIN SCore.DataObjects d ON d.Guid = cl.LabelGuid
        WHERE d.Guid IS NULL;

        MERGE SCore.LanguageLabels AS tgt
        USING (SELECT LabelGuid, LabelName FROM @ColLabels) AS src
           ON tgt.Guid = src.LabelGuid
        WHEN MATCHED THEN
            UPDATE SET tgt.Name = src.LabelName, tgt.RowStatus = 1
        WHEN NOT MATCHED THEN
            INSERT (Guid, Name, RowStatus)
            VALUES (src.LabelGuid, src.LabelName, 1);

        UPDATE cl
           SET cl.LabelId = ll.ID
        FROM @ColLabels cl
        JOIN SCore.LanguageLabels ll
          ON ll.Guid = cl.LabelGuid
         AND ll.RowStatus NOT IN (0,254);

        IF EXISTS (SELECT 1 FROM @ColLabels WHERE LabelId IS NULL)
            THROW 50000, 'Seed failed: Could not resolve LabelId for one or more column LanguageLabels.', 1;

        DECLARE @Trans TABLE
        (
            ColumnName NVARCHAR(250) NOT NULL PRIMARY KEY,
            TransGuid UNIQUEIDENTIFIER NOT NULL,
            LabelId INT NOT NULL,
            [Text] NVARCHAR(250) NOT NULL,
            TextPlural NVARCHAR(250) NOT NULL
        );

        INSERT INTO @Trans (ColumnName, TransGuid, LabelId, [Text], TextPlural)
        SELECT
            d.Name,
            COALESCE(existing.Guid, NEWID()),
            cl.LabelId,
            COALESCE(NULLIF(d.LabelText, N''), SCore.SplitOnUpperCase(d.Name)),
            COALESCE(
                NULLIF(d.LabelTextPlural, N''),
                CASE
                    WHEN d.Name = N'ID' THEN N'IDs'
                    WHEN d.Name = N'Guid' THEN N'Guids'
                    WHEN d.Name = N'RowStatus' THEN N'Row Statuses'
                    ELSE CONCAT(SCore.SplitOnUpperCase(d.Name), N's')
                END
            )
        FROM @Desired d
        JOIN @ColLabels cl ON cl.ColumnName = d.Name
        OUTER APPLY
        (
            SELECT TOP(1) t.Guid
            FROM SCore.LanguageLabelTranslations t
            WHERE t.RowStatus NOT IN (0,254)
              AND t.LanguageLabelId = cl.LabelId
              AND t.LanguageId = @LanguageId
            ORDER BY t.ID DESC
        ) existing;

        INSERT INTO SCore.DataObjects (Guid, RowStatus, EntityTypeId)
        SELECT t.TransGuid, 1, @Et_LanguageLabelTranslations
        FROM @Trans t
        LEFT JOIN SCore.DataObjects d ON d.Guid = t.TransGuid
        WHERE d.Guid IS NULL;

        MERGE SCore.LanguageLabelTranslations AS tgt
        USING (SELECT TransGuid, LabelId, [Text], TextPlural FROM @Trans) AS src
           ON tgt.Guid = src.TransGuid
        WHEN MATCHED THEN
            UPDATE SET
                tgt.RowStatus = 1,
                tgt.[Text] = src.[Text],
                tgt.TextPlural = src.TextPlural,
                tgt.LanguageLabelId = src.LabelId,
                tgt.LanguageId = @LanguageId,
                tgt.HelpText = N''
        WHEN NOT MATCHED THEN
            INSERT (RowStatus, Guid, [Text], TextPlural, LanguageLabelId, LanguageId, HelpText)
            VALUES (1, src.TransGuid, src.[Text], src.TextPlural, src.LabelId, @LanguageId, N'');

        /* ------------------------------------------------------------
           3.D MERGE GridViewColumnDefinitions
        ------------------------------------------------------------ */
        MERGE SUserInterface.GridViewColumnDefinitions AS tgt
        USING
        (
            SELECT
                d.Name,
                d.ColumnOrder,
                d.IsPrimaryKey,
                d.IsHidden,
                d.IsFiltered,
                d.DisplayFormat,
                d.Width,
                ck.ColumnGuid,
                cl.LabelId AS LanguageLabelId
            FROM @Desired d
            JOIN @ColumnKeys ck ON ck.Name = d.Name
            JOIN @ColLabels cl ON cl.ColumnName = d.Name
        ) AS src
           ON tgt.GridViewDefinitionId = @GridViewDefinitionId
          AND tgt.Name = src.Name
          AND tgt.RowStatus NOT IN (0,254)
        WHEN MATCHED THEN
            UPDATE SET
                tgt.ColumnOrder     = src.ColumnOrder,
                tgt.IsPrimaryKey    = src.IsPrimaryKey,
                tgt.IsHidden        = src.IsHidden,
                tgt.IsFiltered      = src.IsFiltered,
                tgt.DisplayFormat   = src.DisplayFormat,
                tgt.Width           = src.Width,
                tgt.LanguageLabelId = src.LanguageLabelId,
                tgt.RowStatus       = 1
        WHEN NOT MATCHED THEN
            INSERT
            (
                RowStatus, Guid, Name, ColumnOrder, GridViewDefinitionId,
                IsPrimaryKey, IsHidden, IsFiltered,
                IsCombo, IsLongitude, IsLatitude,
                DisplayFormat, Width, LanguageLabelId,
                TopHeaderCategory, TopHeaderCategoryOrder
            )
            VALUES
            (
                1,
                CASE
                    WHEN EXISTS (SELECT 1 FROM SUserInterface.GridViewColumnDefinitions x WHERE x.Guid = src.ColumnGuid)
                    THEN NEWID()
                    ELSE src.ColumnGuid
                END,
                src.Name,
                src.ColumnOrder,
                @GridViewDefinitionId,
                src.IsPrimaryKey,
                src.IsHidden,
                src.IsFiltered,
                0,0,0,
                src.DisplayFormat,
                src.Width,
                src.LanguageLabelId,
                N'',
                0
            );

        /* ------------------------------------------------------------
           4) Output
        ------------------------------------------------------------ */
        SELECT 'GridDefinition' AS Item, gd.ID, gd.Guid, gd.Code, gd.PageUri, gd.TabName, gd.LanguageLabelId
        FROM SUserInterface.GridDefinitions gd
        WHERE gd.Code = @GridDefCode
          AND gd.RowStatus NOT IN (0,254);

        SELECT 'GridViewDefinition' AS Item, gvd.ID, gvd.Guid, gvd.Code, gvd.GridDefinitionId, gvd.GridViewTypeId, gvd.DefaultSortColumnName
        FROM SUserInterface.GridViewDefinitions gvd
        WHERE gvd.Code = @GridViewCode
          AND gvd.RowStatus NOT IN (0,254);

        SELECT 'GridViewColumns' AS Item, c.ID, c.Guid, c.Name, c.ColumnOrder, c.IsHidden, c.IsFiltered, c.LanguageLabelId, c.Width
        FROM SUserInterface.GridViewColumnDefinitions c
        WHERE c.GridViewDefinitionId = @GridViewDefinitionId
          AND c.RowStatus NOT IN (0,254)
        ORDER BY c.ColumnOrder;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 50000, @Err, 1;
    END CATCH
END
GO