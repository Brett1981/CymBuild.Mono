PRINT (N'Create table [SCore].[LanguageLabelTranslations]')
GO
PRINT (N'Create table [SCore].[LanguageLabelTranslations]')
GO
CREATE TABLE [SCore].[LanguageLabelTranslations] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_LanguageLabelTranslations_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_LanguageLabelTranslations_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Text] [nvarchar](250) NOT NULL CONSTRAINT [DF_LanguageLabelTranslations_Text] DEFAULT (''),
  [TextPlural] [nvarchar](250) NOT NULL CONSTRAINT [DF_LanguageLabelTranslations_TextPlural] DEFAULT (''),
  [LanguageLabelID] [int] NOT NULL CONSTRAINT [DF_LanguageLabelTranslations_LanguageLabelID] DEFAULT (-1),
  [LanguageID] [int] NOT NULL CONSTRAINT [DF_LanguageLabelTranslations_LanguageID] DEFAULT (-1),
  [HelpText] [nvarchar](max) NOT NULL CONSTRAINT [DF_LanguageLabelTranslations_HelpText] DEFAULT ('')
)
ON [METADATA]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_LanguageLabelTranslations] on table [SCore].[LanguageLabelTranslations]')
GO
ALTER TABLE [SCore].[LanguageLabelTranslations] WITH NOCHECK
  ADD CONSTRAINT [PK_LanguageLabelTranslations] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_LanguageLabelTranslations_1008315981] on table [SCore].[LanguageLabelTranslations]')
GO
CREATE INDEX [IX_SCore_LanguageLabelTranslations_1008315981]
  ON [SCore].[LanguageLabelTranslations] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_LanguageLabelTranslations_1070317612] on table [SCore].[LanguageLabelTranslations]')
GO
CREATE INDEX [IX_SCore_LanguageLabelTranslations_1070317612]
  ON [SCore].[LanguageLabelTranslations] ([LanguageID])
  INCLUDE ([RowStatus], [LanguageLabelID])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_LanguageLabelTranslations_1112326884] on table [SCore].[LanguageLabelTranslations]')
GO
CREATE INDEX [IX_SCore_LanguageLabelTranslations_1112326884]
  ON [SCore].[LanguageLabelTranslations] ([LanguageLabelID], [RowStatus])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_LanguageLabelTranslations_1219597662] on table [SCore].[LanguageLabelTranslations]')
GO
CREATE INDEX [IX_SCore_LanguageLabelTranslations_1219597662]
  ON [SCore].[LanguageLabelTranslations] ([LanguageLabelID], [LanguageID])
  INCLUDE ([Guid])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_LanguageLabelTranslations_1368578410] on table [SCore].[LanguageLabelTranslations]')
GO
CREATE INDEX [IX_SCore_LanguageLabelTranslations_1368578410]
  ON [SCore].[LanguageLabelTranslations] ([LanguageLabelID], [LanguageID])
  INCLUDE ([RowStatus], [TextPlural])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_LanguageLabelTranslations_1684617698] on table [SCore].[LanguageLabelTranslations]')
GO
CREATE INDEX [IX_SCore_LanguageLabelTranslations_1684617698]
  ON [SCore].[LanguageLabelTranslations] ([LanguageLabelID], [LanguageID])
  INCLUDE ([RowStatus], [Text])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_LanguageLabelTranslations_1708317867] on table [SCore].[LanguageLabelTranslations]')
GO
CREATE INDEX [IX_SCore_LanguageLabelTranslations_1708317867]
  ON [SCore].[LanguageLabelTranslations] ([RowStatus])
  INCLUDE ([Guid], [LanguageLabelID], [LanguageID])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_LanguageLabelTranslations_184406494] on table [SCore].[LanguageLabelTranslations]')
GO
CREATE INDEX [IX_SCore_LanguageLabelTranslations_184406494]
  ON [SCore].[LanguageLabelTranslations] ([LanguageID])
  INCLUDE ([Guid], [LanguageLabelID])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_LanguageLabelTranslations_2005253351] on table [SCore].[LanguageLabelTranslations]')
GO
CREATE INDEX [IX_SCore_LanguageLabelTranslations_2005253351]
  ON [SCore].[LanguageLabelTranslations] ([LanguageLabelID], [LanguageID])
  INCLUDE ([RowStatus])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_LanguageLabelTranslations_2091017073] on table [SCore].[LanguageLabelTranslations]')
GO
CREATE INDEX [IX_SCore_LanguageLabelTranslations_2091017073]
  ON [SCore].[LanguageLabelTranslations] ([RowStatus])
  INCLUDE ([TextPlural], [LanguageLabelID], [LanguageID])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_LanguageLabelTranslations_2133444830] on table [SCore].[LanguageLabelTranslations]')
GO
CREATE INDEX [IX_SCore_LanguageLabelTranslations_2133444830]
  ON [SCore].[LanguageLabelTranslations] ([LanguageLabelID], [LanguageID], [RowStatus])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_LanguageLabelTranslations_309240280] on table [SCore].[LanguageLabelTranslations]')
GO
CREATE INDEX [IX_SCore_LanguageLabelTranslations_309240280]
  ON [SCore].[LanguageLabelTranslations] ([LanguageLabelID])
  INCLUDE ([RowStatus], [Guid], [LanguageID])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_LanguageLabelTranslations_486890439] on table [SCore].[LanguageLabelTranslations]')
GO
CREATE INDEX [IX_SCore_LanguageLabelTranslations_486890439]
  ON [SCore].[LanguageLabelTranslations] ([LanguageLabelID])
  INCLUDE ([RowStatus], [RowVersion], [Guid], [Text], [LanguageID])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_LanguageLabelTranslations_957225613] on table [SCore].[LanguageLabelTranslations]')
GO
CREATE INDEX [IX_SCore_LanguageLabelTranslations_957225613]
  ON [SCore].[LanguageLabelTranslations] ([Guid], [RowStatus])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_LanguageLabelTranslations_973519744] on table [SCore].[LanguageLabelTranslations]')
GO
CREATE INDEX [IX_SCore_LanguageLabelTranslations_973519744]
  ON [SCore].[LanguageLabelTranslations] ([RowStatus])
  INCLUDE ([Text], [LanguageLabelID], [LanguageID])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_LanguageLabelTranslations_981754635] on table [SCore].[LanguageLabelTranslations]')
GO
CREATE INDEX [IX_SCore_LanguageLabelTranslations_981754635]
  ON [SCore].[LanguageLabelTranslations] ([RowStatus])
  INCLUDE ([LanguageLabelID], [LanguageID])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_LanguageLabelTranslations_RecordHistory] on table [SCore].[LanguageLabelTranslations]')
GO
CREATE TRIGGER [SCore].[tg_LanguageLabelTranslations_RecordHistory]
   ON  [SCore].[LanguageLabelTranslations]	
   AFTER UPDATE
AS 
BEGIN
	SET NOCOUNT ON;

    IF (ISNULL(CONVERT(int, SESSION_CONTEXT(N'S_disable_triggers')), 0) = 1)
    BEGIN 
        RETURN
    END

    DECLARE	@PreviousValue NVARCHAR(MAX),
			@NewValue NVARCHAR(MAX),
			@UserID INT = 0,
			@SchemaName NVARCHAR(250) = N'SCore',
			@TableName NVARCHAR(250) = N'LanguageLabelTranslations',
			@ColumnName NVARCHAR(250),
			@MaxInsertedID BIGINT,
			@CurrentInsertedID BIGINT,
			@CurrentInsertedGuid UNIQUEIDENTIFIER

	SELECT @UserID = ISNULL(CONVERT(int, SESSION_CONTEXT(N'user_id')), -1)

	SELECT	@MaxInsertedID = MAX([ID]),
			@CurrentInsertedID = -1
	FROM	Inserted

	WHILE	(@CurrentInsertedID < @MaxInsertedID)
	BEGIN 
		SELECT	TOP(1) @CurrentInsertedID = i.[ID],
				@CurrentInsertedGuid = i.Guid
		FROM	Inserted i
		WHERE	(i.[ID] > @CurrentInsertedID)
			ORDER BY i.[ID]
		
		SELECT	
					@PreviousValue = ISNULL(d.[RowStatus], N''),
					@NewValue = ISNULL(i.[RowStatus], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[RowStatus] <> i.[RowStatus])
                        OR  (ISNULL(d.[RowStatus], N'') <> ISNULL(i.[RowStatus], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 13)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[Text], N''),
					@NewValue = ISNULL(i.[Text], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[Text] <> i.[Text])
                        OR  (ISNULL(d.[Text], N'') <> ISNULL(i.[Text], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Text', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 16)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[LanguageLabelID], N''),
					@NewValue = ISNULL(i.[LanguageLabelID], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[LanguageLabelID] <> i.[LanguageLabelID])
                        OR  (ISNULL(d.[LanguageLabelID], N'') <> ISNULL(i.[LanguageLabelID], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'LanguageLabelID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 17)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[LanguageID], N''),
					@NewValue = ISNULL(i.[LanguageID], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[LanguageID] <> i.[LanguageID])
                        OR  (ISNULL(d.[LanguageID], N'') <> ISNULL(i.[LanguageID], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'LanguageID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 18)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_LanguageLabelTranslations_DataObjects] on table [SCore].[LanguageLabelTranslations]')
GO
ALTER TABLE [SCore].[LanguageLabelTranslations] WITH NOCHECK
  ADD CONSTRAINT [FK_LanguageLabelTranslations_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_LanguageLabelTranslations_DataObjects] on table [SCore].[LanguageLabelTranslations]')
GO
ALTER TABLE [SCore].[LanguageLabelTranslations]
  NOCHECK CONSTRAINT [FK_LanguageLabelTranslations_DataObjects]
GO

PRINT (N'Create foreign key [FK_LanguageLabelTranslations_LanguageLabels] on table [SCore].[LanguageLabelTranslations]')
GO
ALTER TABLE [SCore].[LanguageLabelTranslations] WITH NOCHECK
  ADD CONSTRAINT [FK_LanguageLabelTranslations_LanguageLabels] FOREIGN KEY ([LanguageLabelID]) REFERENCES [SCore].[LanguageLabels] ([ID])
GO

PRINT (N'Create foreign key [FK_LanguageLabelTranslations_Languages] on table [SCore].[LanguageLabelTranslations]')
GO
ALTER TABLE [SCore].[LanguageLabelTranslations] WITH NOCHECK
  ADD CONSTRAINT [FK_LanguageLabelTranslations_Languages] FOREIGN KEY ([LanguageID]) REFERENCES [SCore].[Languages] ([ID])
GO

PRINT (N'Create foreign key [FK_LanguageLabelTranslations_RowStatus] on table [SCore].[LanguageLabelTranslations]')
GO
ALTER TABLE [SCore].[LanguageLabelTranslations] WITH NOCHECK
  ADD CONSTRAINT [FK_LanguageLabelTranslations_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO