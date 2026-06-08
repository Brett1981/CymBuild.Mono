PRINT (N'Create table [SCore].[EntityQueryParameters]')
GO
CREATE TABLE [SCore].[EntityQueryParameters] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_EntityQueryParameters_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_EntityQueryParameters_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_EntityQueryParameters_Name] DEFAULT (''),
  [EntityQueryID] [int] NOT NULL CONSTRAINT [DF_EntityQueryParameters_EntityQueryID] DEFAULT (-1),
  [EntityDataTypeID] [int] NOT NULL CONSTRAINT [DF_EntityQueryParameters_EntityDateTypeID] DEFAULT (-1),
  [MappedEntityPropertyID] [int] NOT NULL CONSTRAINT [DF_EntityQueryParameters_EntityPropertyID] DEFAULT (-1),
  [DefaultValue] [nvarchar](100) NOT NULL CONSTRAINT [DF_EntityQueryParameters_DefaultValue] DEFAULT (''),
  [IsInput] [bit] NOT NULL CONSTRAINT [DF_EntityQueryParameters_IsInput] DEFAULT (0),
  [IsOutput] [bit] NOT NULL CONSTRAINT [DF_EntityQueryParameters_IsOutput] DEFAULT (0),
  [IsReturnColumn] [bit] NOT NULL CONSTRAINT [DF_EntityQueryParameters_IsReturnColumn] DEFAULT (0)
)
ON [METADATA]
GO

PRINT (N'Create primary key [PK_EntityQueryParameters] on table [SCore].[EntityQueryParameters]')
GO
ALTER TABLE [SCore].[EntityQueryParameters] WITH NOCHECK
  ADD CONSTRAINT [PK_EntityQueryParameters] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_EntityQueryParameters_Settings] on table [SCore].[EntityQueryParameters]')
GO
CREATE INDEX [IX_EntityQueryParameters_Settings]
  ON [SCore].[EntityQueryParameters] ([EntityQueryID], [RowStatus])
  INCLUDE ([RowVersion], [Guid], [Name], [EntityDataTypeID], [MappedEntityPropertyID])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_EntityQueryParameters_Guid] on table [SCore].[EntityQueryParameters]')
GO
CREATE UNIQUE INDEX [IX_UQ_EntityQueryParameters_Guid]
  ON [SCore].[EntityQueryParameters] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_EntityQueryParameters_RecordHistory] on table [SCore].[EntityQueryParameters]')
GO
CREATE TRIGGER [SCore].[tg_EntityQueryParameters_RecordHistory]
   ON  [SCore].[EntityQueryParameters]	
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
			@TableName NVARCHAR(250) = N'EntityQueryParameters',
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 72)
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
				VALUES(1, @SchemaName, @TableName, N'Name', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 75)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[EntityQueryID], N''),
					@NewValue = ISNULL(i.[EntityQueryID], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[EntityQueryID] <> i.[EntityQueryID])
                        OR  (ISNULL(d.[EntityQueryID], N'') <> ISNULL(i.[EntityQueryID], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EntityQueryID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 76)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[EntityDataTypeID], N''),
					@NewValue = ISNULL(i.[EntityDataTypeID], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[EntityDataTypeID] <> i.[EntityDataTypeID])
                        OR  (ISNULL(d.[EntityDataTypeID], N'') <> ISNULL(i.[EntityDataTypeID], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EntityDataTypeID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 77)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[MappedEntityPropertyID], N''),
					@NewValue = ISNULL(i.[MappedEntityPropertyID], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[MappedEntityPropertyID] <> i.[MappedEntityPropertyID])
                        OR  (ISNULL(d.[MappedEntityPropertyID], N'') <> ISNULL(i.[MappedEntityPropertyID], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'MappedEntityPropertyID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 78)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[DefaultValue], N''),
					@NewValue = ISNULL(i.[DefaultValue], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[DefaultValue] <> i.[DefaultValue])
                        OR  (ISNULL(d.[DefaultValue], N'') <> ISNULL(i.[DefaultValue], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DefaultValue', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 79)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsInput], N''),
					@NewValue = ISNULL(i.[IsInput], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsInput] <> i.[IsInput])
                        OR  (ISNULL(d.[IsInput], N'') <> ISNULL(i.[IsInput], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsInput', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 80)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsOutput], N''),
					@NewValue = ISNULL(i.[IsOutput], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsOutput] <> i.[IsOutput])
                        OR  (ISNULL(d.[IsOutput], N'') <> ISNULL(i.[IsOutput], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsOutput', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 81)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsReturnColumn], N''),
					@NewValue = ISNULL(i.[IsReturnColumn], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsReturnColumn] <> i.[IsReturnColumn])
                        OR  (ISNULL(d.[IsReturnColumn], N'') <> ISNULL(i.[IsReturnColumn], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsReturnColumn', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 82)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_EntityQueryParameters_DataObjects] on table [SCore].[EntityQueryParameters]')
GO
ALTER TABLE [SCore].[EntityQueryParameters] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityQueryParameters_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_EntityQueryParameters_DataObjects] on table [SCore].[EntityQueryParameters]')
GO
ALTER TABLE [SCore].[EntityQueryParameters]
  NOCHECK CONSTRAINT [FK_EntityQueryParameters_DataObjects]
GO

PRINT (N'Create foreign key [FK_EntityQueryParameters_EntityDataTypes] on table [SCore].[EntityQueryParameters]')
GO
ALTER TABLE [SCore].[EntityQueryParameters] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityQueryParameters_EntityDataTypes] FOREIGN KEY ([EntityDataTypeID]) REFERENCES [SCore].[EntityDataTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_EntityQueryParameters_EntityProperties] on table [SCore].[EntityQueryParameters]')
GO
ALTER TABLE [SCore].[EntityQueryParameters] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityQueryParameters_EntityProperties] FOREIGN KEY ([MappedEntityPropertyID]) REFERENCES [SCore].[EntityProperties] ([ID])
GO

PRINT (N'Create foreign key [FK_EntityQueryParameters_EntityQueries] on table [SCore].[EntityQueryParameters]')
GO
ALTER TABLE [SCore].[EntityQueryParameters] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityQueryParameters_EntityQueries] FOREIGN KEY ([EntityQueryID]) REFERENCES [SCore].[EntityQueries] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_EntityQueryParameters_RowStatus] on table [SCore].[EntityQueryParameters]')
GO
ALTER TABLE [SCore].[EntityQueryParameters] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityQueryParameters_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Add extended property [MS_Description] on table [SCore].[EntityQueryParameters]')
GO
EXEC sys.sp_addextendedproperty N'MS_Description', N'How to map the values of the Entity Properties to the Parameters of the Entity Query', 'SCHEMA', N'SCore', 'TABLE', N'EntityQueryParameters'
GO