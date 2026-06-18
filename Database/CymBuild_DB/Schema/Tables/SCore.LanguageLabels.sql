PRINT (N'Create table [SCore].[LanguageLabels]')
GO
CREATE TABLE [SCore].[LanguageLabels] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_LanguageLabels_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_LanguageLabels_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_LanguageLabels_Name] DEFAULT ('')
)
ON [METADATA]
GO

PRINT (N'Create primary key [PK_LanguageLabels] on table [SCore].[LanguageLabels]')
GO
ALTER TABLE [SCore].[LanguageLabels] WITH NOCHECK
  ADD CONSTRAINT [PK_LanguageLabels] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_LanguageLabels_1003669193] on table [SCore].[LanguageLabels]')
GO
CREATE INDEX [IX_SCore_LanguageLabels_1003669193]
  ON [SCore].[LanguageLabels] ([RowStatus])
  INCLUDE ([Guid], [Name])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_LanguageLabels_1008315981] on table [SCore].[LanguageLabels]')
GO
CREATE INDEX [IX_SCore_LanguageLabels_1008315981]
  ON [SCore].[LanguageLabels] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_LanguageLabels_1121071497] on table [SCore].[LanguageLabels]')
GO
CREATE INDEX [IX_SCore_LanguageLabels_1121071497]
  ON [SCore].[LanguageLabels] ([Guid])
  INCLUDE ([RowStatus])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_LanguageLabels_1325759773] on table [SCore].[LanguageLabels]')
GO
CREATE INDEX [IX_SCore_LanguageLabels_1325759773]
  ON [SCore].[LanguageLabels] ([RowStatus], [Name])
  INCLUDE ([Guid])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_LanguageLabels_1885346130] on table [SCore].[LanguageLabels]')
GO
CREATE INDEX [IX_SCore_LanguageLabels_1885346130]
  ON [SCore].[LanguageLabels] ([RowStatus])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_LanguageLabels_724871123] on table [SCore].[LanguageLabels]')
GO
CREATE INDEX [IX_SCore_LanguageLabels_724871123]
  ON [SCore].[LanguageLabels] ([RowStatus])
  INCLUDE ([Guid])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_LanguageLabels_794173022] on table [SCore].[LanguageLabels]')
GO
CREATE INDEX [IX_SCore_LanguageLabels_794173022]
  ON [SCore].[LanguageLabels] ([Name], [RowStatus])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_LanguageLabels_957225613] on table [SCore].[LanguageLabels]')
GO
CREATE INDEX [IX_SCore_LanguageLabels_957225613]
  ON [SCore].[LanguageLabels] ([Guid], [RowStatus])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_LanguageLabels_RecordHistory] on table [SCore].[LanguageLabels]')
GO
CREATE TRIGGER [SCore].[tg_LanguageLabels_RecordHistory]
   ON  [SCore].[LanguageLabels]	
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
			@TableName NVARCHAR(250) = N'LanguageLabels',
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 8)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[Name], N''),
					@NewValue = ISNULL(i.[Name], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[Name] <> i.[Name])
                        OR  (ISNULL(d.[Name], N'') <> ISNULL(i.[Name], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Name', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 11)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_LanguageLabels_RowStatus] on table [SCore].[LanguageLabels]')
GO
ALTER TABLE [SCore].[LanguageLabels] WITH NOCHECK
  ADD CONSTRAINT [FK_LanguageLabels_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO