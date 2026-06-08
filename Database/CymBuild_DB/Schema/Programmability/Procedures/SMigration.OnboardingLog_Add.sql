SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingLog_Add]')
GO

/* ================================================================================================
   Helper logger
   ================================================================================================ */
CREATE PROCEDURE [SMigration].[OnboardingLog_Add]
    @RunGuid         UNIQUEIDENTIFIER,
    @StepName        NVARCHAR(200),
    @EntityName      NVARCHAR(200),
    @ActionName      NVARCHAR(50),
    @AffectedCount   INT = 0,
    @Details         NVARCHAR(2000) = N''
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO SMigration.Onboarding_ExecutionLog
    (
        RunGuid, StepName, EntityName, ActionName, AffectedCount, Details
    )
    VALUES
    (
        @RunGuid, @StepName, @EntityName, @ActionName, @AffectedCount, @Details
    );
END

GO