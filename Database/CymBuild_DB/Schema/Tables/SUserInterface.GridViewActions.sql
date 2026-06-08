PRINT (N'Create table [SUserInterface].[GridViewActions]')
GO
CREATE TABLE [SUserInterface].[GridViewActions] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_GridViewActions_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_GridViewActions_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [GridViewDefinitionId] [int] NOT NULL CONSTRAINT [DF_GridViewActions_GridViewDefinitionId] DEFAULT (-1),
  [LanguageLabelId] [int] NOT NULL DEFAULT (-1),
  [EntityQueryId] [int] NOT NULL CONSTRAINT [DF_GridViewActions_EntityQueryId] DEFAULT (-1)
)
ON [METADATA]
GO

PRINT (N'Create primary key [PK_GridViewActions] on table [SUserInterface].[GridViewActions]')
GO
ALTER TABLE [SUserInterface].[GridViewActions] WITH NOCHECK
  ADD CONSTRAINT [PK_GridViewActions] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_GridViewActions_Unique] on table [SUserInterface].[GridViewActions]')
GO
CREATE UNIQUE INDEX [IX_UQ_GridViewActions_Unique]
  ON [SUserInterface].[GridViewActions] ([GridViewDefinitionId], [EntityQueryId])
  ON [METADATA]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_GridViewActions_RecordHistory] on table [SUserInterface].[GridViewActions]')
GO
CREATE TRIGGER [SUserInterface].[tg_GridViewActions_RecordHistory]
   ON  [SUserInterface].[GridViewActions]	
   AFTER INSERT, UPDATE
AS 
BEGIN
	SET NOCOUNT ON;

    IF (ISNULL(CONVERT(int, SESSION_CONTEXT(N'S_disable_triggers')), 0) = 1)
    BEGIN 
        RETURN
    END

	IF (EXISTS
			(
				SELECT	1
				FROM	Inserted
				WHERE	(ID = -1) 
			)
		)
	BEGIN 
		;THROW 60000, N'Data integrity exception: Attempt to alter -1 record', 1
	END

    DECLARE	@PreviousValue NVARCHAR(MAX),
			@NewValue NVARCHAR(MAX),
			@UserID INT = 0,
			@SchemaName NVARCHAR(250) = N'SUserInterface',
			@TableName NVARCHAR(250) = N'GridViewActions',
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
		
		
		
		IF (NOT EXISTS 
				(
					SELECT	1
					FROM 	deleted d
					WHERE	(d.[ID] = @CurrentInsertedID)
				)
			)
		BEGIN 
				
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, N'', N'', SYSTEM_USER, -1)
	
			RETURN 
		END
		
		SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[EntityQueryId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[EntityQueryId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[EntityQueryId] IS DISTINCT FROM i.[EntityQueryId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EntityQueryId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1684)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[GridViewDefinitionId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[GridViewDefinitionId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[GridViewDefinitionId] IS DISTINCT FROM i.[GridViewDefinitionId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'GridViewDefinitionId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1682)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[LanguageLabelId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[LanguageLabelId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[LanguageLabelId] IS DISTINCT FROM i.[LanguageLabelId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'LanguageLabelId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1683)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RowStatus]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RowStatus]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RowStatus] IS DISTINCT FROM i.[RowStatus])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1679)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_GridViewActions_DataObjects] on table [SUserInterface].[GridViewActions]')
GO
ALTER TABLE [SUserInterface].[GridViewActions] WITH NOCHECK
  ADD CONSTRAINT [FK_GridViewActions_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_GridViewActions_DataObjects] on table [SUserInterface].[GridViewActions]')
GO
ALTER TABLE [SUserInterface].[GridViewActions]
  NOCHECK CONSTRAINT [FK_GridViewActions_DataObjects]
GO

PRINT (N'Create foreign key [FK_GridViewActions_EntityQueries] on table [SUserInterface].[GridViewActions]')
GO
ALTER TABLE [SUserInterface].[GridViewActions] WITH NOCHECK
  ADD CONSTRAINT [FK_GridViewActions_EntityQueries] FOREIGN KEY ([EntityQueryId]) REFERENCES [SCore].[EntityQueries] ([ID])
GO

PRINT (N'Create foreign key [FK_GridViewActions_GridViewDefinition] on table [SUserInterface].[GridViewActions]')
GO
ALTER TABLE [SUserInterface].[GridViewActions] WITH NOCHECK
  ADD CONSTRAINT [FK_GridViewActions_GridViewDefinition] FOREIGN KEY ([GridViewDefinitionId]) REFERENCES [SUserInterface].[GridViewDefinitions] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_GridViewActions_LanguageLabelId] on table [SUserInterface].[GridViewActions]')
GO
ALTER TABLE [SUserInterface].[GridViewActions] WITH NOCHECK
  ADD CONSTRAINT [FK_GridViewActions_LanguageLabelId] FOREIGN KEY ([LanguageLabelId]) REFERENCES [SCore].[LanguageLabels] ([ID])
GO

PRINT (N'Create foreign key [FK_GridViewActions_RowStatus] on table [SUserInterface].[GridViewActions]')
GO
ALTER TABLE [SUserInterface].[GridViewActions] WITH NOCHECK
  ADD CONSTRAINT [FK_GridViewActions_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO