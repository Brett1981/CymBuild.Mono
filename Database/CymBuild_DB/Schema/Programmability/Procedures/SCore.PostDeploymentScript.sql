SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SCore].[PostDeploymentScript]')
GO
PRINT (N'Create procedure [SCore].[PostDeploymentScript]')
GO


CREATE PROCEDURE [SCore].[PostDeploymentScript]
(
    @ThrowOnIssues BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    DECLARE @RunGuid UNIQUEIDENTIFIER = NEWID();

    INSERT INTO SCore.PostDeploymentRunLog
    (
          RunGuid
        , StepName
        , Severity
        , Message
    )
    VALUES
    (
          @RunGuid
        , N'PostDeployment'
        , N'Info'
        , N'Started SCore.PostDeploymentScript.'
    );

    /* =========================================================================================
       1) Add missing DataObjects rows for all active main HoBT tables
    ========================================================================================= */

    PRINT N'Add missing Data Object rows';

    DECLARE
          @WorkId        INT = 0
        , @MaxWorkId     INT = 0
        , @EntityTypeId  INT
        , @SchemaName    SYSNAME
        , @ObjectName    SYSNAME
        , @TwoPartName   NVARCHAR(517)
        , @stmt          NVARCHAR(MAX)
        , @InsertedRows  INT;

    DECLARE @EntityWork TABLE
    (
          WorkId       INT NOT NULL PRIMARY KEY
        , EntityTypeId INT NOT NULL
        , SchemaName   SYSNAME NOT NULL
        , ObjectName   SYSNAME NOT NULL
        , TwoPartName  NVARCHAR(517) NOT NULL
    );

    BEGIN TRY
        INSERT INTO @EntityWork
        (
              WorkId
            , EntityTypeId
            , SchemaName
            , ObjectName
            , TwoPartName
        )
        SELECT
              ROW_NUMBER() OVER
              (
                  ORDER BY
                        et.ID
                      , h.SchemaName
                      , h.ObjectName
              ) AS WorkId
            , et.ID AS EntityTypeId
            , h.SchemaName
            , h.ObjectName
            , QUOTENAME(h.SchemaName) + N'.' + QUOTENAME(h.ObjectName) AS TwoPartName
        FROM SCore.EntityTypes AS et
        JOIN SCore.EntityHoBTs AS h
            ON h.EntityTypeID = et.ID
        JOIN sys.schemas AS s
            ON s.name = h.SchemaName
        JOIN sys.tables AS t
            ON t.schema_id = s.schema_id
           AND t.name = h.ObjectName
        JOIN sys.columns AS cGuid
            ON cGuid.object_id = t.object_id
           AND cGuid.name = N'Guid'
        JOIN sys.columns AS cRowStatus
            ON cRowStatus.object_id = t.object_id
           AND cRowStatus.name = N'RowStatus'
        WHERE et.RowStatus = 1
          AND h.IsMainHoBT = 1
          AND h.ObjectType = N'U'
          AND h.RowStatus NOT IN (0, 254);

        SELECT
            @MaxWorkId = MAX(ew.WorkId)
        FROM @EntityWork AS ew;

        WHILE @WorkId < ISNULL(@MaxWorkId, 0)
        BEGIN
            SELECT TOP (1)
                  @WorkId       = ew.WorkId
                , @EntityTypeId = ew.EntityTypeId
                , @SchemaName   = ew.SchemaName
                , @ObjectName   = ew.ObjectName
                , @TwoPartName  = ew.TwoPartName
            FROM @EntityWork AS ew
            WHERE ew.WorkId > @WorkId
            ORDER BY
                ew.WorkId;

            PRINT @TwoPartName;

            SET @InsertedRows = 0;

            SET @stmt = N'
;WITH SourceRows AS
(
    SELECT
          t1.Guid
        , CAST(MAX(CONVERT(INT, ISNULL(t1.RowStatus, 1))) AS TINYINT) AS RowStatus
    FROM ' + @TwoPartName + N' AS t1
    WHERE t1.Guid IS NOT NULL
      AND t1.Guid <> CONVERT(UNIQUEIDENTIFIER, ''00000000-0000-0000-0000-000000000000'')
    GROUP BY
        t1.Guid
)
INSERT INTO SCore.DataObjects
(
      Guid
    , RowStatus
    , EntityTypeId
)
SELECT
      sr.Guid
    , sr.RowStatus
    , @EntityTypeId
FROM SourceRows AS sr
WHERE NOT EXISTS
(
    SELECT 1
    FROM SCore.DataObjects AS d WITH (UPDLOCK, HOLDLOCK)
    WHERE d.Guid = sr.Guid
);

SET @InsertedRows = @@ROWCOUNT;
';

            BEGIN TRY
                EXEC sys.sp_executesql
                      @stmt
                    , N'@EntityTypeId INT, @InsertedRows INT OUTPUT'
                    , @EntityTypeId = @EntityTypeId
                    , @InsertedRows = @InsertedRows OUTPUT;

                PRINT N'  Inserted missing DataObjects rows: ' + CONVERT(NVARCHAR(20), @InsertedRows);

                INSERT INTO SCore.PostDeploymentRunLog
                (
                      RunGuid
                    , StepName
                    , ObjectName
                    , Severity
                    , Message
                )
                VALUES
                (
                      @RunGuid
                    , N'Main HoBT DataObjects repair'
                    , @TwoPartName
                    , N'Info'
                    , N'Inserted '
                      + CONVERT(NVARCHAR(20), @InsertedRows)
                      + N' missing DataObjects rows using EntityTypeId '
                      + CONVERT(NVARCHAR(20), @EntityTypeId)
                );
            END TRY
            BEGIN CATCH
                INSERT INTO SCore.PostDeploymentRunLog
                (
                      RunGuid
                    , StepName
                    , ObjectName
                    , Severity
                    , Message
                    , ErrorNumber
                    , ErrorSeverity
                    , ErrorState
                    , ErrorLine
                    , ErrorProcedure
                )
                VALUES
                (
                      @RunGuid
                    , N'Main HoBT DataObjects repair'
                    , @TwoPartName
                    , N'Error'
                    , ERROR_MESSAGE()
                    , ERROR_NUMBER()
                    , ERROR_SEVERITY()
                    , ERROR_STATE()
                    , ERROR_LINE()
                    , ERROR_PROCEDURE()
                );
            END CATCH;
        END;
    END TRY
    BEGIN CATCH
        INSERT INTO SCore.PostDeploymentRunLog
        (
              RunGuid
            , StepName
            , Severity
            , Message
            , ErrorNumber
            , ErrorSeverity
            , ErrorState
            , ErrorLine
            , ErrorProcedure
        )
        VALUES
        (
              @RunGuid
            , N'Main HoBT DataObjects repair setup'
            , N'Error'
            , ERROR_MESSAGE()
            , ERROR_NUMBER()
            , ERROR_SEVERITY()
            , ERROR_STATE()
            , ERROR_LINE()
            , ERROR_PROCEDURE()
        );
    END CATCH;

    /* =========================================================================================
       2) Repair FK-backed tables, then validate DataObjects FKs without stopping at first error
    ========================================================================================= */

    PRINT N'Repair DataObjects for FK-backed tables';

    BEGIN TRY
        EXEC SCore.DataObjectsRepairForFkBackedTables
              @RunGuid = @RunGuid
            , @SchemaFilter = NULL
            , @AttemptMetadataRegistration = 0
            , @ThrowOnUnresolved = 0
            , @ValidateConstraints = 0;
    END TRY
    BEGIN CATCH
        INSERT INTO SCore.PostDeploymentRunLog
        (
              RunGuid
            , StepName
            , Severity
            , Message
            , ErrorNumber
            , ErrorSeverity
            , ErrorState
            , ErrorLine
            , ErrorProcedure
        )
        VALUES
        (
              @RunGuid
            , N'DataObjects FK-backed repair'
            , N'Error'
            , ERROR_MESSAGE()
            , ERROR_NUMBER()
            , ERROR_SEVERITY()
            , ERROR_STATE()
            , ERROR_LINE()
            , ERROR_PROCEDURE()
        );
    END CATCH;

    PRINT N'Enable Data Object Key Constraints';

    DECLARE
          @MaxId2     INT
        , @CurrentId2 INT = 0
        , @stmt2      NVARCHAR(MAX)
        , @FkObject   NVARCHAR(517)
        , @FkName     SYSNAME;

    DECLARE @ForeignKeyStatements TABLE
    (
          ID        INT IDENTITY(1,1) NOT NULL PRIMARY KEY
        , ObjectName NVARCHAR(517) NOT NULL
        , ConstraintName SYSNAME NOT NULL
        , Statement NVARCHAR(MAX) NOT NULL
    );

    BEGIN TRY
        INSERT INTO @ForeignKeyStatements
        (
              ObjectName
            , ConstraintName
            , Statement
        )
        SELECT
              QUOTENAME(SCHEMA_NAME(parentTable.schema_id)) + N'.' + QUOTENAME(parentTable.name) AS ObjectName
            , fk.name AS ConstraintName
            , N'ALTER TABLE '
              + QUOTENAME(SCHEMA_NAME(parentTable.schema_id))
              + N'.'
              + QUOTENAME(parentTable.name)
              + N' WITH CHECK CHECK CONSTRAINT '
              + QUOTENAME(fk.name)
              + N';' AS Statement
        FROM sys.foreign_keys AS fk
        JOIN sys.tables AS parentTable
            ON parentTable.object_id = fk.parent_object_id
        WHERE fk.referenced_object_id = OBJECT_ID(N'SCore.DataObjects', N'U')
        ORDER BY
              SCHEMA_NAME(parentTable.schema_id)
            , parentTable.name
            , fk.name;

        SELECT
              @MaxId2 = MAX(fks.ID)
        FROM @ForeignKeyStatements AS fks;

        WHILE @CurrentId2 < ISNULL(@MaxId2, 0)
        BEGIN
            SELECT TOP (1)
                  @CurrentId2 = fks.ID
                , @FkObject   = fks.ObjectName
                , @FkName     = fks.ConstraintName
                , @stmt2      = fks.Statement
            FROM @ForeignKeyStatements AS fks
            WHERE fks.ID > @CurrentId2
            ORDER BY
                fks.ID;

            PRINT @stmt2;

            BEGIN TRY
                EXEC sys.sp_executesql @stmt2;

                INSERT INTO SCore.PostDeploymentRunLog
                (
                      RunGuid
                    , StepName
                    , ObjectName
                    , Severity
                    , Message
                )
                VALUES
                (
                      @RunGuid
                    , N'DataObjects FK validation'
                    , @FkObject
                    , N'Info'
                    , N'Constraint validated: ' + QUOTENAME(@FkName)
                );
            END TRY
            BEGIN CATCH
                INSERT INTO SCore.PostDeploymentRunLog
                (
                      RunGuid
                    , StepName
                    , ObjectName
                    , Severity
                    , Message
                    , ErrorNumber
                    , ErrorSeverity
                    , ErrorState
                    , ErrorLine
                    , ErrorProcedure
                )
                VALUES
                (
                      @RunGuid
                    , N'DataObjects FK validation'
                    , @FkObject
                    , N'Error'
                    , ERROR_MESSAGE()
                    , ERROR_NUMBER()
                    , ERROR_SEVERITY()
                    , ERROR_STATE()
                    , ERROR_LINE()
                    , ERROR_PROCEDURE()
                );
            END CATCH;
        END;
    END TRY
    BEGIN CATCH
        INSERT INTO SCore.PostDeploymentRunLog
        (
              RunGuid
            , StepName
            , Severity
            , Message
            , ErrorNumber
            , ErrorSeverity
            , ErrorState
            , ErrorLine
            , ErrorProcedure
        )
        VALUES
        (
              @RunGuid
            , N'DataObjects FK validation setup'
            , N'Error'
            , ERROR_MESSAGE()
            , ERROR_NUMBER()
            , ERROR_SEVERITY()
            , ERROR_STATE()
            , ERROR_LINE()
            , ERROR_PROCEDURE()
        );
    END CATCH;

    /* =========================================================================================
       3) Rebuild triggers / schema binding / default rows
    ========================================================================================= */

    PRINT N'Rebuild triggers';

    BEGIN TRY
        EXEC SCore.RebuildRecordHistoryTriggers;

        INSERT INTO SCore.PostDeploymentRunLog
        (
              RunGuid
            , StepName
            , Severity
            , Message
        )
        VALUES
        (
              @RunGuid
            , N'Rebuild record history triggers'
            , N'Info'
            , N'RebuildRecordHistoryTriggers completed. Review SQL messages for any non-throwing dynamic SQL errors.'
        );
    END TRY
    BEGIN CATCH
        INSERT INTO SCore.PostDeploymentRunLog
        (
              RunGuid
            , StepName
            , Severity
            , Message
            , ErrorNumber
            , ErrorSeverity
            , ErrorState
            , ErrorLine
            , ErrorProcedure
        )
        VALUES
        (
              @RunGuid
            , N'Rebuild record history triggers'
            , N'Error'
            , ERROR_MESSAGE()
            , ERROR_NUMBER()
            , ERROR_SEVERITY()
            , ERROR_STATE()
            , ERROR_LINE()
            , ERROR_PROCEDURE()
        );
    END CATCH;

    PRINT N'Enable Schema Binding';

    BEGIN TRY
        DECLARE
              @SchemaBindingOuterPass        INT = 0
            , @SchemaBindingMaxOuterPasses   INT = 10
            , @SchemaBoundBefore             BIGINT = 0
            , @SchemaBoundAfter              BIGINT = 0
            , @SchemaBindingMadeProgress     BIT = 1;

        /*
            SCore.SCHEMABINDING is a stored procedure, not a table.

            We therefore detect progress by counting schema-bound modules in sys.sql_modules
            before and after each apply attempt.

            The loop stops when a pass makes no further schema-bound progress.
        */
        WHILE @SchemaBindingOuterPass < @SchemaBindingMaxOuterPasses
          AND @SchemaBindingMadeProgress = 1
        BEGIN
            SET @SchemaBindingOuterPass += 1;

            SELECT
                @SchemaBoundBefore = COUNT_BIG(1)
            FROM sys.sql_modules AS sm
            JOIN sys.objects AS o
                ON o.object_id = sm.object_id
            WHERE sm.is_schema_bound = 1
              AND o.is_ms_shipped = 0
              AND o.type IN
              (
                    N'V'   -- View
                  , N'FN'  -- Scalar function
                  , N'IF'  -- Inline table-valued function
                  , N'TF'  -- Multi-statement table-valued function
              );

            PRINT N'Schema binding outer pass '
                + CONVERT(NVARCHAR(20), @SchemaBindingOuterPass)
                + N' of '
                + CONVERT(NVARCHAR(20), @SchemaBindingMaxOuterPasses)
                + N'. Currently schema-bound modules: '
                + CONVERT(NVARCHAR(20), @SchemaBoundBefore)
                + N'.';

            INSERT INTO SCore.PostDeploymentRunLog
            (
                  RunGuid
                , StepName
                , Severity
                , Message
            )
            VALUES
            (
                  @RunGuid
                , N'Schema binding'
                , N'Info'
                , N'Starting schema-binding outer pass '
                  + CONVERT(NVARCHAR(20), @SchemaBindingOuterPass)
                  + N'. Currently schema-bound modules: '
                  + CONVERT(NVARCHAR(20), @SchemaBoundBefore)
            );

            /*
                Use the existing wrapper if present. This preserves its diagnostics/output.
            */
            EXEC SCore.SchemaBindingApplyDiscoveredDependencies
                  @RunGuid = @RunGuid
                , @Apply = 1
                , @MaxPasses = 4
                , @ThrowOnError = 0;

            EXEC SCore.SchemaBindingApplyUntilStable
                  @MaxPasses = 8
                , @ThrowOnFinalFailure = 0;

            SELECT
                @SchemaBoundAfter = COUNT_BIG(1)
            FROM sys.sql_modules AS sm
            JOIN sys.objects AS o
                ON o.object_id = sm.object_id
            WHERE sm.is_schema_bound = 1
              AND o.is_ms_shipped = 0
              AND o.type IN
              (
                    N'V'
                  , N'FN'
                  , N'IF'
                  , N'TF'
              );

            PRINT N'Schema binding outer pass '
                + CONVERT(NVARCHAR(20), @SchemaBindingOuterPass)
                + N' complete. Schema-bound modules before: '
                + CONVERT(NVARCHAR(20), @SchemaBoundBefore)
                + N', after: '
                + CONVERT(NVARCHAR(20), @SchemaBoundAfter)
                + N'.';

            INSERT INTO SCore.PostDeploymentRunLog
            (
                  RunGuid
                , StepName
                , Severity
                , Message
            )
            VALUES
            (
                  @RunGuid
                , N'Schema binding'
                , CASE
                      WHEN @SchemaBoundAfter > @SchemaBoundBefore THEN N'Info'
                      ELSE N'Warning'
                  END
                , N'Completed schema-binding outer pass '
                  + CONVERT(NVARCHAR(20), @SchemaBindingOuterPass)
                  + N'. Schema-bound modules before: '
                  + CONVERT(NVARCHAR(20), @SchemaBoundBefore)
                  + N', after: '
                  + CONVERT(NVARCHAR(20), @SchemaBoundAfter)
            );

            IF @SchemaBoundAfter > @SchemaBoundBefore
            BEGIN
                SET @SchemaBindingMadeProgress = 1;
            END
            ELSE
            BEGIN
                SET @SchemaBindingMadeProgress = 0;
            END;
        END;

        IF @SchemaBindingMadeProgress = 1
           AND @SchemaBindingOuterPass >= @SchemaBindingMaxOuterPasses
        BEGIN
            INSERT INTO SCore.PostDeploymentRunLog
            (
                  RunGuid
                , StepName
                , Severity
                , Message
            )
            VALUES
            (
                  @RunGuid
                , N'Schema binding'
                , N'Warning'
                , N'Schema-binding outer loop reached the maximum pass count. Further progress may still be possible; review schema-binding diagnostics.'
            );
        END;

        INSERT INTO SCore.PostDeploymentRunLog
        (
              RunGuid
            , StepName
            , Severity
            , Message
        )
        VALUES
        (
              @RunGuid
            , N'Schema binding'
            , N'Info'
            , N'Schema-binding outer loop completed. Review returned schema-binding diagnostics for unresolved objects.'
        );
    END TRY
    BEGIN CATCH
        INSERT INTO SCore.PostDeploymentRunLog
        (
              RunGuid
            , StepName
            , Severity
            , Message
            , ErrorNumber
            , ErrorSeverity
            , ErrorState
            , ErrorLine
            , ErrorProcedure
        )
        VALUES
        (
              @RunGuid
            , N'Schema binding'
            , N'Error'
            , ERROR_MESSAGE()
            , ERROR_NUMBER()
            , ERROR_SEVERITY()
            , ERROR_STATE()
            , ERROR_LINE()
            , ERROR_PROCEDURE()
        );
    END CATCH;

    PRINT N'Add missing default rows';

    BEGIN TRY
        EXEC SCore.CreateDefaultRows
          @RunGuid = @RunGuid
        , @ThrowOnError = 0;

        INSERT INTO SCore.PostDeploymentRunLog
        (
              RunGuid
            , StepName
            , Severity
            , Message
        )
        VALUES
        (
              @RunGuid
            , N'Create default rows'
            , N'Info'
            , N'CreateDefaultRows completed. Review SQL messages for any non-throwing insert errors.'
        );
    END TRY
    BEGIN CATCH
        INSERT INTO SCore.PostDeploymentRunLog
        (
              RunGuid
            , StepName
            , Severity
            , Message
            , ErrorNumber
            , ErrorSeverity
            , ErrorState
            , ErrorLine
            , ErrorProcedure
        )
        VALUES
        (
              @RunGuid
            , N'Create default rows'
            , N'Error'
            , ERROR_MESSAGE()
            , ERROR_NUMBER()
            , ERROR_SEVERITY()
            , ERROR_STATE()
            , ERROR_LINE()
            , ERROR_PROCEDURE()
        );
    END CATCH;

    /* =========================================================================================
       4) SQL Agent job
    ========================================================================================= */

    DECLARE
          @dbName             SYSNAME = DB_NAME()
        , @jobName            SYSNAME = N'Entity Status Update - ' + DB_NAME()
        , @scheduleName       SYSNAME = N'Daily 6AM - Entity Status Update - ' + DB_NAME()
        , @CanInspectAgent    BIT = 0
        , @AgentProbe         BIGINT = 0
        , @jobId              UNIQUEIDENTIFIER = NULL
        , @scheduleId         INT = NULL;

    BEGIN TRY
        SELECT
            @AgentProbe = COUNT_BIG(1)
        FROM msdb.dbo.sysjobs AS sj
        WHERE 1 = 0;

        SET @CanInspectAgent = 1;
    END TRY
    BEGIN CATCH
        SET @CanInspectAgent = 0;

        INSERT INTO SCore.PostDeploymentRunLog
        (
              RunGuid
            , StepName
            , Severity
            , Message
            , ErrorNumber
            , ErrorSeverity
            , ErrorState
            , ErrorLine
            , ErrorProcedure
        )
        VALUES
        (
              @RunGuid
            , N'SQL Agent job'
            , N'Warning'
            , N'Skipping SQL Agent job check/create. Current deploy identity cannot inspect msdb.dbo.sysjobs. Error: ' + ERROR_MESSAGE()
            , ERROR_NUMBER()
            , ERROR_SEVERITY()
            , ERROR_STATE()
            , ERROR_LINE()
            , ERROR_PROCEDURE()
        );
    END CATCH;

    IF @CanInspectAgent = 1
    BEGIN
        BEGIN TRY
            SELECT
                @jobId = sj.job_id
            FROM msdb.dbo.sysjobs AS sj
            WHERE sj.name = @jobName;

            IF @jobId IS NULL
            BEGIN
                EXEC msdb.dbo.sp_add_job
                      @job_name = @jobName
                    , @enabled  = 1
                    , @job_id   = @jobId OUTPUT;

                EXEC msdb.dbo.sp_add_jobstep
                      @job_name      = @jobName
                    , @step_name     = N'Run Status Update'
                    , @command       = N'EXEC [SCore].[DataObjectTransitionAddCalculatedStatus];'
                    , @database_name = @dbName;
            END;

            SELECT
                @scheduleId = ss.schedule_id
            FROM msdb.dbo.sysschedules AS ss
            WHERE ss.name = @scheduleName;

            IF @scheduleId IS NULL
            BEGIN
                EXEC msdb.dbo.sp_add_schedule
                      @schedule_name      = @scheduleName
                    , @enabled            = 1
                    , @freq_type          = 4
                    , @freq_interval      = 1
                    , @freq_subday_type   = 1
                    , @active_start_time  = 060000
                    , @schedule_id        = @scheduleId OUTPUT;
            END;

            IF @jobId IS NOT NULL
               AND @scheduleId IS NOT NULL
               AND NOT EXISTS
               (
                   SELECT 1
                   FROM msdb.dbo.sysjobschedules AS js
                   WHERE js.job_id = @jobId
                     AND js.schedule_id = @scheduleId
               )
            BEGIN
                EXEC msdb.dbo.sp_attach_schedule
                      @job_name      = @jobName
                    , @schedule_name = @scheduleName;
            END;

            IF @jobId IS NOT NULL
               AND NOT EXISTS
               (
                   SELECT 1
                   FROM msdb.dbo.sysjobservers AS jsv
                   WHERE jsv.job_id = @jobId
               )
            BEGIN
                EXEC msdb.dbo.sp_add_jobserver
                    @job_name = @jobName;
            END;

            INSERT INTO SCore.PostDeploymentRunLog
            (
                  RunGuid
                , StepName
                , ObjectName
                , Severity
                , Message
            )
            VALUES
            (
                  @RunGuid
                , N'SQL Agent job'
                , @jobName
                , N'Info'
                , N'SQL Agent job check/create completed.'
            );
        END TRY
        BEGIN CATCH
            INSERT INTO SCore.PostDeploymentRunLog
            (
                  RunGuid
                , StepName
                , ObjectName
                , Severity
                , Message
                , ErrorNumber
                , ErrorSeverity
                , ErrorState
                , ErrorLine
                , ErrorProcedure
            )
            VALUES
            (
                  @RunGuid
                , N'SQL Agent job'
                , @jobName
                , N'Warning'
                , N'SQL Agent job check/create failed but post-deploy continued. Error: ' + ERROR_MESSAGE()
                , ERROR_NUMBER()
                , ERROR_SEVERITY()
                , ERROR_STATE()
                , ERROR_LINE()
                , ERROR_PROCEDURE()
            );
        END CATCH;
    END;

    INSERT INTO SCore.PostDeploymentRunLog
    (
          RunGuid
        , StepName
        , Severity
        , Message
    )
    VALUES
    (
          @RunGuid
        , N'PostDeployment'
        , N'Info'
        , N'Completed SCore.PostDeploymentScript.'
    );

    /* =========================================================================================
       Final output
    ========================================================================================= */

    SELECT
          RunGuid = @RunGuid;

    SELECT
          Severity
        , IssueCount = COUNT_BIG(1)
    FROM SCore.PostDeploymentRunLog
    WHERE RunGuid = @RunGuid
    GROUP BY
        Severity
    ORDER BY
        CASE Severity
            WHEN N'Error' THEN 1
            WHEN N'Warning' THEN 2
            ELSE 3
        END;

    SELECT
          ID
        , StepName
        , ObjectName
        , Severity
        , Message
        , ErrorNumber
        , ErrorSeverity
        , ErrorState
        , ErrorLine
        , ErrorProcedure
        , CreatedUtc
    FROM SCore.PostDeploymentRunLog
    WHERE RunGuid = @RunGuid
      AND Severity IN (N'Error', N'Warning')
    ORDER BY
        ID;

    SELECT
          ID
        , StepName
        , ObjectName
        , Severity
        , Message
        , CreatedUtc
    FROM SCore.PostDeploymentRunLog
    WHERE RunGuid = @RunGuid
    ORDER BY
        ID;

    IF @ThrowOnIssues = 1
       AND EXISTS
       (
           SELECT 1
           FROM SCore.PostDeploymentRunLog
           WHERE RunGuid = @RunGuid
             AND Severity = N'Error'
       )
    BEGIN
        ;THROW 51090, N'SCore.PostDeploymentScript completed with logged errors. Review the returned post-deployment log.', 1;
    END;
END;
GO