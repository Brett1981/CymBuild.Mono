/* ================================================================================================
   CymBuild Metadata Migration - Apply existing validated run

   Required sqlcmd variables:
   - RunGuid
   - ForceApply

   Behaviour:
   - Re-validates the exact staged run.
   - Rebuilds identity map.
   - Applies staged metadata using SMigration.MetadataApply_Run.
   - Performs a post-apply execution log/run output.

   LIVE:
   - SMigration.MetadataApply_Run itself requires @ForceApply = 1 for TargetEnvironment = LIVE.
   ================================================================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @RunGuid UNIQUEIDENTIFIER = '$(RunGuid)',
    @ForceApply BIT = CONVERT(BIT, '$(ForceApply)');

BEGIN TRY
    EXEC SMigration.MetadataValidate_Run
        @RunGuid = @RunGuid;

    IF EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_ValidationIssues AS vi
        WHERE vi.RunGuid = @RunGuid
          AND vi.RowStatus NOT IN (0,254)
          AND vi.Severity = N'Fail'
    )
    BEGIN
        EXEC SMigration.MetadataRun_Get @RunGuid = @RunGuid;
        THROW 61010, N'Metadata apply validation failed. Resolve Fail issues before apply.', 1;
    END;

    EXEC SMigration.MetadataApplyIdentityMap_Build
        @RunGuid = @RunGuid;

    EXEC SMigration.MetadataApply_Run
        @RunGuid = @RunGuid,
        @ForceApply = @ForceApply;

    EXEC SMigration.MetadataRun_Get
        @RunGuid = @RunGuid;

    SELECT
        RunGuid = @RunGuid,
        ForceApply = @ForceApply,
        ResultMessage = N'Metadata apply completed successfully.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
        ROLLBACK TRAN;
    END;

    SELECT
        RunGuid = @RunGuid,
        ForceApply = @ForceApply,
        ErrorNumber = ERROR_NUMBER(),
        ErrorSeverity = ERROR_SEVERITY(),
        ErrorState = ERROR_STATE(),
        ErrorLine = ERROR_LINE(),
        ErrorProcedure = ERROR_PROCEDURE(),
        ErrorMessage = ERROR_MESSAGE();

    THROW;
END CATCH;
GO
