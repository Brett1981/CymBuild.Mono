SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataRun_List]')
GO

CREATE PROCEDURE [SMigration].[MetadataRun_List]
(
    @Top INT = 100,
    @SourceEnvironment NVARCHAR(20) = NULL,
    @TargetEnvironment NVARCHAR(20) = NULL,
    @RunStatus NVARCHAR(30) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (ISNULL(@Top, 100))
        r.ID,
        r.Guid,
        r.RowStatus,
        r.SourceEnvironment,
        r.TargetEnvironment,
        r.SourceServerName,
        r.SourceDatabaseName,
        r.TargetServerName,
        r.TargetDatabaseName,
        r.RunStatus,
        r.IsValidateOnly,
        r.CreatedOnUtc,
        r.ValidatedOnUtc,
        r.AppliedOnUtc,
        r.CreatedByUserId,
        r.SummaryJson
    FROM SMigration.Metadata_Run AS r
    WHERE r.RowStatus NOT IN (0,254)
      AND (@SourceEnvironment IS NULL OR r.SourceEnvironment = @SourceEnvironment)
      AND (@TargetEnvironment IS NULL OR r.TargetEnvironment = @TargetEnvironment)
      AND (@RunStatus IS NULL OR r.RunStatus = @RunStatus)
    ORDER BY r.ID DESC;
END;
GO