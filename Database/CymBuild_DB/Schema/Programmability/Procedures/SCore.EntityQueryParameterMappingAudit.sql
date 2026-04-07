SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SCore].[EntityQueryParameterMappingAudit]')
GO
-- EXEC SCore.EntityQueryParameterMappingAudit @ApplyFix = 0, @Strict = 0, @AutoFixExactName = 0;
-- EXEC SCore.EntityQueryParameterMappingAudit @ApplyFix = 1, @Strict = 0, @AutoFixExactName = 1;

CREATE PROCEDURE [SCore].[EntityQueryParameterMappingAudit]
(
    @ApplyFix BIT = 0,              -- 0 = report only, 1 = apply SAFE fixes (DataObjects + optional remaps)
    @MaxRows  INT = 2000,           -- cap output sizes
    @Strict BIT = 0,                -- 1 = show all cross-HoBT mismatches, 0 = smart filter
    @AutoFixExactName BIT = 0       -- 1 = remap orphans + mismatches by exact-name-on-query-HoBT (+ safe special-cases)
)
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------------------------
    -- Detect EntityQueries shape
    -------------------------------------------------------------------------
    DECLARE
        @HasEqEntityHoBTID BIT = 0,
        @HasEqSchemaName   BIT = 0,
        @HasEqObjectName   BIT = 0;

    SELECT
        @HasEqEntityHoBTID = CASE WHEN EXISTS (
            SELECT 1 FROM sys.columns
            WHERE object_id = OBJECT_ID(N'SCore.EntityQueries')
              AND [name] = N'EntityHoBTID'
        ) THEN 1 ELSE 0 END,
        @HasEqSchemaName = CASE WHEN EXISTS (
            SELECT 1 FROM sys.columns
            WHERE object_id = OBJECT_ID(N'SCore.EntityQueries')
              AND [name] = N'SchemaName'
        ) THEN 1 ELSE 0 END,
        @HasEqObjectName = CASE WHEN EXISTS (
            SELECT 1 FROM sys.columns
            WHERE object_id = OBJECT_ID(N'SCore.EntityQueries')
              AND [name] = N'ObjectName'
        ) THEN 1 ELSE 0 END;

    IF (@HasEqEntityHoBTID = 0 AND NOT (@HasEqSchemaName = 1 AND @HasEqObjectName = 1))
    BEGIN
        ;THROW 60070,
            N'SCore.EntityQueries must expose either EntityHoBTID OR (SchemaName + ObjectName). Neither shape was detected.',
            1;
    END

    -------------------------------------------------------------------------
    -- Temp tables
    -------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#Mismatches') IS NOT NULL DROP TABLE #Mismatches;
    IF OBJECT_ID('tempdb..#Orphans') IS NOT NULL DROP TABLE #Orphans;
    IF OBJECT_ID('tempdb..#MissingDataObjects') IS NOT NULL DROP TABLE #MissingDataObjects;
    IF OBJECT_ID('tempdb..#FixCandidates') IS NOT NULL DROP TABLE #FixCandidates;
    IF OBJECT_ID('tempdb..#AppliedFixes') IS NOT NULL DROP TABLE #AppliedFixes;
    IF OBJECT_ID('tempdb..#QueryHoBTResolution') IS NOT NULL DROP TABLE #QueryHoBTResolution;
    IF OBJECT_ID('tempdb..#MissingDataObjects_EntityQueries') IS NOT NULL DROP TABLE #MissingDataObjects_EntityQueries;

    CREATE TABLE #Mismatches
    (
        EntityQueryID              INT,
        EntityQueryGuid            UNIQUEIDENTIFIER,
        EntityQueryName            NVARCHAR(250),

        QuerySchemaName            NVARCHAR(255) NULL,
        QueryObjectName            NVARCHAR(255) NULL,
        QueryEntityHoBTId          INT NULL,

        EntityQueryParameterId     INT,
        ParameterName              NVARCHAR(250),

        MappedEntityPropertyID     INT,
        MappedEntityPropertyName   NVARCHAR(250) NULL,
        MappedEntityPropertyGuid   UNIQUEIDENTIFIER NULL,

        PropertySchemaName         NVARCHAR(255) NULL,
        PropertyObjectName         NVARCHAR(255) NULL,
        PropertyEntityHoBTId       INT NULL
    );

    CREATE TABLE #Orphans
    (
        EntityQueryParameterId     INT,
        ParameterName              NVARCHAR(250),
        EntityQueryID              INT,
        EntityQueryName            NVARCHAR(250),
        EntityQueryGuid            UNIQUEIDENTIFIER,
        MappedEntityPropertyID     INT
    );

    CREATE TABLE #MissingDataObjects
    (
        EntityQueryParameterId     INT,
        ParamGuid                  UNIQUEIDENTIFIER,
        ParameterName              NVARCHAR(250),
        EntityQueryID              INT,
        RowStatus                  TINYINT
    );

    CREATE TABLE #MissingDataObjects_EntityQueries
    (
        EntityQueryID INT,
        QueryGuid UNIQUEIDENTIFIER,
        QueryName NVARCHAR(250),
        RowStatus TINYINT
    );

    CREATE TABLE #QueryHoBTResolution
    (
        EntityQueryID        INT PRIMARY KEY,
        CurrentEntityHoBTID  INT NULL,
        ResolvedEntityHoBTID INT NULL,
        ResolvedSchemaName   NVARCHAR(255) NULL,
        ResolvedObjectName   NVARCHAR(255) NULL,
        HasDiscrepancy       BIT NOT NULL
    );

    CREATE TABLE #FixCandidates
    (
        EntityQueryParameterId INT NOT NULL,
        EntityQueryID          INT NOT NULL,
        QueryEntityHoBTId      INT NOT NULL,
        ParameterName          NVARCHAR(250) NOT NULL,
        OldMappedEntityPropertyID INT NOT NULL,
        NewMappedEntityPropertyID INT NOT NULL,
        NewMappedEntityPropertyName NVARCHAR(250) NOT NULL,
        Reason NVARCHAR(200) NOT NULL
    );

    CREATE TABLE #AppliedFixes
    (
        EntityQueryParameterId INT,
        OldMappedEntityPropertyID INT,
        NewMappedEntityPropertyID INT,
        Reason NVARCHAR(200),
        AppliedAtUtc DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
    );

    -------------------------------------------------------------------------
    -- Resolve HoBT by (SchemaName,ObjectName) for discrepancy diagnostics
    -------------------------------------------------------------------------
    INSERT #QueryHoBTResolution (EntityQueryID, CurrentEntityHoBTID, ResolvedEntityHoBTID, ResolvedSchemaName, ResolvedObjectName, HasDiscrepancy)
    SELECT
        eq.ID,
        NULLIF(eq.EntityHoBTID, -1) AS CurrentEntityHoBTID,
        ehByName.ID                 AS ResolvedEntityHoBTID,
        eq.SchemaName,
        eq.ObjectName,
        CAST(CASE WHEN ehByName.ID IS NOT NULL
                   AND NULLIF(eq.EntityHoBTID, -1) IS NOT NULL
                   AND ehByName.ID <> NULLIF(eq.EntityHoBTID, -1)
                  THEN 1 ELSE 0 END AS BIT) AS HasDiscrepancy
    FROM SCore.EntityQueries eq
    LEFT JOIN SCore.EntityHoBTs ehByName
      ON ehByName.SchemaName = eq.SchemaName
     AND ehByName.ObjectName = eq.ObjectName
    WHERE eq.RowStatus NOT IN (0,254);

    -------------------------------------------------------------------------
    -- Dynamic mismatch/orphan fill (supports both EntityQueries shapes)
    -------------------------------------------------------------------------
    DECLARE @Sql NVARCHAR(MAX) = N'';
    DECLARE @Params NVARCHAR(MAX) = N'@MaxRows INT, @Strict BIT';

    IF (@HasEqEntityHoBTID = 1)
    BEGIN
        SET @Sql = N'
