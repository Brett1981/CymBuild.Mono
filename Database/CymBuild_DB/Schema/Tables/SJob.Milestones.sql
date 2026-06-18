SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create table [SJob].[Milestones]')
GO
CREATE TABLE [SJob].[Milestones] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Milestones_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Milestones_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobID] [int] NOT NULL CONSTRAINT [DF_Milestones_JobID] DEFAULT (-1),
  [QuoteLineID] [int] NOT NULL CONSTRAINT [DF_Milestones_QuoteID] DEFAULT (-1),
  [MilestoneTypeID] [int] NOT NULL CONSTRAINT [DF_Milestones_MilestoneTypeID] DEFAULT (-1),
  [Description] [nvarchar](500) NOT NULL CONSTRAINT [DF_Milestones_Description] DEFAULT (''),
  [StartDateTimeUTC] [datetime2] NULL,
  [DueDateTimeUTC] [datetime2] NULL,
  [ScheduledDateTimeUTC] [datetime2] NULL,
  [CompletedDateTimeUTC] [datetime2] NULL,
  [QuotedHours] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Milestones_QuotedHours] DEFAULT (0),
  [EstimatedRemainingHours] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Milestones_EstimatedRemainingHours] DEFAULT (0),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF_Milestones_SortOrder] DEFAULT (0),
  [StartedByUserId] [int] NOT NULL CONSTRAINT [DF_Milestones_StartedByUserId] DEFAULT (-1),
  [CompletedByUserId] [int] NOT NULL CONSTRAINT [DF_Milestones_CompletedByUserId] DEFAULT (-1),
  [IsNotApplicable] [bit] NOT NULL CONSTRAINT [DF_Milestones_IsNotApplicable] DEFAULT (0),
  [ReviewedDateTimeUTC] [datetime2] NULL,
  [ReviewerUserId] [int] NOT NULL CONSTRAINT [DF_Milestones_ReviewerUserId] DEFAULT (-1),
  [Reference] [nvarchar](250) NOT NULL CONSTRAINT [DF_Milestones_Reference] DEFAULT (''),
  [IsComplete] AS (case when [CompletedDateTimeUTC] IS NOT NULL OR [IsNotApplicable]=(1) then (1) else (0) end) PERSISTED NOT NULL,
  [SubmittedDateTimeUTC] [datetime2] NULL,
  [SubmittedBy] [int] NOT NULL CONSTRAINT [DF_Milestones_SubmittedBy] DEFAULT (-1),
  [SubmissionExpiryDate] [datetime2] NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Milestones] on table [SJob].[Milestones]')
GO
ALTER TABLE [SJob].[Milestones] WITH NOCHECK
  ADD CONSTRAINT [PK_Milestones] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_JobMilestones] on table [SJob].[Milestones]')
GO
CREATE INDEX [IX_JobMilestones]
  ON [SJob].[Milestones] ([JobID], [SortOrder], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_JobMilestones_Job] on table [SJob].[Milestones]')
GO
CREATE INDEX [IX_JobMilestones_Job]
  ON [SJob].[Milestones] ([JobID], [RowStatus])
  INCLUDE ([MilestoneTypeID])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_JobMilestones_Overdue] on table [SJob].[Milestones]')
GO
CREATE INDEX [IX_JobMilestones_Overdue]
  ON [SJob].[Milestones] ([JobID], [MilestoneTypeID], [DueDateTimeUTC], [ScheduledDateTimeUTC], [IsComplete], [RowStatus])
  WHERE ([Rowstatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_MilestoneMetric] on table [SJob].[Milestones]')
GO
CREATE INDEX [IX_MilestoneMetric]
  ON [SJob].[Milestones] ([JobID], [SortOrder], [CompletedDateTimeUTC], [RowStatus])
  INCLUDE ([Description])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Milestones_Started] on table [SJob].[Milestones]')
GO
CREATE INDEX [IX_Milestones_Started]
  ON [SJob].[Milestones] ([JobID], [MilestoneTypeID], [StartDateTimeUTC], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254) AND [StartDateTimeUTC] IS NOT NULL)
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SJob_Milestones_1388038500] on table [SJob].[Milestones]')
GO
CREATE INDEX [IX_SJob_Milestones_1388038500]
  ON [SJob].[Milestones] ([JobID], [CompletedDateTimeUTC], [IsNotApplicable])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SJob_Milestones_1454006418] on table [SJob].[Milestones]')
GO
CREATE INDEX [IX_SJob_Milestones_1454006418]
  ON [SJob].[Milestones] ([CompletedDateTimeUTC], [IsNotApplicable])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SJob_Milestones_1659660077] on table [SJob].[Milestones]')
GO
CREATE INDEX [IX_SJob_Milestones_1659660077]
  ON [SJob].[Milestones] ([MilestoneTypeID], [StartDateTimeUTC])
  INCLUDE ([RowStatus], [JobID], [DueDateTimeUTC], [ScheduledDateTimeUTC], [Reference])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SJob_Milestones_1668773423] on table [SJob].[Milestones]')
GO
CREATE INDEX [IX_SJob_Milestones_1668773423]
  ON [SJob].[Milestones] ([RowStatus], [StartDateTimeUTC])
  INCLUDE ([JobID], [MilestoneTypeID], [DueDateTimeUTC], [ScheduledDateTimeUTC], [Reference])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SJob_Milestones_1849322190] on table [SJob].[Milestones]')
GO
CREATE INDEX [IX_SJob_Milestones_1849322190]
  ON [SJob].[Milestones] ([MilestoneTypeID], [CompletedDateTimeUTC], [IsNotApplicable])
  INCLUDE ([JobID])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SJob_Milestones_4793954] on table [SJob].[Milestones]')
GO
CREATE INDEX [IX_SJob_Milestones_4793954]
  ON [SJob].[Milestones] ([MilestoneTypeID])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SJob_Milestones_543889385] on table [SJob].[Milestones]')
GO
CREATE INDEX [IX_SJob_Milestones_543889385]
  ON [SJob].[Milestones] ([CompletedDateTimeUTC], [IsNotApplicable], [RowStatus], [SubmissionExpiryDate])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_Milestones_Guid] on table [SJob].[Milestones]')
GO
CREATE UNIQUE INDEX [IX_UQ_Milestones_Guid]
  ON [SJob].[Milestones] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_Milestones_RecordHistory] on table [SJob].[Milestones]')
GO
CREATE TRIGGER [SJob].[tg_Milestones_RecordHistory]
   ON  [SJob].[Milestones]	
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
			@TableName NVARCHAR(250) = N'Milestones',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CompletedByUserId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CompletedByUserId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CompletedByUserId] IS DISTINCT FROM i.[CompletedByUserId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CompletedByUserId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 460)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CompletedDateTimeUTC]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CompletedDateTimeUTC]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CompletedDateTimeUTC] IS DISTINCT FROM i.[CompletedDateTimeUTC])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CompletedDateTimeUTC', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 455)
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
				VALUES(1, @SchemaName, @TableName, N'Description', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 451)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DueDateTimeUTC]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DueDateTimeUTC]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DueDateTimeUTC] IS DISTINCT FROM i.[DueDateTimeUTC])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DueDateTimeUTC', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 453)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[EstimatedRemainingHours]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[EstimatedRemainingHours]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[EstimatedRemainingHours] IS DISTINCT FROM i.[EstimatedRemainingHours])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EstimatedRemainingHours', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 457)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsComplete]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsComplete]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsComplete] IS DISTINCT FROM i.[IsComplete])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsComplete', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1700)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsNotApplicable]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsNotApplicable]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsNotApplicable] IS DISTINCT FROM i.[IsNotApplicable])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsNotApplicable', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 581)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[JobID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[JobID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[JobID] IS DISTINCT FROM i.[JobID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'JobID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 449)
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
				VALUES(1, @SchemaName, @TableName, N'MilestoneTypeID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 582)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[QuotedHours]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[QuotedHours]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[QuotedHours] IS DISTINCT FROM i.[QuotedHours])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'QuotedHours', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 456)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[QuoteLineID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[QuoteLineID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[QuoteLineID] IS DISTINCT FROM i.[QuoteLineID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'QuoteLineID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 450)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Reference]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Reference]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Reference] IS DISTINCT FROM i.[Reference])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Reference', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1145)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ReviewedDateTimeUTC]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ReviewedDateTimeUTC]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ReviewedDateTimeUTC] IS DISTINCT FROM i.[ReviewedDateTimeUTC])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ReviewedDateTimeUTC', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 583)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ReviewerUserId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ReviewerUserId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ReviewerUserId] IS DISTINCT FROM i.[ReviewerUserId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ReviewerUserId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 584)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 446)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ScheduledDateTimeUTC]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ScheduledDateTimeUTC]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ScheduledDateTimeUTC] IS DISTINCT FROM i.[ScheduledDateTimeUTC])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ScheduledDateTimeUTC', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 454)
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
				VALUES(1, @SchemaName, @TableName, N'SortOrder', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 458)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[StartDateTimeUTC]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[StartDateTimeUTC]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[StartDateTimeUTC] IS DISTINCT FROM i.[StartDateTimeUTC])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'StartDateTimeUTC', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 452)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[StartedByUserId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[StartedByUserId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[StartedByUserId] IS DISTINCT FROM i.[StartedByUserId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'StartedByUserId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 459)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SubmissionExpiryDate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SubmissionExpiryDate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SubmissionExpiryDate] IS DISTINCT FROM i.[SubmissionExpiryDate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SubmissionExpiryDate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1701)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SubmittedBy]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SubmittedBy]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SubmittedBy] IS DISTINCT FROM i.[SubmittedBy])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SubmittedBy', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1702)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SubmittedDateTimeUTC]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SubmittedDateTimeUTC]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SubmittedDateTimeUTC] IS DISTINCT FROM i.[SubmittedDateTimeUTC])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SubmittedDateTimeUTC', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1703)
			END 
			
			
			END
		END
		
		
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tr_Milestones_InvoiceAutomation_Completion] on table [SJob].[Milestones]')
GO
/* =============================================================================
   SJob.tr_Milestones_InvoiceAutomation_Completion

   Recommended approach:
   - DO NOT execute materialisation / automation procs inside the trigger.
   - Enqueue a lightweight “nudge” into SFin.InvoiceAutomationNudgeQueue.
   - Background worker processes nudges and runs:
       SFin.InvoiceScheduleTriggerInstances_Materialise
     (and optionally Phase4–6 / consistency sweep).

   This trigger enqueues only when the milestone transitions into a “complete-ish”
   state:
     - INSERT where CompletedDateTimeUTC is set OR IsNotApplicable=1
     - UPDATE where CompletedDateTimeUTC changes from NULL -> NOT NULL
     - UPDATE where IsNotApplicable changes 0 -> 1

   Non-blocking: errors are swallowed.
============================================================================= */

CREATE TRIGGER [SJob].[tr_Milestones_InvoiceAutomation_Completion]
ON [SJob].[Milestones]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Guard: allow disabling during bulk loads / scripts
    IF (ISNULL(CONVERT(INT, SESSION_CONTEXT(N'S_disable_triggers')), 0) = 1)
        RETURN;

    -- Only proceed if at least one row just became "complete" / "N/A"
    IF NOT EXISTS
    (
        SELECT 1
        FROM inserted i
        LEFT JOIN deleted d ON d.ID = i.ID
        WHERE
            i.RowStatus NOT IN (0, 254)
            AND
            (
                -- Insert: already complete or N/A
                (d.ID IS NULL AND (i.CompletedDateTimeUTC IS NOT NULL OR i.IsNotApplicable = 1))

                -- Update: CompletedDateTimeUTC changed from NULL -> NOT NULL
                OR (d.ID IS NOT NULL AND d.CompletedDateTimeUTC IS NULL AND i.CompletedDateTimeUTC IS NOT NULL)

                -- Update: IsNotApplicable changed from 0 -> 1
                OR (d.ID IS NOT NULL AND ISNULL(d.IsNotApplicable, 0) = 0 AND i.IsNotApplicable = 1)
            )
    )
        RETURN;

    BEGIN TRY
        INSERT INTO SFin.InvoiceAutomationNudgeQueue
        (
              [Source]
            , [EntityId]
            , [EntityGuid]
        )
        SELECT DISTINCT
              [Source]   = N'Milestone'
            , [EntityId] = i.ID
            , [EntityGuid] =
                CASE
                    WHEN COL_LENGTH(N'SJob.Milestones', N'Guid') IS NOT NULL THEN i.Guid
                    ELSE NULL
                END
        FROM inserted i
        LEFT JOIN deleted d ON d.ID = i.ID
        WHERE
            i.RowStatus NOT IN (0, 254)
            AND
            (
                (d.ID IS NULL AND (i.CompletedDateTimeUTC IS NOT NULL OR i.IsNotApplicable = 1))
                OR (d.ID IS NOT NULL AND d.CompletedDateTimeUTC IS NULL AND i.CompletedDateTimeUTC IS NOT NULL)
                OR (d.ID IS NOT NULL AND ISNULL(d.IsNotApplicable, 0) = 0 AND i.IsNotApplicable = 1)
            );
    END TRY
    BEGIN CATCH
        -- Never block milestone completion
        RETURN;
    END CATCH
END;
GO

PRINT (N'Create foreign key [FK_Milestones_DataObjects] on table [SJob].[Milestones]')
GO
ALTER TABLE [SJob].[Milestones] WITH NOCHECK
  ADD CONSTRAINT [FK_Milestones_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_Milestones_DataObjects] on table [SJob].[Milestones]')
GO
ALTER TABLE [SJob].[Milestones]
  NOCHECK CONSTRAINT [FK_Milestones_DataObjects]
GO

PRINT (N'Create foreign key [FK_Milestones_Identities] on table [SJob].[Milestones]')
GO
ALTER TABLE [SJob].[Milestones] WITH NOCHECK
  ADD CONSTRAINT [FK_Milestones_Identities] FOREIGN KEY ([StartedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Milestones_Identities1] on table [SJob].[Milestones]')
GO
ALTER TABLE [SJob].[Milestones] WITH NOCHECK
  ADD CONSTRAINT [FK_Milestones_Identities1] FOREIGN KEY ([CompletedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Milestones_Identities2] on table [SJob].[Milestones]')
GO
ALTER TABLE [SJob].[Milestones] WITH NOCHECK
  ADD CONSTRAINT [FK_Milestones_Identities2] FOREIGN KEY ([ReviewerUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Milestones_Jobs] on table [SJob].[Milestones]')
GO
ALTER TABLE [SJob].[Milestones] WITH NOCHECK
  ADD CONSTRAINT [FK_Milestones_Jobs] FOREIGN KEY ([JobID]) REFERENCES [SJob].[Jobs] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_Milestones_MilestoneTypes] on table [SJob].[Milestones]')
GO
ALTER TABLE [SJob].[Milestones] WITH NOCHECK
  ADD CONSTRAINT [FK_Milestones_MilestoneTypes] FOREIGN KEY ([MilestoneTypeID]) REFERENCES [SJob].[MilestoneTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_Milestones_RowStatus] on table [SJob].[Milestones]')
GO
ALTER TABLE [SJob].[Milestones] WITH NOCHECK
  ADD CONSTRAINT [FK_Milestones_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO