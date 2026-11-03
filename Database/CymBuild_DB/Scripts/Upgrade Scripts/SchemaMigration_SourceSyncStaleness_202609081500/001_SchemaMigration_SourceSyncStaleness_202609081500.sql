SET XACT_ABORT ON;
GO

PRINT (N'Ensure column [SMigration].[Schema_Run].[SourceSyncedOnUtc] exists')
GO
IF COL_LENGTH(N'SMigration.Schema_Run', N'SourceSyncedOnUtc') IS NULL
BEGIN
    ALTER TABLE [SMigration].[Schema_Run]
        ADD [SourceSyncedOnUtc] [datetime2](7) NULL;
END;
GO

PRINT (N'Ensure column [SMigration].[Schema_Run].[SourceSyncCommit] exists')
GO
IF COL_LENGTH(N'SMigration.Schema_Run', N'SourceSyncCommit') IS NULL
BEGIN
    ALTER TABLE [SMigration].[Schema_Run]
        ADD [SourceSyncCommit] [nvarchar](64) NULL;
END;
GO
