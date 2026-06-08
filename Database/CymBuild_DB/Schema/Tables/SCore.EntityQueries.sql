PRINT (N'Create table [SCore].[EntityQueries]')
GO
CREATE TABLE [SCore].[EntityQueries] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_EntityQueries_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_EntityQuerues_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_EntityQueries_Name] DEFAULT (''),
  [Statement] [nvarchar](max) NOT NULL CONSTRAINT [DF_EntityQueries_Statement] DEFAULT (''),
  [EntityTypeID] [int] NOT NULL CONSTRAINT [DF_EntityQueries_EntityTypeID] DEFAULT (-1),
  [EntityHoBTID] [int] NOT NULL CONSTRAINT [DEFAULT_EntityQueries_EnityHoBTID] DEFAULT (-1),
  [IsDefaultCreate] [bit] NOT NULL CONSTRAINT [DF_EntityQueries_IsDefaultCreate] DEFAULT (0),
  [IsDefaultRead] [bit] NOT NULL CONSTRAINT [DF_EntityQueries_IsDefaultRead] DEFAULT (0),
  [IsDefaultUpdate] [bit] NOT NULL CONSTRAINT [DF_EntityQueries_IsDefaultUpdate] DEFAULT (0),
  [IsDefaultDelete] [bit] NOT NULL CONSTRAINT [DF_EntityQueries_IsDefaultDelete] DEFAULT (0),
  [IsScalarExecute] [bit] NOT NULL CONSTRAINT [DF_EntityQueries_IsScalarExecute] DEFAULT (0),
  [IsDefaultValidation] [bit] NOT NULL CONSTRAINT [DEFAULT_EntityQueries_IsDefaultValidation] DEFAULT (0),
  [UsesProcessGuid] [bit] NOT NULL CONSTRAINT [DEFAULT_EntityQueries_UsesProcessGuid] DEFAULT (0),
  [IsDefaultDataPills] [bit] NOT NULL CONSTRAINT [DEFAULT_EntityQueries_IsDefaultDataPills] DEFAULT (0),
  [IsProgressData] [bit] NOT NULL CONSTRAINT [DF_EntityQueries_IsProgressData] DEFAULT (0),
  [IsMergeDocumentQuery] [bit] NOT NULL CONSTRAINT [DF_EntityQueries_IsMergeDocumentQuery] DEFAULT (0),
  [SchemaName] [nvarchar](255) NOT NULL CONSTRAINT [DF_EntityQueries_SchemaName] DEFAULT (''),
  [ObjectName] [nvarchar](255) NOT NULL CONSTRAINT [DF_EntityQueries_ObjectName] DEFAULT (''),
  [IsManualStatement] [bit] NOT NULL CONSTRAINT [DF_EntityQueries_IsManualStatement] DEFAULT (0)
)
ON [METADATA]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_EntityQueries] on table [SCore].[EntityQueries]')
GO
ALTER TABLE [SCore].[EntityQueries] WITH NOCHECK
  ADD CONSTRAINT [PK_EntityQueries] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80) ON [METADATA]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_EntityQueries_EntityTypeID] on table [SCore].[EntityQueries]')
GO
CREATE INDEX [IX_EntityQueries_EntityTypeID]
  ON [SCore].[EntityQueries] ([EntityTypeID], [RowStatus])
  INCLUDE ([RowVersion], [Guid], [Name], [EntityHoBTID], [IsDefaultCreate], [IsDefaultRead], [IsDefaultUpdate], [IsDefaultDelete], [IsProgressData], [Statement], [IsScalarExecute], [IsDefaultValidation], [IsDefaultDataPills])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_EntityQueries_Guid] on table [SCore].[EntityQueries]')
GO
CREATE UNIQUE INDEX [IX_UQ_EntityQueries_Guid]
  ON [SCore].[EntityQueries] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_EntityQueries_RecordHistory] on table [SCore].[EntityQueries]')
GO
CREATE TRIGGER [SCore].[tg_EntityQueries_RecordHistory]
   ON  [SCore].[EntityQueries]	
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
			@TableName NVARCHAR(250) = N'EntityQueries',
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 60)
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
				VALUES(1, @SchemaName, @TableName, N'Name', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 63)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[Statement], N''),
					@NewValue = ISNULL(i.[Statement], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[Statement] <> i.[Statement])
                        OR  (ISNULL(d.[Statement], N'') <> ISNULL(i.[Statement], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Statement', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 64)
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
				VALUES(1, @SchemaName, @TableName, N'EntityTypeID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 65)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsDefaultCreate], N''),
					@NewValue = ISNULL(i.[IsDefaultCreate], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsDefaultCreate] <> i.[IsDefaultCreate])
                        OR  (ISNULL(d.[IsDefaultCreate], N'') <> ISNULL(i.[IsDefaultCreate], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsDefaultCreate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 66)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsDefaultRead], N''),
					@NewValue = ISNULL(i.[IsDefaultRead], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsDefaultRead] <> i.[IsDefaultRead])
                        OR  (ISNULL(d.[IsDefaultRead], N'') <> ISNULL(i.[IsDefaultRead], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsDefaultRead', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 67)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsDefaultUpdate], N''),
					@NewValue = ISNULL(i.[IsDefaultUpdate], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsDefaultUpdate] <> i.[IsDefaultUpdate])
                        OR  (ISNULL(d.[IsDefaultUpdate], N'') <> ISNULL(i.[IsDefaultUpdate], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsDefaultUpdate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 68)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsDefaultDelete], N''),
					@NewValue = ISNULL(i.[IsDefaultDelete], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsDefaultDelete] <> i.[IsDefaultDelete])
                        OR  (ISNULL(d.[IsDefaultDelete], N'') <> ISNULL(i.[IsDefaultDelete], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsDefaultDelete', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 69)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsScalarExecute], N''),
					@NewValue = ISNULL(i.[IsScalarExecute], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsScalarExecute] <> i.[IsScalarExecute])
                        OR  (ISNULL(d.[IsScalarExecute], N'') <> ISNULL(i.[IsScalarExecute], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsScalarExecute', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 70)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsDefaultValidation], N''),
					@NewValue = ISNULL(i.[IsDefaultValidation], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsDefaultValidation] <> i.[IsDefaultValidation])
                        OR  (ISNULL(d.[IsDefaultValidation], N'') <> ISNULL(i.[IsDefaultValidation], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsDefaultValidation', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 443)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[EntityHoBTID], N''),
					@NewValue = ISNULL(i.[EntityHoBTID], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[EntityHoBTID] <> i.[EntityHoBTID])
                        OR  (ISNULL(d.[EntityHoBTID], N'') <> ISNULL(i.[EntityHoBTID], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EntityHoBTID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 444)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsDefaultDataPills], N''),
					@NewValue = ISNULL(i.[IsDefaultDataPills], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsDefaultDataPills] <> i.[IsDefaultDataPills])
                        OR  (ISNULL(d.[IsDefaultDataPills], N'') <> ISNULL(i.[IsDefaultDataPills], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsDefaultDataPills', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 741)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsMergeDocumentQuery], N''),
					@NewValue = ISNULL(i.[IsMergeDocumentQuery], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsMergeDocumentQuery] <> i.[IsMergeDocumentQuery])
                        OR  (ISNULL(d.[IsMergeDocumentQuery], N'') <> ISNULL(i.[IsMergeDocumentQuery], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsMergeDocumentQuery', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 742)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsProgressData], N''),
					@NewValue = ISNULL(i.[IsProgressData], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsProgressData] <> i.[IsProgressData])
                        OR  (ISNULL(d.[IsProgressData], N'') <> ISNULL(i.[IsProgressData], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsProgressData', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 743)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_EntityQueries_DataObjects] on table [SCore].[EntityQueries]')
GO
ALTER TABLE [SCore].[EntityQueries] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityQueries_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_EntityQueries_DataObjects] on table [SCore].[EntityQueries]')
GO
ALTER TABLE [SCore].[EntityQueries]
  NOCHECK CONSTRAINT [FK_EntityQueries_DataObjects]
GO

PRINT (N'Create foreign key [FK_EntityQueries_EntityHoBTs] on table [SCore].[EntityQueries]')
GO
ALTER TABLE [SCore].[EntityQueries] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityQueries_EntityHoBTs] FOREIGN KEY ([EntityHoBTID]) REFERENCES [SCore].[EntityHobts] ([ID])
GO

PRINT (N'Create foreign key [FK_EntityQueries_EntityTypes] on table [SCore].[EntityQueries]')
GO
ALTER TABLE [SCore].[EntityQueries] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityQueries_EntityTypes] FOREIGN KEY ([EntityTypeID]) REFERENCES [SCore].[EntityTypes] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_EntityQueries_RowStatus] on table [SCore].[EntityQueries]')
GO
ALTER TABLE [SCore].[EntityQueries] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityQueries_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Add extended property [MS_Description] on table [SCore].[EntityQueries]')
GO
EXEC sys.sp_addextendedproperty N'MS_Description', N'The queries to run in SQL to perform different functions on this Entity Type e.g. Create Read Update Delete Validate', 'SCHEMA', N'SCore', 'TABLE', N'EntityQueries'
GO