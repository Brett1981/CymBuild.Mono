PRINT (N'Create table [SCore].[EntityPropertyGroups]')
GO
CREATE TABLE [SCore].[EntityPropertyGroups] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_EntityPropertyGroups_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_EntityPropertyGroups_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_EntityPropertyGroups_Name] DEFAULT (''),
  [IsHidden] [bit] NOT NULL CONSTRAINT [DF_EntityPropertyGroups_IsHidden] DEFAULT (0),
  [SortOrder] [smallint] NOT NULL CONSTRAINT [DF_EntityPropertyGroups_SortOrder] DEFAULT (0),
  [LanguageLabelID] [int] NOT NULL CONSTRAINT [DF_EntityPropertyGroups_LanguageLabelID] DEFAULT (-1),
  [EntityTypeID] [int] NOT NULL CONSTRAINT [DEFAULT_EntityPropertyGroups_EntityTypeID] DEFAULT (-1),
  [PropertyGroupLayoutID] [int] NOT NULL CONSTRAINT [DF_EntityPropertyGroups_PropertyGroupLayoutID] DEFAULT (-1),
  [ShowOnMobile] [bit] NOT NULL CONSTRAINT [DF_EntityPropertyGroups_ShowOnMobile] DEFAULT (0),
  [IsCollapsable] [bit] NOT NULL CONSTRAINT [DF_EntityPropertyGroups_IsCollapsable] DEFAULT (0),
  [IsDefaultCollapsed] [bit] NOT NULL CONSTRAINT [DF_EntityPropertyGroups_IsDefaultCollapsed] DEFAULT (0),
  [IsDefaultCollapsed_Mobile] [bit] NOT NULL CONSTRAINT [DF_EntityPropertyGroups_IsDefaultCollapsed_Moble] DEFAULT (0)
)
ON [METADATA]
GO

PRINT (N'Create primary key [PK_EntityPropertyGroups] on table [SCore].[EntityPropertyGroups]')
GO
ALTER TABLE [SCore].[EntityPropertyGroups] WITH NOCHECK
  ADD CONSTRAINT [PK_EntityPropertyGroups] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_EntityPropertyGroups_Guid] on table [SCore].[EntityPropertyGroups]')
GO
CREATE UNIQUE INDEX [IX_UQ_EntityPropertyGroups_Guid]
  ON [SCore].[EntityPropertyGroups] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_EntityPropertyGroups_RecordHistory] on table [SCore].[EntityPropertyGroups]')
GO
CREATE TRIGGER [SCore].[tg_EntityPropertyGroups_RecordHistory]
   ON  [SCore].[EntityPropertyGroups]	
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
			@TableName NVARCHAR(250) = N'EntityPropertyGroups',
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 162)
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
				VALUES(1, @SchemaName, @TableName, N'Name', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 165)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsHidden], N''),
					@NewValue = ISNULL(i.[IsHidden], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsHidden] <> i.[IsHidden])
                        OR  (ISNULL(d.[IsHidden], N'') <> ISNULL(i.[IsHidden], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsHidden', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 166)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[SortOrder], N''),
					@NewValue = ISNULL(i.[SortOrder], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[SortOrder] <> i.[SortOrder])
                        OR  (ISNULL(d.[SortOrder], N'') <> ISNULL(i.[SortOrder], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SortOrder', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 167)
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
				VALUES(1, @SchemaName, @TableName, N'LanguageLabelID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 168)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[EntityTypeID], N''),
					@NewValue = ISNULL(i.[EntityTypeID], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[EntityTypeID] <> i.[EntityTypeID])
                        OR  (ISNULL(d.[EntityTypeID], N'') <> ISNULL(i.[EntityTypeID], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EntityTypeID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 169)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[PropertyGroupLayoutID], N''),
					@NewValue = ISNULL(i.[PropertyGroupLayoutID], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[PropertyGroupLayoutID] <> i.[PropertyGroupLayoutID])
                        OR  (ISNULL(d.[PropertyGroupLayoutID], N'') <> ISNULL(i.[PropertyGroupLayoutID], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PropertyGroupLayoutID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 752)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_EntityPropertyGroups_EntityTypes] on table [SCore].[EntityPropertyGroups]')
GO
ALTER TABLE [SCore].[EntityPropertyGroups] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityPropertyGroups_EntityTypes] FOREIGN KEY ([EntityTypeID]) REFERENCES [SCore].[EntityTypes] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_EntityPropertyGroups_LanguageLabels] on table [SCore].[EntityPropertyGroups]')
GO
ALTER TABLE [SCore].[EntityPropertyGroups] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityPropertyGroups_LanguageLabels] FOREIGN KEY ([LanguageLabelID]) REFERENCES [SCore].[LanguageLabels] ([ID])
GO

PRINT (N'Create foreign key [FK_EntityPropertyGroups_PropertyGroupLayouts] on table [SCore].[EntityPropertyGroups]')
GO
ALTER TABLE [SCore].[EntityPropertyGroups] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityPropertyGroups_PropertyGroupLayouts] FOREIGN KEY ([PropertyGroupLayoutID]) REFERENCES [SUserInterface].[PropertyGroupLayouts] ([ID])
GO

PRINT (N'Create foreign key [FK_EntityPropertyGroups_RowStatus] on table [SCore].[EntityPropertyGroups]')
GO
ALTER TABLE [SCore].[EntityPropertyGroups] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityPropertyGroups_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Add extended property [MS_Description] on table [SCore].[EntityPropertyGroups]')
GO
EXEC sys.sp_addextendedproperty N'MS_Description', N'Records to group properties together', 'SCHEMA', N'SCore', 'TABLE', N'EntityPropertyGroups'
GO