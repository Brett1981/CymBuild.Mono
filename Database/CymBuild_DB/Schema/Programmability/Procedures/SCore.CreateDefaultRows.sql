SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SCore].[CreateDefaultRows]')
GO
PRINT (N'Create procedure [SCore].[CreateDefaultRows]')
GO

CREATE PROCEDURE [SCore].[CreateDefaultRows]
(
      @RunGuid       UNIQUEIDENTIFIER = NULL
    , @ThrowOnError  BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    DECLARE
          @OwnRunGuid BIT = 0
        , @CanLog     BIT = 0;

    IF @RunGuid IS NULL
    BEGIN
        SET @RunGuid = NEWID();
        SET @OwnRunGuid = 1;
    END;

    IF OBJECT_ID(N'SCore.PostDeploymentRunLog', N'U') IS NOT NULL
    BEGIN
        SET @CanLog = 1;
    END;

    IF @CanLog = 1
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
            , N'Create default rows'
            , N'Info'
            , N'Started CreateDefaultRows.'
        );
    END;

    BEGIN TRY
        EXEC sys.sp_set_session_context
              @key = N'S_disable_triggers'
            , @value = 1;

        DECLARE @Tables TABLE
        (
              ID              INT IDENTITY(1,1) NOT NULL PRIMARY KEY
            , ObjectId        INT NOT NULL
            , SchemaName      SYSNAME NOT NULL
            , TableName       SYSNAME NOT NULL
            , TwoPartName     NVARCHAR(517) NOT NULL
            , HasRowStatus    BIT NOT NULL
        );

        INSERT INTO @Tables
        (
              ObjectId
            , SchemaName
            , TableName
            , TwoPartName
            , HasRowStatus
        )
        SELECT
              t.object_id
            , SCHEMA_NAME(t.schema_id) AS SchemaName
            , t.name AS TableName
            , QUOTENAME(SCHEMA_NAME(t.schema_id)) + N'.' + QUOTENAME(t.name) AS TwoPartName
            , CASE
                  WHEN EXISTS
                  (
                      SELECT 1
                      FROM sys.columns AS c
                      WHERE c.object_id = t.object_id
                        AND c.name = N'RowStatus'
                  )
                  THEN 1
                  ELSE 0
              END AS HasRowStatus
        FROM sys.tables AS t
        WHERE EXISTS
        (
            SELECT 1
            FROM sys.columns AS c
            WHERE c.object_id = t.object_id
              AND c.name = N'ID'
              AND c.is_identity = 1
        )
        AND EXISTS
        (
            SELECT 1
            FROM sys.columns AS c
            WHERE c.object_id = t.object_id
              AND c.name = N'Guid'
        )
        ORDER BY
              CASE
                  WHEN SCHEMA_NAME(t.schema_id) = N'SCore'
                   AND t.name = N'DataObjects'
                  THEN 0
                  ELSE 1
              END
            , SCHEMA_NAME(t.schema_id)
            , t.name;

        DECLARE
              @MaxTableID             INT
            , @CurrentTableID         INT = 0
            , @CurrentObjectId        INT
            , @CurrentSchemaName      SYSNAME
            , @CurrentTableName       SYSNAME
            , @TwoPartName            NVARCHAR(517)
            , @HasRowStatus           BIT
            , @Exists                 BIT
            , @BlockingColumns        NVARCHAR(MAX)
            , @stmt                   NVARCHAR(MAX)
            , @InsertedRows           INT
            , @UpdatedRows            INT;

        SELECT
            @MaxTableID = MAX(t.ID)
        FROM @Tables AS t;

        WHILE @CurrentTableID < ISNULL(@MaxTableID, 0)
        BEGIN
            SELECT TOP (1)
                  @CurrentTableID    = t.ID
                , @CurrentObjectId   = t.ObjectId
                , @CurrentSchemaName = t.SchemaName
                , @CurrentTableName  = t.TableName
                , @TwoPartName       = t.TwoPartName
                , @HasRowStatus      = t.HasRowStatus
            FROM @Tables AS t
            WHERE t.ID > @CurrentTableID
            ORDER BY
                t.ID;

            SET @Exists = 0;
            SET @InsertedRows = 0;
            SET @UpdatedRows = 0;
            SET @BlockingColumns = NULL;

            /*
                Only auto-insert where all mandatory columns can be satisfied safely.

                Allowed:
                - ID: explicit identity insert
                - Guid: zero guid
                - RowStatus: 1
                - nullable columns
                - columns with defaults
                - computed columns
                - rowversion/timestamp columns

                Anything else is skipped and logged.
            */
            SELECT
                @BlockingColumns =
                    STRING_AGG(CONVERT(NVARCHAR(MAX), QUOTENAME(c.name)), N', ')
            FROM sys.columns AS c
            WHERE c.object_id = @CurrentObjectId
              AND c.is_nullable = 0
              AND c.default_object_id = 0
              AND c.is_identity = 0
              AND c.is_computed = 0
              AND c.system_type_id <> 189 -- timestamp / rowversion
              AND c.generated_always_type = 0
              AND c.name NOT IN
              (
                    N'ID'
                  , N'Guid'
                  , N'RowStatus'
              );

            IF @BlockingColumns IS NOT NULL
            BEGIN
                PRINT N'Skipping default row for ' + @TwoPartName
                    + N' because mandatory columns without defaults exist: '
                    + @BlockingColumns;

                IF @CanLog = 1
                BEGIN
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
                        , N'Create default rows'
                        , @TwoPartName
                        , N'Warning'
                        , N'Skipped default row insert because mandatory columns without defaults exist: '
                          + @BlockingColumns
                    );
                END;

                CONTINUE;
            END;

            SET @stmt =
                N'IF EXISTS
                  (
                      SELECT 1
                      FROM ' + @TwoPartName + N'
                      WHERE ID = -1
                  )
                  BEGIN
                      SET @Exists = 1;
                  END;';

            BEGIN TRY
                EXEC sys.sp_executesql
                      @stmt
                    , N'@Exists BIT OUTPUT'
                    , @Exists = @Exists OUTPUT;
            END TRY
            BEGIN CATCH
                IF @CanLog = 1
                BEGIN
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
                        , N'Create default rows - existence check'
                        , @TwoPartName
                        , N'Error'
                        , ERROR_MESSAGE()
                        , ERROR_NUMBER()
                        , ERROR_SEVERITY()
                        , ERROR_STATE()
                        , ERROR_LINE()
                        , ERROR_PROCEDURE()
                    );
                END;

                CONTINUE;
            END CATCH;

            IF @Exists <> 1
            BEGIN
                SET @stmt =
                    N'SET IDENTITY_INSERT ' + @TwoPartName + N' ON;

                      INSERT INTO ' + @TwoPartName + N'
                      (
                            [ID]
                          , [Guid]'
                          + CASE
                                WHEN @HasRowStatus = 1
                                THEN N'
                          , [RowStatus]'
                                ELSE N''
                            END
                          + N'
                      )
                      VALUES
                      (
                            -1
                          , CONVERT(UNIQUEIDENTIFIER, ''00000000-0000-0000-0000-000000000000'')'
                          + CASE
                                WHEN @HasRowStatus = 1
                                THEN N'
                          , 1'
                                ELSE N''
                            END
                          + N'
                      );

                      SET @InsertedRows = @@ROWCOUNT;

                      SET IDENTITY_INSERT ' + @TwoPartName + N' OFF;';

                BEGIN TRY
                    EXEC sys.sp_executesql
                          @stmt
                        , N'@InsertedRows INT OUTPUT'
                        , @InsertedRows = @InsertedRows OUTPUT;

                    PRINT N'Inserted default row for ' + @TwoPartName;

                    IF @CanLog = 1
                    BEGIN
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
                            , N'Create default rows'
                            , @TwoPartName
                            , N'Info'
                            , N'Inserted default row ID = -1. Rows inserted: '
                              + CONVERT(NVARCHAR(20), @InsertedRows)
                        );
                    END;
                END TRY
                BEGIN CATCH
                    BEGIN TRY
                        SET @stmt = N'SET IDENTITY_INSERT ' + @TwoPartName + N' OFF;';
                        EXEC sys.sp_executesql @stmt;
                    END TRY
                    BEGIN CATCH
                    END CATCH;

                    PRINT N'Failed to insert default row for ' + @TwoPartName
                        + N': '
                        + ERROR_MESSAGE();

                    IF @CanLog = 1
                    BEGIN
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
                            , N'Create default rows - insert'
                            , @TwoPartName
                            , N'Error'
                            , ERROR_MESSAGE()
                            , ERROR_NUMBER()
                            , ERROR_SEVERITY()
                            , ERROR_STATE()
                            , ERROR_LINE()
                            , ERROR_PROCEDURE()
                        );
                    END;
                END CATCH;
            END;
            ELSE
            BEGIN
                SET @stmt =
                    N'UPDATE ' + @TwoPartName + N'
                      SET [Guid] = CONVERT(UNIQUEIDENTIFIER, ''00000000-0000-0000-0000-000000000000'')'
                      + CASE
                            WHEN @HasRowStatus = 1
                            THEN N',
                          [RowStatus] = ISNULL([RowStatus], 1)'
                            ELSE N''
                        END
                      + N'
                      WHERE ID = -1
                        AND
                        (
                            [Guid] <> CONVERT(UNIQUEIDENTIFIER, ''00000000-0000-0000-0000-000000000000'')'
                      + CASE
                            WHEN @HasRowStatus = 1
                            THEN N'
                            OR [RowStatus] IS NULL'
                            ELSE N''
                        END
                      + N'
                        );

                      SET @UpdatedRows = @@ROWCOUNT;';

                BEGIN TRY
                    EXEC sys.sp_executesql
                          @stmt
                        , N'@UpdatedRows INT OUTPUT'
                        , @UpdatedRows = @UpdatedRows OUTPUT;

                    IF @UpdatedRows > 0
                    BEGIN
                        PRINT N'Corrected default row for ' + @TwoPartName;

                        IF @CanLog = 1
                        BEGIN
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
                                , N'Create default rows'
                                , @TwoPartName
                                , N'Info'
                                , N'Corrected existing default row ID = -1. Rows updated: '
                                  + CONVERT(NVARCHAR(20), @UpdatedRows)
                            );
                        END;
                    END;
                END TRY
                BEGIN CATCH
                    IF @CanLog = 1
                    BEGIN
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
                            , N'Create default rows - correction'
                            , @TwoPartName
                            , N'Error'
                            , ERROR_MESSAGE()
                            , ERROR_NUMBER()
                            , ERROR_SEVERITY()
                            , ERROR_STATE()
                            , ERROR_LINE()
                            , ERROR_PROCEDURE()
                        );
                    END;
                END CATCH;
            END;
        END;

        EXEC sys.sp_set_session_context
              @key = N'S_disable_triggers'
            , @value = 0;

        IF @CanLog = 1
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
                , N'Create default rows'
                , N'Info'
                , N'Completed CreateDefaultRows.'
            );
        END;
    END TRY
    BEGIN CATCH
        BEGIN TRY
            EXEC sys.sp_set_session_context
                  @key = N'S_disable_triggers'
                , @value = 0;
        END TRY
        BEGIN CATCH
        END CATCH;

        IF @CanLog = 1
        BEGIN
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
        END;

        IF @ThrowOnError = 1
        BEGIN
            THROW;
        END;
    END CATCH;

    IF @OwnRunGuid = 1
       AND @CanLog = 1
    BEGIN
        SELECT
              RunGuid = @RunGuid;

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
        ORDER BY
            ID;
    END;

    IF @ThrowOnError = 1
       AND @CanLog = 1
       AND EXISTS
       (
           SELECT 1
           FROM SCore.PostDeploymentRunLog
           WHERE RunGuid = @RunGuid
             AND Severity = N'Error'
             AND StepName LIKE N'Create default rows%'
       )
    BEGIN
        THROW 51100, N'CreateDefaultRows completed with logged errors. Review SCore.PostDeploymentRunLog.', 1;
    END;
END;
GO