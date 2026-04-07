SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SCore].[ObjectSecurity_FindAndFixDamagedRecords]')
GO
CREATE PROCEDURE [SCore].[ObjectSecurity_FindAndFixDamagedRecords]
(
    @Apply BIT = 0, -- 0 = report only, 1 = delete invalid ObjectSecurity rows
    @EntityTypeNamesCsv NVARCHAR(MAX) = N'Jobs,Quotes,Enquiries,Enquiry Services,Quote Items' -- override if needed
)
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------------------------
    -- Detect which guid column ObjectSecurity uses: ObjectGuid or DataObjectGuid
    -------------------------------------------------------------------------
    DECLARE @OsGuidCol SYSNAME = NULL;

    IF COL_LENGTH('SCore.ObjectSecurity', 'ObjectGuid') IS NOT NULL
        SET @OsGuidCol = N'ObjectGuid';
    ELSE IF COL_LENGTH('SCore.ObjectSecurity', 'DataObjectGuid') IS NOT NULL
        SET @OsGuidCol = N'DataObjectGuid';
    ELSE
        THROW 60050, N'SCore.ObjectSecurity does not contain ObjectGuid or DataObjectGuid.', 1;

    -------------------------------------------------------------------------
    -- Parse entity type names
    -------------------------------------------------------------------------
    DECLARE @Names TABLE (Name NVARCHAR(250) PRIMARY KEY);

    INSERT INTO @Names(Name)
    SELECT LTRIM(RTRIM(value))
    FROM STRING_SPLIT(@EntityTypeNamesCsv, ',')
    WHERE LTRIM(RTRIM(value)) <> N'';

    -------------------------------------------------------------------------
    -- Build a list of target EntityTypeIds
    -------------------------------------------------------------------------
    DECLARE @TargetEntityTypes TABLE
    (
        EntityTypeId INT PRIMARY KEY,
        Name NVARCHAR(250)
    );

    INSERT INTO @TargetEntityTypes(EntityTypeId, Name)
    SELECT et.ID, et.Name
    FROM SCore.EntityTypes et
    JOIN @Names n ON n.Name = et.Name
    WHERE et.RowStatus NOT IN (0,254);

    IF NOT EXISTS (SELECT 1 FROM @TargetEntityTypes)
        THROW 60051, N'No matching active EntityTypes found for @EntityTypeNamesCsv.', 1;

    -------------------------------------------------------------------------
    -- Identify "damaged" objects:
    -- objects (DataObjects) in target entity types that have active ObjectSecurity
    -- rows with invalid GroupId (NULL/0/missing/inactive group)
    -------------------------------------------------------------------------
    DECLARE @Damaged TABLE
    (
        EntityTypeId INT,
        EntityTypeName NVARCHAR(250),
        DataObjectGuid UNIQUEIDENTIFIER,
        BadRowCount INT
    );

    DECLARE @sql NVARCHAR(MAX) = N'
    ;WITH TargetObjects AS
    (
        SELECT d.Guid AS DataObjectGuid, d.EntityTypeId
        FROM SCore.DataObjects d
        JOIN @TargetEntityTypes t ON t.EntityTypeId = d.EntityTypeId
        WHERE d.RowStatus NOT IN (0,254)
    ),
    BadSecurityRows AS
    (
        SELECT
            t.EntityTypeId,
            o.DataObjectGuid,
            COUNT(1) AS BadRowCount
        FROM TargetObjects o
        JOIN SCore.ObjectSecurity os
          ON os.' + QUOTENAME(@OsGuidCol) + N' = o.DataObjectGuid
        LEFT JOIN SCore.Groups g
          ON g.ID = os.GroupId
         AND g.RowStatus NOT IN (0,254)
        WHERE os.RowStatus NOT IN (0,254)
          AND (
                os.GroupId IS NULL
             OR os.GroupId = 0
             OR g.ID IS NULL  -- missing or inactive group
          )
        GROUP BY t.EntityTypeId, o.DataObjectGuid
    )
    SELECT
        b.EntityTypeId,
        t.Name AS EntityTypeName,
        b.DataObjectGuid,
        b.BadRowCount
    FROM BadSecurityRows b
    JOIN @TargetEntityTypes t ON t.EntityTypeId = b.EntityTypeId;
    ';

    INSERT INTO @Damaged(EntityTypeId, EntityTypeName, DataObjectGuid, BadRowCount)
    EXEC sp_executesql
        @sql,
        N'@TargetEntityTypes TABLE (EntityTypeId INT PRIMARY KEY, Name NVARCHAR(250)) READONLY',
        @TargetEntityTypes = @TargetEntityTypes;

    -------------------------------------------------------------------------
    -- Report (always)
    -------------------------------------------------------------------------
    SELECT
        EntityTypeName,
        COUNT(*)          AS DamagedObjectCount,
        SUM(BadRowCount)  AS BadObjectSecurityRowCount
    FROM @Damaged
    GROUP BY EntityTypeName
    ORDER BY EntityTypeName;

    SELECT TOP (500)
        EntityTypeName,
        DataObjectGuid,
        BadRowCount
    FROM @Damaged
    ORDER BY EntityTypeName, BadRowCount DESC, DataObjectGuid;

    -------------------------------------------------------------------------
    -- Apply fix (optional): delete only the invalid ObjectSecurity rows.
    -- Leaving *no* rows means Everyone (per your rule).
    -------------------------------------------------------------------------
    IF (@Apply = 1)
    BEGIN
        DECLARE @Deleted TABLE
        (
            EntityTypeName NVARCHAR(250),
            DataObjectGuid UNIQUEIDENTIFIER,
            DeletedRows INT
        );

        DECLARE @applySql NVARCHAR(MAX) = N'
        ;WITH Damaged AS
        (
            SELECT d.EntityTypeName, d.DataObjectGuid
            FROM @Damaged d
        ),
        ToDelete AS
        (
            SELECT
                d.EntityTypeName,
                os.' + QUOTENAME(@OsGuidCol) + N' AS DataObjectGuid,
                os.ID
            FROM Damaged d
            JOIN SCore.ObjectSecurity os
              ON os.' + QUOTENAME(@OsGuidCol) + N' = d.DataObjectGuid
            LEFT JOIN SCore.Groups g
              ON g.ID = os.GroupId
             AND g.RowStatus NOT IN (0,254)
            WHERE os.RowStatus NOT IN (0,254)
              AND (
                    os.GroupId IS NULL
                 OR os.GroupId = 0
                 OR g.ID IS NULL
              )
        )
        DELETE os
        OUTPUT
            t.EntityTypeName,
            deleted.' + QUOTENAME(@OsGuidCol) + N',
            1
        INTO @Deleted(EntityTypeName, DataObjectGuid, DeletedRows)
        FROM SCore.ObjectSecurity os
        JOIN ToDelete t ON t.ID = os.ID;
        ';

        EXEC sp_executesql
            @applySql,
            N'@Damaged TABLE (EntityTypeId INT, EntityTypeName NVARCHAR(250), DataObjectGuid UNIQUEIDENTIFIER, BadRowCount INT) READONLY,
              @Deleted TABLE (EntityTypeName NVARCHAR(250), DataObjectGuid UNIQUEIDENTIFIER, DeletedRows INT) OUTPUT',
            @Damaged = @Damaged,
            @Deleted = @Deleted;

        SELECT
            EntityTypeName,
            COUNT(DISTINCT DataObjectGuid) AS FixedObjectCount,
            SUM(DeletedRows)               AS DeletedBadRows
        FROM @Deleted
        GROUP BY EntityTypeName
        ORDER BY EntityTypeName;
    END
END;
GO