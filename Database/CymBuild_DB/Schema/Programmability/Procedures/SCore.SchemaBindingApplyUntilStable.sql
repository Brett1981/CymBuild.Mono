SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SCore].[SchemaBindingApplyUntilStable]')
GO

/* =========================================================================================
   Helper: Apply schema binding repeatedly until dependency ordering settles

   Purpose:
   - Handles cases where view/function A can only become schema-bound after view/function B
     has become schema-bound.
   - Does NOT rewrite SQL.
   - Does NOT hide real schema-binding issues such as SELECT *, cross-database refs,
     missing two-part names, or unsupported syntax.
========================================================================================= */
CREATE PROCEDURE [SCore].[SchemaBindingApplyUntilStable]
(
      @MaxPasses           INT = 8
    , @ThrowOnFinalFailure BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    IF @MaxPasses IS NULL OR @MaxPasses < 1
        SET @MaxPasses = 1;

    DECLARE
          @Pass         INT = 1
        , @BoundBefore  BIGINT = 0
        , @BoundAfter   BIGINT = 0
        , @HadError     BIT = 0
        , @Message      NVARCHAR(4000);

    DECLARE @Errors TABLE
    (
          ID             INT IDENTITY(1,1) NOT NULL
        , PassNumber     INT NOT NULL
        , ErrorNumber    INT NULL
        , ErrorSeverity  INT NULL
        , ErrorState     INT NULL
        , ErrorLine      INT NULL
        , ErrorProcedure SYSNAME NULL
        , ErrorMessage   NVARCHAR(4000) NOT NULL
        , LoggedAtUtc    DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME()
    );

    WHILE @Pass <= @MaxPasses
    BEGIN
        SELECT
            @BoundBefore = COUNT_BIG(1)
        FROM sys.objects AS o
        WHERE o.[type] IN ('V', 'FN', 'IF', 'TF')
          AND CONVERT(INT, OBJECTPROPERTYEX(o.object_id, 'IsSchemaBound')) = 1;

        SET @Message =
            N'Schema binding pass '
            + CONVERT(NVARCHAR(20), @Pass)
            + N' of '
            + CONVERT(NVARCHAR(20), @MaxPasses)
            + N'. Currently schema-bound objects: '
            + CONVERT(NVARCHAR(20), @BoundBefore)
            + N'.';

        RAISERROR(@Message, 10, 1) WITH NOWAIT;

        BEGIN TRY
            EXEC [SCore].[SCHEMABINDING] @Apply = 1;
        END TRY
        BEGIN CATCH
            SET @HadError = 1;

            INSERT INTO @Errors
            (
                  PassNumber
                , ErrorNumber
                , ErrorSeverity
                , ErrorState
                , ErrorLine
                , ErrorProcedure
                , ErrorMessage
            )
            SELECT
                  @Pass
                , ERROR_NUMBER()
                , ERROR_SEVERITY()
                , ERROR_STATE()
                , ERROR_LINE()
                , ERROR_PROCEDURE()
                , ERROR_MESSAGE();

            SET @Message =
                N'Schema binding pass '
                + CONVERT(NVARCHAR(20), @Pass)
                + N' raised an error: '
                + ERROR_MESSAGE();

            RAISERROR(@Message, 10, 1) WITH NOWAIT;
        END CATCH;

        SELECT
            @BoundAfter = COUNT_BIG(1)
        FROM sys.objects AS o
        WHERE o.[type] IN ('V', 'FN', 'IF', 'TF')
          AND CONVERT(INT, OBJECTPROPERTYEX(o.object_id, 'IsSchemaBound')) = 1;

        SET @Message =
            N'Schema binding pass '
            + CONVERT(NVARCHAR(20), @Pass)
            + N' complete. Schema-bound objects after pass: '
            + CONVERT(NVARCHAR(20), @BoundAfter)
            + N'.';

        RAISERROR(@Message, 10, 1) WITH NOWAIT;

        IF @BoundAfter <= @BoundBefore
        BEGIN
            RAISERROR(N'No additional objects became schema-bound on this pass. Stopping retry loop.', 10, 1) WITH NOWAIT;
            BREAK;
        END;

        SET @Pass += 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM @Errors AS e
    )
    BEGIN
        SELECT
              e.PassNumber
            , e.ErrorNumber
            , e.ErrorSeverity
            , e.ErrorState
            , e.ErrorProcedure
            , e.ErrorLine
            , e.ErrorMessage
            , e.LoggedAtUtc
        FROM @Errors AS e
        ORDER BY
              e.ID;
    END;

    IF @ThrowOnFinalFailure = 1 AND @HadError = 1
    BEGIN
        THROW 51001, N'One or more schema-binding passes failed. Review the returned error list.', 1;
    END;
END;
GO