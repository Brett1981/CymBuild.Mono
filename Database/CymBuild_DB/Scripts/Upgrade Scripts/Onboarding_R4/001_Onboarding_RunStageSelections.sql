SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'SMigration.Onboarding_RunStageSelections', N'U') IS NULL
BEGIN
    CREATE TABLE [SMigration].[Onboarding_RunStageSelections]
    (
        [ID] [int] IDENTITY(1,1) NOT NULL,
        [Guid] [uniqueidentifier] ROWGUIDCOL NOT NULL,
        [RowStatus] [tinyint] NOT NULL,
        [RowVersion] [timestamp] NOT NULL,
        [RunGuid] [uniqueidentifier] NOT NULL,
        [EntityName] [nvarchar](200) NOT NULL,
        [RowGuid] [uniqueidentifier] NOT NULL,
        [SelectedByUserId] [int] NOT NULL,
        [SelectedOnUtc] [datetime2](7) NOT NULL,
        CONSTRAINT [PK_SMigration_Onboarding_RunStageSelections] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS i
    WHERE i.name = N'UX_SMigration_Onboarding_RunStageSelections_Run_Entity_Row'
      AND i.object_id = OBJECT_ID(N'SMigration.Onboarding_RunStageSelections')
)
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX [UX_SMigration_Onboarding_RunStageSelections_Run_Entity_Row]
    ON [SMigration].[Onboarding_RunStageSelections] ([RunGuid], [EntityName], [RowGuid])
    WHERE [RowStatus] NOT IN (0,254);
END;
GO

IF OBJECT_ID(N'SMigration.MetadataDataObject_Ensure', N'P') IS NOT NULL
BEGIN
    DECLARE @Existing TABLE (Guid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY);

    INSERT INTO @Existing (Guid)
    SELECT selection.Guid
    FROM SMigration.Onboarding_RunStageSelections AS selection
    WHERE selection.Guid IS NOT NULL
      AND NOT EXISTS
      (
          SELECT 1
          FROM SCore.DataObjects AS dataObject
          WHERE dataObject.Guid = selection.Guid
      );

    DECLARE @Guid UNIQUEIDENTIFIER;
    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT Guid FROM @Existing;
    OPEN cur;
    FETCH NEXT FROM cur INTO @Guid;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SMigration.MetadataDataObject_Ensure
            @Guid = @Guid,
            @SchemeName = N'SMigration',
            @ObjectName = N'Onboarding_RunStageSelections';
        FETCH NEXT FROM cur INTO @Guid;
    END;
    CLOSE cur;
    DEALLOCATE cur;
END;
GO