;WITH QueryToHoBT AS
(
    SELECT
        eq.ID     AS EntityQueryID,
        eq.[Guid] AS EntityQueryGuid,
        eq.[Name] AS EntityQueryName,
        eq.EntityHoBTID AS QueryEntityHoBTId,
        ehq.SchemaName  AS QuerySchemaName,
        ehq.ObjectName  AS QueryObjectName
    FROM SCore.EntityQueries eq
    LEFT JOIN SCore.EntityHoBTs ehq ON ehq.ID = eq.EntityHoBTID
    WHERE eq.RowStatus NOT IN (0,254)
),
ParamMap AS
(
    SELECT
        eqp.ID                  AS EntityQueryParameterId,
        eqp.[Name]              AS ParameterName,
        eqp.EntityQueryID,
        eqp.RowStatus,
        eqp.MappedEntityPropertyID,
        ep.[Name]               AS MappedEntityPropertyName,
        ep.[Guid]               AS MappedEntityPropertyGuid,
        ehp.ID                  AS PropertyEntityHoBTId,
        ehp.SchemaName          AS PropertySchemaName,
        ehp.ObjectName          AS PropertyObjectName
    FROM SCore.EntityQueryParameters eqp
    LEFT JOIN SCore.EntityProperties ep ON ep.ID = eqp.MappedEntityPropertyID
    LEFT JOIN SCore.EntityHoBTs ehp     ON ehp.ID = ep.EntityHoBTID
    WHERE eqp.RowStatus NOT IN (0,254)
)
INSERT #Mismatches
SELECT TOP (@MaxRows)
    q.EntityQueryID,
    q.EntityQueryGuid,
    q.EntityQueryName,
    q.QuerySchemaName,
    q.QueryObjectName,
    q.QueryEntityHoBTId,
    p.EntityQueryParameterId,
    p.ParameterName,
    p.MappedEntityPropertyID,
    p.MappedEntityPropertyName,
    p.MappedEntityPropertyGuid,
    p.PropertySchemaName,
    p.PropertyObjectName,
    p.PropertyEntityHoBTId
FROM QueryToHoBT q
JOIN ParamMap p ON p.EntityQueryID = q.EntityQueryID
WHERE
    ISNULL(p.MappedEntityPropertyID, -1) > 0
    AND p.PropertyEntityHoBTId IS NOT NULL
    AND q.QueryEntityHoBTId IS NOT NULL
    AND q.QueryEntityHoBTId > 0
    AND p.PropertyEntityHoBTId <> q.QueryEntityHoBTId
    AND (
        @Strict = 1
        OR
        (
            p.ParameterName <> N''@Guid''
            AND NOT (
                p.PropertyObjectName LIKE N''%ExtendedInfo%''
                OR p.PropertyObjectName LIKE N''%[_]ExtendedInfo''
                OR p.PropertyObjectName LIKE N''%[_]ShoreExt''
                OR p.PropertyObjectName LIKE N''%[_]Ext''
            )
        )
    )
ORDER BY q.EntityQueryName, p.ParameterName;

INSERT #Orphans
SELECT TOP (@MaxRows)
    eqp.ID,
    eqp.[Name],
    eqp.EntityQueryID,
    eq.[Name],
    eq.[Guid],
    eqp.MappedEntityPropertyID
FROM SCore.EntityQueryParameters eqp
JOIN SCore.EntityQueries eq ON eq.ID = eqp.EntityQueryID
LEFT JOIN SCore.EntityProperties ep ON ep.ID = eqp.MappedEntityPropertyID
WHERE
    eqp.RowStatus NOT IN (0,254)
    AND ISNULL(eqp.MappedEntityPropertyID, -1) > 0
    AND ep.ID IS NULL
ORDER BY eqp.EntityQueryID, eqp.ID;
';
    END
    ELSE
    BEGIN
        SET @Sql = N'
;WITH QueryToHoBT AS
(
    SELECT
        eq.ID     AS EntityQueryID,
        eq.[Guid] AS EntityQueryGuid,
        eq.[Name] AS EntityQueryName,
        ehq.ID        AS QueryEntityHoBTId,
        eq.SchemaName AS QuerySchemaName,
        eq.ObjectName AS QueryObjectName
    FROM SCore.EntityQueries eq
    LEFT JOIN SCore.EntityHoBTs ehq
        ON ehq.SchemaName = eq.SchemaName
       AND ehq.ObjectName = eq.ObjectName
    WHERE eq.RowStatus NOT IN (0,254)
),
ParamMap AS
(
    SELECT
        eqp.ID                  AS EntityQueryParameterId,
        eqp.[Name]              AS ParameterName,
        eqp.EntityQueryID,
        eqp.RowStatus,
        eqp.MappedEntityPropertyID,
        ep.[Name]               AS MappedEntityPropertyName,
        ep.[Guid]               AS MappedEntityPropertyGuid,
        ehp.ID                  AS PropertyEntityHoBTId,
        ehp.SchemaName          AS PropertySchemaName,
        ehp.ObjectName          AS PropertyObjectName
    FROM SCore.EntityQueryParameters eqp
    LEFT JOIN SCore.EntityProperties ep ON ep.ID = eqp.MappedEntityPropertyID
    LEFT JOIN SCore.EntityHoBTs ehp     ON ehp.ID = ep.EntityHoBTID
    WHERE eqp.RowStatus NOT IN (0,254)
)
INSERT #Mismatches
SELECT TOP (@MaxRows)
    q.EntityQueryID,
    q.EntityQueryGuid,
    q.EntityQueryName,
    q.QuerySchemaName,
    q.QueryObjectName,
    q.QueryEntityHoBTId,
    p.EntityQueryParameterId,
    p.ParameterName,
    p.MappedEntityPropertyID,
    p.MappedEntityPropertyName,
    p.MappedEntityPropertyGuid,
    p.PropertySchemaName,
    p.PropertyObjectName,
    p.PropertyEntityHoBTId
FROM QueryToHoBT q
JOIN ParamMap p ON p.EntityQueryID = q.EntityQueryID
WHERE
    ISNULL(p.MappedEntityPropertyID, -1) > 0
    AND p.PropertyEntityHoBTId IS NOT NULL
    AND q.QueryEntityHoBTId IS NOT NULL
    AND q.QueryEntityHoBTId > 0
    AND p.PropertyEntityHoBTId <> q.QueryEntityHoBTId
    AND (
        @Strict = 1
        OR
        (
            p.ParameterName <> N''@Guid''
            AND NOT (
                p.PropertyObjectName LIKE N''%ExtendedInfo%''
                OR p.PropertyObjectName LIKE N''%[_]ExtendedInfo''
                OR p.PropertyObjectName LIKE N''%[_]ShoreExt''
                OR p.PropertyObjectName LIKE N''%[_]Ext''
            )
        )
    )
ORDER BY q.EntityQueryName, p.ParameterName;

INSERT #Orphans
SELECT TOP (@MaxRows)
    eqp.ID,
    eqp.[Name],
    eqp.EntityQueryID,
    eq.[Name],
    eq.[Guid],
    eqp.MappedEntityPropertyID
FROM SCore.EntityQueryParameters eqp
JOIN SCore.EntityQueries eq ON eq.ID = eqp.EntityQueryID
LEFT JOIN SCore.EntityProperties ep ON ep.ID = eqp.MappedEntityPropertyID
WHERE
    eqp.RowStatus NOT IN (0,254)
    AND ISNULL(eqp.MappedEntityPropertyID, -1) > 0
    AND ep.ID IS NULL
ORDER BY eqp.EntityQueryID, eqp.ID;
';
    END

    EXEC sys.sp_executesql @Sql, @Params, @MaxRows = @MaxRows, @Strict = @Strict;

    -------------------------------------------------------------------------
    -- Missing DataObjects for EntityQueryParameters
    -------------------------------------------------------------------------
    INSERT #MissingDataObjects
    SELECT TOP (@MaxRows)
        eqp.ID,
        eqp.[Guid],
        eqp.[Name],
        eqp.EntityQueryID,
        eqp.RowStatus
    FROM SCore.EntityQueryParameters eqp
    LEFT JOIN SCore.DataObjects d ON d.[Guid] = eqp.[Guid]
    WHERE eqp.RowStatus NOT IN (0,254)
      AND d.[Guid] IS NULL
    ORDER BY eqp.ID DESC;

    -------------------------------------------------------------------------
    -- Missing DataObjects for EntityQueries
    -------------------------------------------------------------------------
    INSERT #MissingDataObjects_EntityQueries (EntityQueryID, QueryGuid, QueryName, RowStatus)
    SELECT TOP (@MaxRows)
        eq.ID,
        eq.[Guid],
        eq.[Name],
        eq.RowStatus
    FROM SCore.EntityQueries eq
    LEFT JOIN SCore.DataObjects d ON d.[Guid] = eq.[Guid]
    WHERE eq.RowStatus NOT IN (0,254)
      AND d.[Guid] IS NULL
    ORDER BY eq.ID DESC;

    -------------------------------------------------------------------------
    -- Build fix candidates (generic exact-name-on-query-HoBT) + safe special-case 379
    -------------------------------------------------------------------------
    IF (@AutoFixExactName = 1)
    BEGIN
        ;WITH Candidates AS
        (
            SELECT
                eqp.ID AS EntityQueryParameterId,
                eqp.EntityQueryID,
                eq.EntityHoBTID AS QueryEntityHoBTId,
                eqp.[Name] AS ParameterName,
                eqp.MappedEntityPropertyID AS OldMappedEntityPropertyID,

                CASE
                    WHEN LEFT(eqp.[Name], 1) = N'@' THEN SUBSTRING(eqp.[Name], 2, 250)
                    ELSE eqp.[Name]
                END AS ParamBase
            FROM SCore.EntityQueryParameters eqp
            JOIN SCore.EntityQueries eq ON eq.ID = eqp.EntityQueryID
            WHERE eqp.RowStatus NOT IN (0,254)
              AND ISNULL(eqp.MappedEntityPropertyID, -1) > 0
              AND ISNULL(eq.EntityHoBTID, -1) > 0
        ),
        Candidates2 AS
        (
            SELECT
                c.*,
                CASE
                    WHEN RIGHT(c.ParamBase, 4) = N'Guid' AND LEN(c.ParamBase) > 4
                        THEN LEFT(c.ParamBase, LEN(c.ParamBase) - 4)
                    ELSE NULL
                END AS BaseNoGuid
            FROM Candidates c
        ),
        TargetProps AS
        (
            SELECT
                c.EntityQueryParameterId,
                c.EntityQueryID,
                c.QueryEntityHoBTId,
                c.ParameterName,
                c.OldMappedEntityPropertyID,
                ep.ID AS NewMappedEntityPropertyID,
                ep.[Name] AS NewMappedEntityPropertyName,
                ROW_NUMBER() OVER (PARTITION BY c.EntityQueryParameterId ORDER BY ep.ID) AS rn,
                COUNT(1) OVER (PARTITION BY c.EntityQueryParameterId) AS cnt
            FROM Candidates2 c
            JOIN SCore.EntityProperties ep
              ON ep.EntityHoBTID = c.QueryEntityHoBTId
             AND ep.RowStatus NOT IN (0,254)
             AND (
                    ep.[Name] = c.ParamBase
                 OR ep.[Name] = c.ParamBase + N'Id'
                 OR ep.[Name] = c.ParamBase + N'Guid'
                 OR (c.BaseNoGuid IS NOT NULL AND ep.[Name] = c.BaseNoGuid)
                 OR (c.BaseNoGuid IS NOT NULL AND ep.[Name] = c.BaseNoGuid + N'ID')
                 OR (c.BaseNoGuid IS NOT NULL AND ep.[Name] = c.BaseNoGuid + N'Id')
                 OR (c.ParamBase = N'UserGroupGuid' AND ep.[Name] IN (N'GroupID', N'GroupId'))
                 OR (c.ParamBase = N'WorkflowGuid'  AND ep.[Name] IN (N'WorkflowID', N'WorkflowId'))
             )
        )
        INSERT #FixCandidates
        SELECT
            tp.EntityQueryParameterId,
            tp.EntityQueryID,
            tp.QueryEntityHoBTId,
            tp.ParameterName,
            tp.OldMappedEntityPropertyID,
            tp.NewMappedEntityPropertyID,
            tp.NewMappedEntityPropertyName,
            N'ExactNameOnQueryHoBT'
        FROM TargetProps tp
        WHERE tp.rn = 1
          AND tp.cnt = 1
          AND tp.NewMappedEntityPropertyID <> tp.OldMappedEntityPropertyID
          AND (
                EXISTS (SELECT 1 FROM #Orphans o WHERE o.EntityQueryParameterId = tp.EntityQueryParameterId)
             OR EXISTS (SELECT 1 FROM #Mismatches m WHERE m.EntityQueryParameterId = tp.EntityQueryParameterId)
          );

        -- Safe special-case for EntityQueryID 379
        INSERT #FixCandidates
        (
            EntityQueryParameterId,
            EntityQueryID,
            QueryEntityHoBTId,
            ParameterName,
            OldMappedEntityPropertyID,
            NewMappedEntityPropertyID,
            NewMappedEntityPropertyName,
            Reason
        )
        SELECT
            eqp.ID,
            eqp.EntityQueryID,
            eq.EntityHoBTID,
            eqp.[Name],
            eqp.MappedEntityPropertyID,
            ep.ID,
            ep.[Name],
            N'SpecialCase:379 WorkflowStatusNotificationGroupsUpsert'
        FROM SCore.EntityQueryParameters eqp
        JOIN SCore.EntityQueries eq ON eq.ID = eqp.EntityQueryID
        JOIN SCore.EntityProperties ep
          ON ep.EntityHoBTID = eq.EntityHoBTID
         AND ep.RowStatus NOT IN (0,254)
        WHERE eqp.RowStatus NOT IN (0,254)
          AND eqp.EntityQueryID = 379
          AND EXISTS (SELECT 1 FROM #Orphans o WHERE o.EntityQueryParameterId = eqp.ID)
          AND (
                (eqp.[Name] = N'@Guid'          AND ep.[Name] = N'Guid')
             OR (eqp.[Name] = N'@CanAction'     AND ep.[Name] = N'CanAction')
             OR (eqp.[Name] = N'@WorkflowGuid'  AND ep.[Name] = N'WorkflowID')
             OR (eqp.[Name] = N'@UserGroupGuid' AND ep.[Name] = N'GroupID')
          )
          AND ep.ID <> eqp.MappedEntityPropertyID
          AND NOT EXISTS (SELECT 1 FROM #FixCandidates fc WHERE fc.EntityQueryParameterId = eqp.ID);
    END

    -------------------------------------------------------------------------
    -- APPLY FIXES
    -------------------------------------------------------------------------
    IF (@ApplyFix = 1)
    BEGIN
        BEGIN TRY
            BEGIN TRAN;

            DECLARE @EntityTypeId_EntityQueryParameters INT = NULL;
            SELECT @EntityTypeId_EntityQueryParameters = eh.EntityTypeID
            FROM SCore.EntityHoBTs eh
            WHERE eh.SchemaName = N'SCore' AND eh.ObjectName = N'EntityQueryParameters';

            IF (ISNULL(@EntityTypeId_EntityQueryParameters, -1) < 0)
                THROW 60071, N'Cannot resolve EntityTypeID for SCore.EntityQueryParameters via SCore.EntityHoBTs.', 1;

            INSERT SCore.DataObjects ([Guid], RowStatus, EntityTypeId)
            SELECT m.ParamGuid, 1, @EntityTypeId_EntityQueryParameters
            FROM #MissingDataObjects m
            WHERE NOT EXISTS (SELECT 1 FROM SCore.DataObjects d WHERE d.[Guid] = m.ParamGuid);

            DECLARE @EntityTypeId_EntityQueries INT = NULL;
            SELECT @EntityTypeId_EntityQueries = eh.EntityTypeID
            FROM SCore.EntityHoBTs eh
            WHERE eh.SchemaName = N'SCore' AND eh.ObjectName = N'EntityQueries';

            IF (ISNULL(@EntityTypeId_EntityQueries, -1) < 0)
                THROW 60072, N'Cannot resolve EntityTypeID for SCore.EntityQueries via SCore.EntityHoBTs.', 1;

            INSERT SCore.DataObjects ([Guid], RowStatus, EntityTypeId)
            SELECT m.QueryGuid, 1, @EntityTypeId_EntityQueries
            FROM #MissingDataObjects_EntityQueries m
            WHERE NOT EXISTS (SELECT 1 FROM SCore.DataObjects d WHERE d.[Guid] = m.QueryGuid);

            IF (@AutoFixExactName = 1)
            BEGIN
                UPDATE eqp
                SET eqp.MappedEntityPropertyID = fc.NewMappedEntityPropertyID
                OUTPUT
                    inserted.ID,
                    deleted.MappedEntityPropertyID,
                    inserted.MappedEntityPropertyID,
                    fc.Reason,
                    SYSUTCDATETIME()
                INTO #AppliedFixes (EntityQueryParameterId, OldMappedEntityPropertyID, NewMappedEntityPropertyID, Reason, AppliedAtUtc)
                FROM SCore.EntityQueryParameters eqp
                JOIN #FixCandidates fc ON fc.EntityQueryParameterId = eqp.ID
                WHERE eqp.RowStatus NOT IN (0,254);
            END

            COMMIT;
        END TRY
        BEGIN CATCH
            IF (@@TRANCOUNT > 0) ROLLBACK;

            DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
            DECLARE @Num INT = ERROR_NUMBER();
            DECLARE @ThrowMessage NVARCHAR(4000);

            SET @ThrowMessage = CONCAT(N'ApplyFix failed: ', @Num, N': ', @Err);
            THROW 60020, @ThrowMessage, 1;
        END CATCH
    END

    -------------------------------------------------------------------------
    -- SUMMARY + RESULT SETS
    -------------------------------------------------------------------------
    SELECT
        @ApplyFix AS ApplyFix,
        @AutoFixExactName AS AutoFixExactName,
        (SELECT COUNT(1) FROM #Mismatches)         AS CrossHoBT_Mismatches,
        (SELECT COUNT(1) FROM #Orphans)            AS Orphan_MappedEntityPropertyID,
        (SELECT COUNT(1) FROM #MissingDataObjects) AS Missing_DataObjects_For_EntityQueryParameters,
        (SELECT COUNT(1) FROM #FixCandidates)      AS AutoFix_Candidates,
        (SELECT COUNT(1) FROM #AppliedFixes)       AS AutoFix_Applied;

    SELECT TOP (@MaxRows) *
    FROM #Mismatches
    ORDER BY EntityQueryName, ParameterName;

    SELECT TOP (@MaxRows) *
    FROM #Orphans
    ORDER BY EntityQueryID, EntityQueryParameterId;

    SELECT TOP (@MaxRows) *
    FROM #MissingDataObjects
    ORDER BY EntityQueryParameterId DESC;

    SELECT TOP (@MaxRows) *
    FROM #FixCandidates
    ORDER BY EntityQueryID, EntityQueryParameterId;

    SELECT TOP (@MaxRows) *
    FROM #AppliedFixes
    ORDER BY AppliedAtUtc DESC, EntityQueryParameterId DESC;

    SELECT TOP (@MaxRows)
        EntityQueryID,
        CurrentEntityHoBTID,
        ResolvedEntityHoBTID,
        ResolvedSchemaName,
        ResolvedObjectName,
        HasDiscrepancy
    FROM #QueryHoBTResolution
    WHERE HasDiscrepancy = 1
    ORDER BY EntityQueryID;
END;
GO