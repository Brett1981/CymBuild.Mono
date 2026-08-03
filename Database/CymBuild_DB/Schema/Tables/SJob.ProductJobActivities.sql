PRINT (N'Create table [SJob].[ProductJobActivities]')
GO
PRINT (N'Create table [SJob].[ProductJobActivities]')
GO
CREATE TABLE [SJob].[ProductJobActivities] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_ProductJobActivities_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ProductJobActivities_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [ProductId] [int] NOT NULL CONSTRAINT [DF_ProductJobActivities_ProductId] DEFAULT (-1),
  [JobTypeActivityTypeId] [int] NOT NULL CONSTRAINT [DF_ProductJobActivities_JobTypeActivityTypeId] DEFAULT (-1),
  [ActivityTitle] [nvarchar](250) NOT NULL CONSTRAINT [DF_ProductJobActivities_ActivityTitle] DEFAULT (''),
  [OffsetDays] [int] NOT NULL CONSTRAINT [DF_ProductJobActivities_OffsetDays] DEFAULT (0),
  [OffsetWeeks] [int] NOT NULL CONSTRAINT [DF_ProductJobActivities_OffsetWeeks] DEFAULT (0),
  [OffsetMonths] [int] NOT NULL CONSTRAINT [DF_ProductJobActivities_OffsetMonths] DEFAULT (0),
  [JobTypeMilestoneTemplateId] [int] NOT NULL CONSTRAINT [DF_ProductJobActivities_JobTypeMilestoneTemplateId] DEFAULT (-1),
  [PercentageOfProductValue] [decimal](5, 2) NOT NULL CONSTRAINT [DF_ProductJobActivities_PercentageOfProductValue] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_ProductJobActivities] on table [SJob].[ProductJobActivities]')
GO
ALTER TABLE [SJob].[ProductJobActivities] WITH NOCHECK
  ADD CONSTRAINT [PK_ProductJobActivities] PRIMARY KEY CLUSTERED ([ID])
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_ProductJobActivities_Product] on table [SJob].[ProductJobActivities]')
GO
CREATE INDEX [IX_ProductJobActivities_Product]
  ON [SJob].[ProductJobActivities] ([ProductId], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_ProductJobActivities_Guid] on table [SJob].[ProductJobActivities]')
GO
CREATE UNIQUE INDEX [IX_UQ_ProductJobActivities_Guid]
  ON [SJob].[ProductJobActivities] ([Guid])
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_ProductJobActivities_RecordHistory] on table [SJob].[ProductJobActivities]')
GO
CREATE TRIGGER [SJob].[tg_ProductJobActivities_RecordHistory]
   ON  [SJob].[ProductJobActivities]	
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
			@TableName NVARCHAR(250) = N'ProductJobActivities',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ActivityTitle]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ActivityTitle]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ActivityTitle] IS DISTINCT FROM i.[ActivityTitle])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ActivityTitle', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1651)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[JobTypeActivityTypeId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[JobTypeActivityTypeId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[JobTypeActivityTypeId] IS DISTINCT FROM i.[JobTypeActivityTypeId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'JobTypeActivityTypeId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1650)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[JobTypeMilestoneTemplateId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[JobTypeMilestoneTemplateId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[JobTypeMilestoneTemplateId] IS DISTINCT FROM i.[JobTypeMilestoneTemplateId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'JobTypeMilestoneTemplateId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1655)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[OffsetDays]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[OffsetDays]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[OffsetDays] IS DISTINCT FROM i.[OffsetDays])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'OffsetDays', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1652)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[OffsetMonths]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[OffsetMonths]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[OffsetMonths] IS DISTINCT FROM i.[OffsetMonths])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'OffsetMonths', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1654)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[OffsetWeeks]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[OffsetWeeks]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[OffsetWeeks] IS DISTINCT FROM i.[OffsetWeeks])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'OffsetWeeks', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1653)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PercentageOfProductValue]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PercentageOfProductValue]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PercentageOfProductValue] IS DISTINCT FROM i.[PercentageOfProductValue])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PercentageOfProductValue', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1656)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ProductId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ProductId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ProductId] IS DISTINCT FROM i.[ProductId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ProductId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1649)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1646)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_ProductJobActivities_DataObjects] on table [SJob].[ProductJobActivities]')
GO
ALTER TABLE [SJob].[ProductJobActivities] WITH NOCHECK
  ADD CONSTRAINT [FK_ProductJobActivities_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_ProductJobActivities_DataObjects] on table [SJob].[ProductJobActivities]')
GO
ALTER TABLE [SJob].[ProductJobActivities]
  NOCHECK CONSTRAINT [FK_ProductJobActivities_DataObjects]
GO

PRINT (N'Create foreign key [FK_ProductJobActivities_JobTypeActivityTypes] on table [SJob].[ProductJobActivities]')
GO
ALTER TABLE [SJob].[ProductJobActivities] WITH NOCHECK
  ADD CONSTRAINT [FK_ProductJobActivities_JobTypeActivityTypes] FOREIGN KEY ([JobTypeActivityTypeId]) REFERENCES [SJob].[JobTypeActivityTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_ProductJobActivities_JobTypeMilestoneTemplates] on table [SJob].[ProductJobActivities]')
GO
ALTER TABLE [SJob].[ProductJobActivities] WITH NOCHECK
  ADD CONSTRAINT [FK_ProductJobActivities_JobTypeMilestoneTemplates] FOREIGN KEY ([JobTypeMilestoneTemplateId]) REFERENCES [SJob].[JobTypeMilestoneTemplates] ([ID])
GO

PRINT (N'Create foreign key [FK_ProductJobActivities_RowStatus] on table [SJob].[ProductJobActivities]')
GO
ALTER TABLE [SJob].[ProductJobActivities] WITH NOCHECK
  ADD CONSTRAINT [FK_ProductJobActivities_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO