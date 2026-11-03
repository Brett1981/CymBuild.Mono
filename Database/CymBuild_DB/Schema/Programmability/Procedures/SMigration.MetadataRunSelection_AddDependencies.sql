SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataRunSelection_AddDependencies]')
GO

/*
    CYB-564: when rows are selected for apply, also select the rows they need or that belong
    to them, so a selection cannot leave a new child without its new parent (seen live: HoBT
    SJob.FeeAmendmentChase selected without its new EntityType 'Fee Amendment Chase', which
    failed Apply with a raw NOT NULL error on EntityHobts.EntityTypeID).

    @SeedJson is the rows the user just selected:
    [{"SchemaName":"SCore","TableName":"EntityHobts","SourceRowGuid":"..."}].
    Relationships are the declared single-column foreign keys between registered tables (the
    same set MetadataStage_NormaliseDifferences, MetadataValidate_Run and MetadataApply_Run use),
    matched through each staged row's SourceRowId.

      1. Down: staged Insert/Update rows that reference a seed row, then rows that reference
         those, and so on. Only Insert/Update rows are followed.
      2. Up: for every seed row and every row from step 1, new (Insert) parents, recursively.
         An Update/NoChange parent already exists in the target, and a parent with an Identity
         Map override resolves to its mapped target row, so neither is needed.
         Parents added in step 2 do not pull in their own children; otherwise selecting one HoBT
         would select every other HoBT and property of its EntityType.

    Ignored rows are never selected. Added rows are recorded with SelectionSource
    N'Dependency'. Unselecting a row does not cascade; MetadataValidate_Run and
    MetadataApply_Run block a selection that is left without a required parent.
*/
CREATE OR ALTER PROCEDURE [SMigration].[MetadataRunSelection_AddDependencies]
(
    @RunGuid UNIQUEIDENTIFIER,
    @SeedJson NVARCHAR(MAX)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @TargetDatabaseName SYSNAME,
        @AddedCount INT = 0,
        @SelectionGuid UNIQUEIDENTIFIER,
        @RegistryGuid UNIQUEIDENTIFIER,
        @SourceRowGuid UNIQUEIDENTIFIER,
        @DifferenceType NVARCHAR(30);

    SELECT
        @TargetDatabaseName = run.TargetDatabaseName
    FROM SMigration.Metadata_Run AS run
    WHERE run.Guid = @RunGuid
      AND run.RowStatus NOT IN (0,254);

    IF @TargetDatabaseName IS NULL
        THROW 52103, 'Metadata run was not found or is inactive.', 1;

    CREATE TABLE #Rows
    (
        StagedRowId BIGINT NOT NULL PRIMARY KEY,
        RegistryGuid UNIQUEIDENTIFIER NOT NULL,
        SourceRowGuid UNIQUEIDENTIFIER NOT NULL,
        SourceRowId BIGINT NULL,
        DifferenceType NVARCHAR(30) NOT NULL,
        IsSelectable BIT NOT NULL,
        HasOverride BIT NOT NULL
    );

    INSERT INTO #Rows
    (
        StagedRowId,
        RegistryGuid,
        SourceRowGuid,
        SourceRowId,
        DifferenceType,
        IsSelectable,
        HasOverride
    )
    SELECT
        sr.ID,
        sr.RegistryGuid,
        sr.SourceRowGuid,
        sr.SourceRowId,
        sr.DifferenceType,
        CASE
            WHEN sr.DifferenceType IN (N'Insert', N'Update')
                 AND NOT EXISTS
                 (
                     SELECT 1
                     FROM SMigration.Metadata_IgnoredRecords AS ignored
                     WHERE ignored.DatabaseName = @TargetDatabaseName
                       AND ignored.RegistryGuid = sr.RegistryGuid
                       AND ignored.SourceRowGuid = sr.SourceRowGuid
                       AND ignored.RowStatus NOT IN (0,254)
                 ) THEN 1
            ELSE 0
        END,
        CASE
            WHEN EXISTS
            (
                SELECT 1
                FROM SMigration.Metadata_IdentityMapOverrides AS identityOverride
                WHERE identityOverride.DatabaseName = @TargetDatabaseName
                  AND identityOverride.RegistryGuid = sr.RegistryGuid
                  AND identityOverride.SourceRowGuid = sr.SourceRowGuid
                  AND identityOverride.RowStatus NOT IN (0,254)
            ) THEN 1
            ELSE 0
        END
    FROM SMigration.Metadata_StagedRows AS sr
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.SourceRowGuid IS NOT NULL;

    CREATE INDEX IX_Rows_Registry_SourceRowId ON #Rows (RegistryGuid, SourceRowId);

    -- Each step below is materialised on purpose. Joining staged rows to their parents directly
    -- on a JSON_VALUE of the child payload let the optimiser re-parse payloads for every
    -- candidate pair, and a ~14,000-row run did not finish within the 300 second timeout.
    CREATE TABLE #ForeignKeys
    (
        ChildRegistryGuid UNIQUEIDENTIFIER NOT NULL,
        ColumnName SYSNAME NOT NULL,
        RefRegistryGuid UNIQUEIDENTIFIER NOT NULL,
        PRIMARY KEY CLUSTERED (ChildRegistryGuid, ColumnName)
    );

    ;WITH RegisteredForeignKeys AS
    (
        SELECT
            childTr.Guid AS ChildRegistryGuid,
            pc.name AS ColumnName,
            refTr.Guid AS RefRegistryGuid
        FROM SMigration.Metadata_TableRegistry AS childTr
        INNER JOIN sys.foreign_key_columns AS fkc
            ON fkc.parent_object_id = OBJECT_ID(QUOTENAME(childTr.SchemaName) + N'.' + QUOTENAME(childTr.TableName))
        INNER JOIN sys.columns AS pc
            ON pc.object_id = fkc.parent_object_id
           AND pc.column_id = fkc.parent_column_id
        INNER JOIN sys.tables AS rt
            ON rt.object_id = fkc.referenced_object_id
        INNER JOIN sys.schemas AS rs
            ON rs.schema_id = rt.schema_id
        INNER JOIN sys.columns AS rc
            ON rc.object_id = fkc.referenced_object_id
           AND rc.column_id = fkc.referenced_column_id
        INNER JOIN SMigration.Metadata_TableRegistry AS refTr
            ON refTr.SchemaName = rs.name
           AND refTr.TableName = rt.name
           AND refTr.RowStatus NOT IN (0,254)
           AND refTr.IsEnabled = 1
        WHERE childTr.RowStatus NOT IN (0,254)
          AND childTr.IsEnabled = 1
          AND pc.name <> N'RowStatus'
          AND rc.name = refTr.PrimaryKeyColumnName
          AND NOT EXISTS
          (
              SELECT 1
              FROM sys.foreign_key_columns AS otherColumn
              WHERE otherColumn.constraint_object_id = fkc.constraint_object_id
                AND otherColumn.constraint_column_id <> fkc.constraint_column_id
          )
    )
    INSERT INTO #ForeignKeys
    (
        ChildRegistryGuid,
        ColumnName,
        RefRegistryGuid
    )
    SELECT DISTINCT
        fk.ChildRegistryGuid,
        fk.ColumnName,
        fk.RefRegistryGuid
    FROM RegisteredForeignKeys AS fk;

    -- One JSON_VALUE per (staged row, foreign key column). JSON_VALUE returns at most 4000
    -- characters (NULL beyond that in lax mode), so the BIGINT conversion cannot raise 8152.
    CREATE TABLE #ChildReferences
    (
        ChildStagedRowId BIGINT NOT NULL,
        RefRegistryGuid UNIQUEIDENTIFIER NOT NULL,
        ParentSourceRowId BIGINT NOT NULL
    );

    INSERT INTO #ChildReferences
    (
        ChildStagedRowId,
        RefRegistryGuid,
        ParentSourceRowId
    )
    SELECT
        refs.ChildStagedRowId,
        refs.RefRegistryGuid,
        refs.ParentSourceRowId
    FROM
    (
        SELECT
            child.ID AS ChildStagedRowId,
            fk.RefRegistryGuid,
            TRY_CONVERT(BIGINT, JSON_VALUE(child.SourcePayloadJson, N'$."' + fk.ColumnName + N'"')) AS ParentSourceRowId
        FROM SMigration.Metadata_StagedRows AS child
        INNER JOIN #ForeignKeys AS fk
            ON fk.ChildRegistryGuid = child.RegistryGuid
        WHERE child.RunGuid = @RunGuid
          AND child.RowStatus NOT IN (0,254)
    ) AS refs
    WHERE refs.ParentSourceRowId IS NOT NULL;

    CREATE INDEX IX_ChildReferences_Parent ON #ChildReferences (RefRegistryGuid, ParentSourceRowId);

    CREATE TABLE #Edges
    (
        ChildStagedRowId BIGINT NOT NULL,
        ParentStagedRowId BIGINT NOT NULL,
        PRIMARY KEY CLUSTERED (ChildStagedRowId, ParentStagedRowId)
    );

    INSERT INTO #Edges
    (
        ChildStagedRowId,
        ParentStagedRowId
    )
    SELECT DISTINCT
        cr.ChildStagedRowId,
        parent.StagedRowId
    FROM #ChildReferences AS cr
    INNER JOIN #Rows AS parent
        ON parent.RegistryGuid = cr.RefRegistryGuid
       AND parent.SourceRowId = cr.ParentSourceRowId
    WHERE parent.StagedRowId <> cr.ChildStagedRowId;

    CREATE INDEX IX_Edges_Parent ON #Edges (ParentStagedRowId, ChildStagedRowId);

    CREATE TABLE #Closure
    (
        StagedRowId BIGINT NOT NULL PRIMARY KEY,
        IsSeed BIT NOT NULL,
        IsDownward BIT NOT NULL
    );

    INSERT INTO #Closure
    (
        StagedRowId,
        IsSeed,
        IsDownward
    )
    SELECT DISTINCT
        r.StagedRowId,
        1,
        1
    FROM OPENJSON(@SeedJson)
        WITH
        (
            SchemaName SYSNAME '$.SchemaName',
            TableName SYSNAME '$.TableName',
            SourceRowGuid UNIQUEIDENTIFIER '$.SourceRowGuid'
        ) AS seed
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.SchemaName = seed.SchemaName
       AND tr.TableName = seed.TableName
       AND tr.RowStatus NOT IN (0,254)
    INNER JOIN #Rows AS r
        ON r.RegistryGuid = tr.Guid
       AND r.SourceRowGuid = seed.SourceRowGuid
    WHERE r.IsSelectable = 1;

    -- 1. Down: rows that reference a seed row or a row already found this way.
    WHILE 1 = 1
    BEGIN
        INSERT INTO #Closure
        (
            StagedRowId,
            IsSeed,
            IsDownward
        )
        SELECT DISTINCT
            e.ChildStagedRowId,
            0,
            1
        FROM #Closure AS c
        INNER JOIN #Edges AS e
            ON e.ParentStagedRowId = c.StagedRowId
        INNER JOIN #Rows AS childRow
            ON childRow.StagedRowId = e.ChildStagedRowId
        WHERE c.IsDownward = 1
          AND childRow.IsSelectable = 1
          AND NOT EXISTS (SELECT 1 FROM #Closure AS existing WHERE existing.StagedRowId = e.ChildStagedRowId);

        IF @@ROWCOUNT = 0 BREAK;
    END;

    -- 2. Up: new parents of anything in the closure.
    WHILE 1 = 1
    BEGIN
        INSERT INTO #Closure
        (
            StagedRowId,
            IsSeed,
            IsDownward
        )
        SELECT DISTINCT
            e.ParentStagedRowId,
            0,
            0
        FROM #Closure AS c
        INNER JOIN #Edges AS e
            ON e.ChildStagedRowId = c.StagedRowId
        INNER JOIN #Rows AS parentRow
            ON parentRow.StagedRowId = e.ParentStagedRowId
        WHERE parentRow.IsSelectable = 1
          AND parentRow.DifferenceType = N'Insert'
          AND parentRow.HasOverride = 0
          AND NOT EXISTS (SELECT 1 FROM #Closure AS existing WHERE existing.StagedRowId = e.ParentStagedRowId);

        IF @@ROWCOUNT = 0 BREAK;
    END;

    DECLARE dependency_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            r.RegistryGuid,
            r.SourceRowGuid,
            r.DifferenceType,
            sel.Guid
        FROM #Closure AS c
        INNER JOIN #Rows AS r
            ON r.StagedRowId = c.StagedRowId
        LEFT JOIN SMigration.Metadata_RunSelections AS sel
            ON sel.RunGuid = @RunGuid
           AND sel.RegistryGuid = r.RegistryGuid
           AND sel.SourceRowGuid = r.SourceRowGuid
        WHERE c.IsSeed = 0
          AND
          (
              sel.Guid IS NULL
              OR sel.RowStatus IN (0,254)
          );

    OPEN dependency_cursor;

    FETCH NEXT FROM dependency_cursor
    INTO @RegistryGuid, @SourceRowGuid, @DifferenceType, @SelectionGuid;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @SelectionGuid = ISNULL(@SelectionGuid, NEWID());

        EXEC SMigration.MetadataDataObject_Ensure
            @Guid = @SelectionGuid,
            @SchemeName = N'SMigration',
            @ObjectName = N'Metadata_RunSelections';

        IF EXISTS (SELECT 1 FROM SMigration.Metadata_RunSelections AS sel WHERE sel.Guid = @SelectionGuid)
        BEGIN
            UPDATE SMigration.Metadata_RunSelections
            SET
                RowStatus = 1,
                DifferenceType = @DifferenceType,
                SelectionSource = N'Dependency',
                SelectedByUserId = ISNULL(SCore.GetCurrentUserId(), -1),
                SelectedOnUtc = SYSUTCDATETIME()
            WHERE Guid = @SelectionGuid;
        END
        ELSE
        BEGIN
            INSERT INTO SMigration.Metadata_RunSelections
            (
                Guid,
                RowStatus,
                RunGuid,
                RegistryGuid,
                SourceRowGuid,
                DifferenceType,
                SelectionSource,
                SelectedByUserId,
                SelectedOnUtc
            )
            SELECT
                @SelectionGuid,
                1,
                @RunGuid,
                @RegistryGuid,
                @SourceRowGuid,
                @DifferenceType,
                N'Dependency',
                ISNULL(SCore.GetCurrentUserId(), -1),
                SYSUTCDATETIME();
        END;

        SET @AddedCount += 1;

        FETCH NEXT FROM dependency_cursor
        INTO @RegistryGuid, @SourceRowGuid, @DifferenceType, @SelectionGuid;
    END;

    CLOSE dependency_cursor;
    DEALLOCATE dependency_cursor;

    IF @AddedCount > 0
    BEGIN
        UPDATE SMigration.Metadata_Run
        SET
            RunStatus = N'Staged',
            ValidatedOnUtc = NULL
        WHERE Guid = @RunGuid
          AND RowStatus NOT IN (0,254);
    END;

    SELECT @AddedCount AS AutoSelectedCount;
END
GO
