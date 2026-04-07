SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT (N'Create procedure [SCore].[PostDeploymentScript]')
GO

CREATE PROCEDURE [SCore].[PostDeploymentScript]
AS
BEGIN
    SET NOCOUNT ON;

    /* =========================================================================================
       1) Add missing DataObjects rows for all main HoBT tables (RowStatus=1 EntityTypes only)
          - Avoid duplicate PK violations by:
            - DISTINCT (handles duplicate GUIDs in source tables)
            - NOT EXISTS (handles already-present DataObjects)
            - filters zero-guid
    ========================================================================================= */

    PRINT N'Add missing Data Object rows';

    DECLARE
          @MaxEntityType     INT
        , @CurrentEntityType INT = 0
        , @TableName         NVARCHAR(500)
        , @SchemaName        SYSNAME
        , @ObjectName        SYSNAME
        , @stmt              NVARCHAR(MAX);

    SELECT @MaxEntityType = MAX(et.ID)
    FROM SCore.EntityTypes et
    WHERE et.RowStatus = 1
      AND EXISTS
      (
          SELECT 1
          FROM SCore.EntityHoBTs eh
          WHERE eh.EntityTypeID = et.ID
            AND eh.ObjectType   = 'U'
            AND eh.RowStatus   NOT IN (0,254)
      );

    WHILE (@CurrentEntityType < ISNULL(@MaxEntityType, 0))
    BEGIN
        SELECT TOP (1)
              @TableName         = h.SchemaName + N'.' + h.ObjectName
            , @SchemaName        = h.SchemaName
            , @ObjectName        = h.ObjectName
            , @CurrentEntityType = et.ID
        FROM SCore.EntityTypes et
        JOIN SCore.EntityHoBTs h ON h.EntityTypeID = et.ID
        WHERE h.IsMainHoBT = 1
          AND h.ObjectType  = 'U'
          AND et.ID        > @CurrentEntityType
          AND et.RowStatus  = 1
        ORDER BY et.ID;

        IF @TableName IS NULL
            BREAK;

        PRINT @TableName;

        -- Build safe two-part name: [schema].[object]
        DECLARE @TwoPart NVARCHAR(512) =
            QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@ObjectName);

        -- Parameterised entity type id; DISTINCT to protect PK insert from dup GUIDs in the source table
        SET @stmt = N'
INSERT INTO SCore.DataObjects (Guid, RowStatus, EntityTypeId)
SELECT DISTINCT
      t1.Guid
    , t1.RowStatus
    , @EntityTypeId
FROM ' + @TwoPart + N' AS t1
WHERE
    t1.Guid IS NOT NULL
    AND t1.Guid <> ''00000000-0000-0000-0000-000000000000''
    AND NOT EXISTS
    (
        SELECT 1
        FROM SCore.DataObjects AS d
        WHERE d.Guid = t1.Guid
    );';

        EXEC sys.sp_executesql
            @stmt,
            N'@EntityTypeId INT',
            @EntityTypeId = @CurrentEntityType;
    END;

    /* =========================================================================================
       2) Re-enable any FKs that reference SCore.DataObjects
          (Your script had the CHECK form; keep it, but quote identifiers safely)
    ========================================================================================= */

    PRINT N'Enable Data Object Key Constraints';

    DECLARE
          @MaxId2     INT
        , @CurrentId2 INT
        , @stmt2      NVARCHAR(MAX);

    DECLARE @ForeignKeyStatements TABLE
    (
        id        INT IDENTITY(1,1) NOT NULL,
        statement NVARCHAR(4000) NOT NULL
    );

    INSERT @ForeignKeyStatements (statement)
    SELECT
        N'ALTER TABLE ' + QUOTENAME(SCHEMA_NAME(po.schema_id)) + N'.' + QUOTENAME(po.name)
        + N' CHECK CONSTRAINT ' + QUOTENAME(fk.name) + N';'
    FROM sys.foreign_keys fk
    JOIN sys.objects po ON fk.parent_object_id = po.object_id
    JOIN sys.objects ro ON fk.referenced_object_id = ro.object_id
    WHERE ro.name = N'DataObjects';

    SELECT
          @MaxId2     = MAX(id)
        , @CurrentId2 = 0
    FROM @ForeignKeyStatements;

    WHILE (@CurrentId2 < ISNULL(@MaxId2,0))
    BEGIN
        SELECT TOP (1)
              @CurrentId2 = id
            , @stmt2      = statement
        FROM @ForeignKeyStatements
        WHERE id > @CurrentId2
        ORDER BY id;

        PRINT @stmt2;
        EXEC sys.sp_executesql @stmt2;
    END;

    /* =========================================================================================
       3) Rebuild history triggers / enable schemabinding / ensure -1 defaults
    ========================================================================================= */

    PRINT N'Rebuild triggers';
    EXEC SCore.RebuildRecordHistoryTriggers;

    PRINT N'Enable Schema Binding';
    EXEC SCore.SCHEMABINDING @Apply = 1;

    PRINT N'Add missing default rows';
    EXEC SCore.CreateDefaultRows;

    /* =========================================================================================
       4) Ensure Agent job exists (fix: use @jobName everywhere consistently)
    ========================================================================================= */

    DECLARE @dbName  SYSNAME = DB_NAME();
    DECLARE @jobName SYSNAME = N'Entity Status Update - ' + @dbName;

    IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @jobName)
    BEGIN
        PRINT N'Creating Agent: ' + @jobName;

        EXEC msdb.dbo.sp_add_job
              @job_name = @jobName
            , @enabled  = 1;

        EXEC msdb.dbo.sp_add_jobstep
              @job_name      = @jobName
            , @step_name     = N'Run Status Update'
            , @command       = N'EXEC [SCore].[DataObjectTransitionAddCalculatedStatus];'
            , @database_name = @dbName;

        DECLARE @scheduleName SYSNAME = N'Daily 6AM - Entity Status Update - ' + @dbName;

        IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE name = @scheduleName)
        BEGIN
            EXEC msdb.dbo.sp_add_schedule
                  @schedule_name      = @scheduleName
                , @enabled            = 1
                , @freq_type          = 4      -- daily
                , @freq_interval      = 1
                , @freq_subday_type   = 1
                , @active_start_time  = 060000; -- 06:00
        END;

        EXEC msdb.dbo.sp_attach_schedule
              @job_name      = @jobName
            , @schedule_name = @scheduleName;

        EXEC msdb.dbo.sp_add_jobserver
              @job_name = @jobName;
    END;
END;
GO