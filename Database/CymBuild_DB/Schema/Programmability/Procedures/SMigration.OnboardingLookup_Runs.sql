SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingLookup_Runs]')
GO

CREATE PROCEDURE [SMigration].[OnboardingLookup_Runs]
    @SourceDatabase SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Guid = CAST(r.RunGuid AS NVARCHAR(36)),
        Name = CONCAT(CONVERT(NVARCHAR(19), r.CreatedUtc, 120), N' - ', r.SourceDatabase),
        Code = ISNULL(r.SourceDatabase, N''),
        Description = CONCAT(
            CONVERT(NVARCHAR(19), r.CreatedUtc, 120),
            N' | ',
            r.SourceDatabase,
            N' | ',
            ISNULL(r.Notes, N'')
        )
    FROM SMigration.Onboarding_Run AS r
    WHERE (@SourceDatabase IS NULL OR @SourceDatabase = N'' OR r.SourceDatabase = @SourceDatabase)
    ORDER BY r.CreatedUtc DESC;
END
GO