PRINT (N'Create table [SCore].[WorkflowStatusNotificationGroups]')
GO
PRINT (N'Create table [SCore].[WorkflowStatusNotificationGroups]')
GO
CREATE TABLE [SCore].[WorkflowStatusNotificationGroups] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_WorkflowStatusNotificationGroups_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_WorkflowStatusNotificationGroups_Guid] DEFAULT (newid()),
  [WorkflowID] [int] NOT NULL CONSTRAINT [DF_WorkflowStatusNotificationGroups_WorkflowID] DEFAULT (-1),
  [WorkflowStatusGuid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_WorkflowStatusNotificationGroups_WorkflowStatusGuid] DEFAULT (newid()),
  [GroupID] [int] NOT NULL CONSTRAINT [DF_WorkflowStatusNotificationGroups_GroupID] DEFAULT (-1),
  [CanAction] [bit] NOT NULL CONSTRAINT [DF_WorkflowStatusNotificationGroups_CanAction] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_WorkflowStatusNotificationGroups] on table [SCore].[WorkflowStatusNotificationGroups]')
GO
ALTER TABLE [SCore].[WorkflowStatusNotificationGroups] WITH NOCHECK
  ADD CONSTRAINT [PK_WorkflowStatusNotificationGroups] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_WorkflowStatusNotificationGroups_Lookup] on table [SCore].[WorkflowStatusNotificationGroups]')
GO
CREATE INDEX [IX_WorkflowStatusNotificationGroups_Lookup]
  ON [SCore].[WorkflowStatusNotificationGroups] ([RowStatus], [WorkflowID], [WorkflowStatusGuid])
  INCLUDE ([GroupID], [CanAction])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_WorkflowStatusNotificationGroups_Workflow_Status] on table [SCore].[WorkflowStatusNotificationGroups]')
GO
CREATE INDEX [IX_WorkflowStatusNotificationGroups_Workflow_Status]
  ON [SCore].[WorkflowStatusNotificationGroups] ([WorkflowID], [WorkflowStatusGuid])
  INCLUDE ([GroupID], [CanAction])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [UX_WorkflowStatusNotificationGroups_Workflow_Status_Group] on table [SCore].[WorkflowStatusNotificationGroups]')
GO
CREATE UNIQUE INDEX [UX_WorkflowStatusNotificationGroups_Workflow_Status_Group]
  ON [SCore].[WorkflowStatusNotificationGroups] ([WorkflowID], [WorkflowStatusGuid], [GroupID])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_WorkflowStatusNotificationGroups_RecordHistory] on table [SCore].[WorkflowStatusNotificationGroups]')
GO
CREATE TRIGGER [SCore].[tg_WorkflowStatusNotificationGroups_RecordHistory]
   ON  [SCore].[WorkflowStatusNotificationGroups]	
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
			@SchemaName NVARCHAR(250) = N'SCore',
			@TableName NVARCHAR(250) = N'WorkflowStatusNotificationGroups',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CanAction]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CanAction]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CanAction] IS DISTINCT FROM i.[CanAction])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CanAction', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2524)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[GroupID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[GroupID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[GroupID] IS DISTINCT FROM i.[GroupID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'GroupID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2529)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2525)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[WorkflowID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[WorkflowID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[WorkflowID] IS DISTINCT FROM i.[WorkflowID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'WorkflowID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2526)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[WorkflowStatusGuid]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[WorkflowStatusGuid]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[WorkflowStatusGuid] IS DISTINCT FROM i.[WorkflowStatusGuid])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'WorkflowStatusGuid', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2528)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_WFStatusNotificationGroups_Groups] on table [SCore].[WorkflowStatusNotificationGroups]')
GO
ALTER TABLE [SCore].[WorkflowStatusNotificationGroups] WITH NOCHECK
  ADD CONSTRAINT [FK_WFStatusNotificationGroups_Groups] FOREIGN KEY ([GroupID]) REFERENCES [SCore].[Groups] ([ID])
GO

PRINT (N'Create foreign key [FK_WFStatusNotificationGroups_Workflow] on table [SCore].[WorkflowStatusNotificationGroups]')
GO
ALTER TABLE [SCore].[WorkflowStatusNotificationGroups] WITH NOCHECK
  ADD CONSTRAINT [FK_WFStatusNotificationGroups_Workflow] FOREIGN KEY ([WorkflowID]) REFERENCES [SCore].[Workflow] ([ID])
GO