PRINT (N'Create table [SUserInterface].[ActionMenuItems]')
GO
PRINT (N'Create table [SUserInterface].[ActionMenuItems]')
GO
CREATE TABLE [SUserInterface].[ActionMenuItems] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_ActionMenuItems_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ActionMenuItems_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [LanguageLabelId] [int] NOT NULL CONSTRAINT [DF_ActionMenuItems_LanguageLabelId] DEFAULT (-1),
  [IconCss] [nvarchar](100) NOT NULL CONSTRAINT [DF_ActionMenuItems_IconCss] DEFAULT (''),
  [Type] [nvarchar](1) NOT NULL CONSTRAINT [DF_ActionMenuItems_Type] DEFAULT (''),
  [EntityTypeId] [int] NOT NULL CONSTRAINT [DF_ActionMenuItems_EntityTypeId] DEFAULT (-1),
  [EntityQueryId] [int] NOT NULL CONSTRAINT [DF_ActionMenuItems_EntityQueryId] DEFAULT (-1),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF_ActionMenuItems_SortOrder] DEFAULT (0),
  [RedirectToTargetGuid] [bit] NOT NULL CONSTRAINT [DF_ActionMenuItems_RedirectToTargetGuid] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_ActionMenuItems] on table [SUserInterface].[ActionMenuItems]')
GO
ALTER TABLE [SUserInterface].[ActionMenuItems] WITH NOCHECK
  ADD CONSTRAINT [PK_ActionMenuItems] PRIMARY KEY CLUSTERED ([ID])
GO

PRINT (N'Create index [IX_UQ_ActionMenuItems_Gud] on table [SUserInterface].[ActionMenuItems]')
GO
CREATE UNIQUE INDEX [IX_UQ_ActionMenuItems_Gud]
  ON [SUserInterface].[ActionMenuItems] ([Guid])
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_ActionMenuItems_RecordHistory] on table [SUserInterface].[ActionMenuItems]')
GO
CREATE TRIGGER [SUserInterface].[tg_ActionMenuItems_RecordHistory]
   ON  [SUserInterface].[ActionMenuItems]	
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
			@TableName NVARCHAR(250) = N'ActionMenuItems',
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
				VALUES(1, @SchemaName, @TableName, N'EntityQueryId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 680)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[EntityTypeId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[EntityTypeId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[EntityTypeId] IS DISTINCT FROM i.[EntityTypeId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EntityTypeId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 681)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IconCss]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IconCss]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IconCss] IS DISTINCT FROM i.[IconCss])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IconCss', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 683)
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
				VALUES(1, @SchemaName, @TableName, N'LanguageLabelId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 685)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RedirectToTargetGuid]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RedirectToTargetGuid]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RedirectToTargetGuid] IS DISTINCT FROM i.[RedirectToTargetGuid])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RedirectToTargetGuid', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1398)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 686)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SortOrder]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SortOrder]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SortOrder] IS DISTINCT FROM i.[SortOrder])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SortOrder', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1397)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Type]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Type]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Type] IS DISTINCT FROM i.[Type])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Type', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 688)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_ActionMenuItems_DataObjects] on table [SUserInterface].[ActionMenuItems]')
GO
ALTER TABLE [SUserInterface].[ActionMenuItems] WITH NOCHECK
  ADD CONSTRAINT [FK_ActionMenuItems_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_ActionMenuItems_DataObjects] on table [SUserInterface].[ActionMenuItems]')
GO
ALTER TABLE [SUserInterface].[ActionMenuItems]
  NOCHECK CONSTRAINT [FK_ActionMenuItems_DataObjects]
GO

PRINT (N'Create foreign key [FK_ActionMenuItems_EntityQueries] on table [SUserInterface].[ActionMenuItems]')
GO
ALTER TABLE [SUserInterface].[ActionMenuItems] WITH NOCHECK
  ADD CONSTRAINT [FK_ActionMenuItems_EntityQueries] FOREIGN KEY ([EntityQueryId]) REFERENCES [SCore].[EntityQueries] ([ID])
GO

PRINT (N'Create foreign key [FK_ActionMenuItems_EntityTypes] on table [SUserInterface].[ActionMenuItems]')
GO
ALTER TABLE [SUserInterface].[ActionMenuItems] WITH NOCHECK
  ADD CONSTRAINT [FK_ActionMenuItems_EntityTypes] FOREIGN KEY ([EntityTypeId]) REFERENCES [SCore].[EntityTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_ActionMenuItems_LanguageLabels] on table [SUserInterface].[ActionMenuItems]')
GO
ALTER TABLE [SUserInterface].[ActionMenuItems] WITH NOCHECK
  ADD CONSTRAINT [FK_ActionMenuItems_LanguageLabels] FOREIGN KEY ([LanguageLabelId]) REFERENCES [SCore].[LanguageLabels] ([ID])
GO

PRINT (N'Create foreign key [FK_ActionMenuItems_RowStatus] on table [SUserInterface].[ActionMenuItems]')
GO
ALTER TABLE [SUserInterface].[ActionMenuItems] WITH NOCHECK
  ADD CONSTRAINT [FK_ActionMenuItems_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO