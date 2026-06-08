PRINT (N'Create table [SJob].[JobTypeMilestoneTemplates]')
GO
CREATE TABLE [SJob].[JobTypeMilestoneTemplates] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_JobTypeMilestoneTemplates_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_JobTypeMilestoneTemplates_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobTypeID] [int] NOT NULL CONSTRAINT [DF_JobTypeMilestoneTemplates_JobTypeID] DEFAULT (-1),
  [MilestoneTypeID] [int] NOT NULL CONSTRAINT [DF_JobTypeMilestoneTemplates_MilestoneTypeID] DEFAULT (-1),
  [Description] [nvarchar](500) NOT NULL CONSTRAINT [DF_JobTypeMilestoneTemplates_Description] DEFAULT (''),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF_JobTypeMilestoneTemplates_SortOrder] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_JobTypeMilestoneTemplates] on table [SJob].[JobTypeMilestoneTemplates]')
GO
ALTER TABLE [SJob].[JobTypeMilestoneTemplates] WITH NOCHECK
  ADD CONSTRAINT [PK_JobTypeMilestoneTemplates] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_JobTypeMilestoneTemplates_JobType_MilestoneType] on table [SJob].[JobTypeMilestoneTemplates]')
GO
CREATE INDEX [IX_JobTypeMilestoneTemplates_JobType_MilestoneType]
  ON [SJob].[JobTypeMilestoneTemplates] ([JobTypeID], [MilestoneTypeID], [SortOrder])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_JobTypeMilestoneTemplates_Guid] on table [SJob].[JobTypeMilestoneTemplates]')
GO
CREATE UNIQUE INDEX [IX_UQ_JobTypeMilestoneTemplates_Guid]
  ON [SJob].[JobTypeMilestoneTemplates] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_JobTypeMilestoneTemplates_RecordHistory] on table [SJob].[JobTypeMilestoneTemplates]')
GO
CREATE TRIGGER [SJob].[tg_JobTypeMilestoneTemplates_RecordHistory]
   ON  [SJob].[JobTypeMilestoneTemplates]	
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
			@SchemaName NVARCHAR(250) = N'SJob',
			@TableName NVARCHAR(250) = N'JobTypeMilestoneTemplates',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Description]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Description]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Description] IS DISTINCT FROM i.[Description])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Description', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 926)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[JobTypeID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[JobTypeID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[JobTypeID] IS DISTINCT FROM i.[JobTypeID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'JobTypeID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 929)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[MilestoneTypeID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[MilestoneTypeID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[MilestoneTypeID] IS DISTINCT FROM i.[MilestoneTypeID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'MilestoneTypeID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 930)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 931)
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
				VALUES(1, @SchemaName, @TableName, N'SortOrder', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 933)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_JobTypeMilestoneTemplates_DataObjects] on table [SJob].[JobTypeMilestoneTemplates]')
GO
ALTER TABLE [SJob].[JobTypeMilestoneTemplates] WITH NOCHECK
  ADD CONSTRAINT [FK_JobTypeMilestoneTemplates_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_JobTypeMilestoneTemplates_DataObjects] on table [SJob].[JobTypeMilestoneTemplates]')
GO
ALTER TABLE [SJob].[JobTypeMilestoneTemplates]
  NOCHECK CONSTRAINT [FK_JobTypeMilestoneTemplates_DataObjects]
GO

PRINT (N'Create foreign key [FK_JobTypeMilestoneTemplates_JobTypes] on table [SJob].[JobTypeMilestoneTemplates]')
GO
ALTER TABLE [SJob].[JobTypeMilestoneTemplates] WITH NOCHECK
  ADD CONSTRAINT [FK_JobTypeMilestoneTemplates_JobTypes] FOREIGN KEY ([JobTypeID]) REFERENCES [SJob].[JobTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_JobTypeMilestoneTemplates_MilestoneTypes] on table [SJob].[JobTypeMilestoneTemplates]')
GO
ALTER TABLE [SJob].[JobTypeMilestoneTemplates] WITH NOCHECK
  ADD CONSTRAINT [FK_JobTypeMilestoneTemplates_MilestoneTypes] FOREIGN KEY ([MilestoneTypeID]) REFERENCES [SJob].[MilestoneTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_JobTypeMilestoneTemplates_RowStatus] on table [SJob].[JobTypeMilestoneTemplates]')
GO
ALTER TABLE [SJob].[JobTypeMilestoneTemplates] WITH NOCHECK
  ADD CONSTRAINT [FK_JobTypeMilestoneTemplates_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO