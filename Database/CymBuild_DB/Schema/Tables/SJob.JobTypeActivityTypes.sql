PRINT (N'Create table [SJob].[JobTypeActivityTypes]')
GO
CREATE TABLE [SJob].[JobTypeActivityTypes] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_JobTypeActivityTypes_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_JobTypeActivityTypes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobTypeID] [int] NOT NULL CONSTRAINT [DF_JobTypeActivityTypes_JobTypeID] DEFAULT (-1),
  [ActivityTypeID] [int] NOT NULL CONSTRAINT [DF_JobTypeActivityTypes_ActivityTypeID] DEFAULT (-1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_JobTypeActivityTypes] on table [SJob].[JobTypeActivityTypes]')
GO
ALTER TABLE [SJob].[JobTypeActivityTypes] WITH NOCHECK
  ADD CONSTRAINT [PK_JobTypeActivityTypes] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_JobTypeActivityTypes] on table [SJob].[JobTypeActivityTypes]')
GO
CREATE UNIQUE INDEX [IX_UQ_JobTypeActivityTypes]
  ON [SJob].[JobTypeActivityTypes] ([JobTypeID], [ActivityTypeID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_JobTypeActivityTypes_Guid] on table [SJob].[JobTypeActivityTypes]')
GO
CREATE UNIQUE INDEX [IX_UQ_JobTypeActivityTypes_Guid]
  ON [SJob].[JobTypeActivityTypes] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_JobTypeActivityTypes_RecordHistory] on table [SJob].[JobTypeActivityTypes]')
GO
CREATE TRIGGER [SJob].[tg_JobTypeActivityTypes_RecordHistory]
   ON  [SJob].[JobTypeActivityTypes]	
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
			@TableName NVARCHAR(250) = N'JobTypeActivityTypes',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ActivityTypeID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ActivityTypeID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ActivityTypeID] IS DISTINCT FROM i.[ActivityTypeID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ActivityTypeID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 941)
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
				VALUES(1, @SchemaName, @TableName, N'JobTypeID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 944)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 945)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_JobTypeActivityTypes_ActivityTypes] on table [SJob].[JobTypeActivityTypes]')
GO
ALTER TABLE [SJob].[JobTypeActivityTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_JobTypeActivityTypes_ActivityTypes] FOREIGN KEY ([ActivityTypeID]) REFERENCES [SJob].[ActivityTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_JobTypeActivityTypes_DataObjects] on table [SJob].[JobTypeActivityTypes]')
GO
ALTER TABLE [SJob].[JobTypeActivityTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_JobTypeActivityTypes_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_JobTypeActivityTypes_DataObjects] on table [SJob].[JobTypeActivityTypes]')
GO
ALTER TABLE [SJob].[JobTypeActivityTypes]
  NOCHECK CONSTRAINT [FK_JobTypeActivityTypes_DataObjects]
GO

PRINT (N'Create foreign key [FK_JobTypeActivityTypes_JobTypes] on table [SJob].[JobTypeActivityTypes]')
GO
ALTER TABLE [SJob].[JobTypeActivityTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_JobTypeActivityTypes_JobTypes] FOREIGN KEY ([JobTypeID]) REFERENCES [SJob].[JobTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_JobTypeActivityTypes_RowStatus] on table [SJob].[JobTypeActivityTypes]')
GO
ALTER TABLE [SJob].[JobTypeActivityTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_JobTypeActivityTypes_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO