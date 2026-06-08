PRINT (N'Create table [SCore].[EntityHobts]')
GO
CREATE TABLE [SCore].[EntityHobts] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_EntityHoBTs_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_EntityHoBTs_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [SchemaName] [nvarchar](250) NOT NULL CONSTRAINT [DF_EntityHoBTs_SchemaName] DEFAULT (''),
  [ObjectName] [nvarchar](250) NOT NULL CONSTRAINT [DF_EntityHoBTs_ObjectName] DEFAULT (''),
  [EntityTypeID] [int] NOT NULL CONSTRAINT [DF_EntityHoBTs_EntityTypeID] DEFAULT (-1),
  [ObjectType] [char](1) NOT NULL CONSTRAINT [DF_EntityHoBTs_ObjectType] DEFAULT (''),
  [IsMainHoBT] [bit] NOT NULL CONSTRAINT [DF_EntityHoBTs_IsMainHoBT] DEFAULT (0),
  [IsReadOnlyOffline] [bit] NOT NULL CONSTRAINT [DF_EntityHoBTs_IsReadOnlyOffline] DEFAULT (0)
)
ON [METADATA]
GO

PRINT (N'Create primary key [PK_EntityHoBTs] on table [SCore].[EntityHobts]')
GO
ALTER TABLE [SCore].[EntityHobts] WITH NOCHECK
  ADD CONSTRAINT [PK_EntityHoBTs] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
GO

PRINT (N'Create index [IX_EntityHobts_EntityTypeID] on table [SCore].[EntityHobts]')
GO
CREATE INDEX [IX_EntityHobts_EntityTypeID]
  ON [SCore].[EntityHobts] ([EntityTypeID])
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_EntityTypeHobts] on table [SCore].[EntityHobts]')
GO
CREATE INDEX [IX_EntityTypeHobts]
  ON [SCore].[EntityHobts] ([EntityTypeID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_EntityHobts_SchemaName_ObjectName] on table [SCore].[EntityHobts]')
GO
CREATE UNIQUE INDEX [IX_UQ_EntityHobts_SchemaName_ObjectName]
  ON [SCore].[EntityHobts] ([SchemaName], [ObjectName], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_EntityHobts_RecordHistory] on table [SCore].[EntityHobts]')
GO
CREATE TRIGGER [SCore].[tg_EntityHobts_RecordHistory]
   ON  [SCore].[EntityHobts]	
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
			@TableName NVARCHAR(250) = N'EntityHobts',
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 30)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[SchemaName], N''),
					@NewValue = ISNULL(i.[SchemaName], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[SchemaName] <> i.[SchemaName])
                        OR  (ISNULL(d.[SchemaName], N'') <> ISNULL(i.[SchemaName], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SchemaName', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 33)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[ObjectName], N''),
					@NewValue = ISNULL(i.[ObjectName], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[ObjectName] <> i.[ObjectName])
                        OR  (ISNULL(d.[ObjectName], N'') <> ISNULL(i.[ObjectName], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ObjectName', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 34)
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
				VALUES(1, @SchemaName, @TableName, N'EntityTypeID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 35)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[ObjectType], N''),
					@NewValue = ISNULL(i.[ObjectType], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[ObjectType] <> i.[ObjectType])
                        OR  (ISNULL(d.[ObjectType], N'') <> ISNULL(i.[ObjectType], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ObjectType', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 36)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsMainHoBT], N''),
					@NewValue = ISNULL(i.[IsMainHoBT], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsMainHoBT] <> i.[IsMainHoBT])
                        OR  (ISNULL(d.[IsMainHoBT], N'') <> ISNULL(i.[IsMainHoBT], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsMainHoBT', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 37)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsReadOnlyOffline], N''),
					@NewValue = ISNULL(i.[IsReadOnlyOffline], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsReadOnlyOffline] <> i.[IsReadOnlyOffline])
                        OR  (ISNULL(d.[IsReadOnlyOffline], N'') <> ISNULL(i.[IsReadOnlyOffline], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsReadOnlyOffline', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 38)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_EntityHobts_DataObjects] on table [SCore].[EntityHobts]')
GO
ALTER TABLE [SCore].[EntityHobts] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityHobts_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_EntityHobts_DataObjects] on table [SCore].[EntityHobts]')
GO
ALTER TABLE [SCore].[EntityHobts]
  NOCHECK CONSTRAINT [FK_EntityHobts_DataObjects]
GO

PRINT (N'Create foreign key [FK_EntityHoBTs_EntityTypes] on table [SCore].[EntityHobts]')
GO
ALTER TABLE [SCore].[EntityHobts] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityHoBTs_EntityTypes] FOREIGN KEY ([EntityTypeID]) REFERENCES [SCore].[EntityTypes] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_EntityHobts_RowStatus] on table [SCore].[EntityHobts]')
GO
ALTER TABLE [SCore].[EntityHobts] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityHobts_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Add extended property [MS_Description] on table [SCore].[EntityHobts]')
GO
EXEC sys.sp_addextendedproperty N'MS_Description', N'Describes the structural object used for hold the Entity Properties', 'SCHEMA', N'SCore', 'TABLE', N'EntityHobts'
GO