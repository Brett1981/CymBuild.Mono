PRINT (N'Create table [SJob].[Activities]')
GO
PRINT (N'Create table [SJob].[Activities]')
GO
CREATE TABLE [SJob].[Activities] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_Activity_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_Activity_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobID] [int] NOT NULL CONSTRAINT [DEFAULT_Activity_JobID] DEFAULT (-1),
  [MilestoneID] [bigint] NOT NULL CONSTRAINT [DF_Activity_MilestoneID] DEFAULT (-1),
  [SurveyorID] [int] NOT NULL CONSTRAINT [DEFAULT_Activity_SurveyorID] DEFAULT (-1),
  [Date] [datetime2] NOT NULL CONSTRAINT [DEFAULT_Activity_Date] DEFAULT (getdate()),
  [EndDate] [datetime2] NOT NULL CONSTRAINT [DEFAULT_Activity_EndDate] DEFAULT (getdate()),
  [ActivityTypeID] [int] NOT NULL CONSTRAINT [DEFAULT_Activity_ActivityTypeID] DEFAULT (-1),
  [ActivityStatusID] [int] NOT NULL CONSTRAINT [DEFAULT_Activity_ActivityStatusID] DEFAULT (-1),
  [Title] [nvarchar](250) NOT NULL CONSTRAINT [DEFAULT_Activity_Title] DEFAULT (''),
  [Notes] [nvarchar](max) NOT NULL CONSTRAINT [DEFAULT_Activity_Notes] DEFAULT (''),
  [CreatedByUserID] [int] NOT NULL CONSTRAINT [DEFAULT_Activity_CreatedByUserID] DEFAULT (-1),
  [LastUpdatedByUserID] [int] NOT NULL CONSTRAINT [DEFAULT_Activity_LastUpdatedByUserID] DEFAULT (-1),
  [VersionID] [int] NOT NULL CONSTRAINT [DEFAULT_Activity_VersionID] DEFAULT (-1),
  [InvoicingQuantity] [decimal](19, 2) NOT NULL CONSTRAINT [DEFAULT_Activity_InvoicingQuantity] DEFAULT (0),
  [LegacyID] [bigint] NULL,
  [ExchangeId] [nvarchar](500) NOT NULL CONSTRAINT [DF_Activities_ExchangeId] DEFAULT (''),
  [IsAdditionalWork] [bit] NOT NULL CONSTRAINT [DF_Activities_IsAdditionalWork] DEFAULT (0),
  [RibaStageId] [int] NOT NULL CONSTRAINT [DF_Activities_RibaStageId] DEFAULT (-1),
  [InvoicingValue] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Activities_InvoicingValue] DEFAULT (0),
  [LegacySystemID] [int] NOT NULL DEFAULT (-1),
  [NewExpiryDate] [datetime] NULL CONSTRAINT [DF_Activities_NewExpiryDate] DEFAULT (NULL),
  [CompletedDateTimeUTC] [datetime2] NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Activity] on table [SJob].[Activities]')
GO
ALTER TABLE [SJob].[Activities] WITH NOCHECK
  ADD CONSTRAINT [PK_Activity] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_Activities__RowStatus] on table [SJob].[Activities]')
GO
CREATE INDEX [IX_Activities__RowStatus]
  ON [SJob].[Activities] ([RowStatus])
  INCLUDE ([RowVersion], [Guid], [MilestoneID], [SurveyorID], [Date], [EndDate], [ActivityTypeID], [ActivityStatusID], [Title])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Activities_JobId] on table [SJob].[Activities]')
GO
CREATE INDEX [IX_Activities_JobId]
  ON [SJob].[Activities] ([JobID], [RowStatus], [Date] DESC)
  INCLUDE ([ActivityStatusID], [ActivityTypeID], [EndDate])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Activities_Stage] on table [SJob].[Activities]')
GO
CREATE INDEX [IX_Activities_Stage]
  ON [SJob].[Activities] ([RibaStageId], [RowStatus])
  INCLUDE ([JobID])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Activities_Surveyor] on table [SJob].[Activities]')
GO
CREATE INDEX [IX_Activities_Surveyor]
  ON [SJob].[Activities] ([SurveyorID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_Activities_Guid] on table [SJob].[Activities]')
GO
CREATE UNIQUE INDEX [IX_UQ_Activities_Guid]
  ON [SJob].[Activities] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tr_Activities_InvoiceAutomation_Completion] on table [SJob].[Activities]')
GO
/* =============================================================================
   SJob.tr_Activities_InvoiceAutomation_Completion

   Recommended approach:
   - DO NOT call heavy procs from within the trigger.
   - Instead, enqueue a lightweight “nudge” row into SFin.InvoiceAutomationNudgeQueue.
   - A background worker (or scheduled job) processes the queue and runs:
       SFin.InvoiceScheduleTriggerInstances_Materialise
     (and optionally Phase4–6 runner / consistency sweep).

   This avoids:
   - long-running locks on core tables
   - trigger-induced rollbacks / unexpected latency
   - re-entrancy / deadlocks under load

   Notes:
   - We only enqueue when the row transitions into “complete”, OR becomes “complete + EndDate set”,
     OR CompletedDateTimeUTC becomes set.
   - We keep this trigger non-blocking: any enqueue failure is swallowed.
============================================================================= */

CREATE TRIGGER [SJob].[tr_Activities_InvoiceAutomation_Completion]
ON [SJob].[Activities]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Guard: allow disabling during bulk loads / scripts
    IF (ISNULL(CONVERT(INT, SESSION_CONTEXT(N'S_disable_triggers')), 0) = 1)
        RETURN;

    /* Only proceed if at least one row “became complete” (or got completion timestamp/end date) */
    IF NOT EXISTS
    (
        SELECT 1
        FROM inserted i
        LEFT JOIN deleted d ON d.ID = i.ID
        JOIN SJob.ActivityStatus sNew ON sNew.ID = i.ActivityStatusID
        LEFT JOIN SJob.ActivityStatus sOld ON sOld.ID = d.ActivityStatusID
        WHERE
            i.RowStatus NOT IN (0, 254)
            AND sNew.IsCompleteStatus = 1
            AND
            (
                   ISNULL(sOld.IsCompleteStatus, 0) = 0
                OR (ISNULL(d.EndDate, '19000101') <> ISNULL(i.EndDate, '19000101') AND i.EndDate IS NOT NULL)
                OR (d.CompletedDateTimeUTC IS NULL AND i.CompletedDateTimeUTC IS NOT NULL)
            )
    )
        RETURN;

    BEGIN TRY
        /* Lightweight enqueue: one row per changed Activity ID (deduping left to worker if desired) */
        INSERT INTO SFin.InvoiceAutomationNudgeQueue
        (
              [Source]
            , [EntityId]
            , [EntityGuid]
        )
        SELECT DISTINCT
              [Source]   = N'Activity'
            , [EntityId] = i.ID
            , [EntityGuid] =
                CASE
                    WHEN COL_LENGTH(N'SJob.Activities', N'Guid') IS NOT NULL THEN i.Guid
                    ELSE NULL
                END
        FROM inserted i
        LEFT JOIN deleted d ON d.ID = i.ID
        JOIN SJob.ActivityStatus sNew ON sNew.ID = i.ActivityStatusID
        LEFT JOIN SJob.ActivityStatus sOld ON sOld.ID = d.ActivityStatusID
        WHERE
            i.RowStatus NOT IN (0, 254)
            AND sNew.IsCompleteStatus = 1
            AND
            (
                   ISNULL(sOld.IsCompleteStatus, 0) = 0
                OR (ISNULL(d.EndDate, '19000101') <> ISNULL(i.EndDate, '19000101') AND i.EndDate IS NOT NULL)
                OR (d.CompletedDateTimeUTC IS NULL AND i.CompletedDateTimeUTC IS NOT NULL)
            );
    END TRY
    BEGIN CATCH
        -- Never block the core business update path.
        RETURN;
    END CATCH
END;
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_Activities_RecordHistory] on table [SJob].[Activities]')
GO
CREATE TRIGGER [SJob].[tg_Activities_RecordHistory]
   ON  [SJob].[Activities]	
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
			@TableName NVARCHAR(250) = N'Activities',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ActivityStatusID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ActivityStatusID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ActivityStatusID] IS DISTINCT FROM i.[ActivityStatusID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ActivityStatusID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 299)
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
				VALUES(1, @SchemaName, @TableName, N'ActivityTypeID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 298)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CreatedByUserID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CreatedByUserID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CreatedByUserID] IS DISTINCT FROM i.[CreatedByUserID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CreatedByUserID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 302)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Date]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Date]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Date] IS DISTINCT FROM i.[Date])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Date', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 296)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[EndDate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[EndDate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[EndDate] IS DISTINCT FROM i.[EndDate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EndDate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 297)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ExchangeId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ExchangeId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ExchangeId] IS DISTINCT FROM i.[ExchangeId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ExchangeId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 699)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[InvoicingQuantity]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[InvoicingQuantity]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[InvoicingQuantity] IS DISTINCT FROM i.[InvoicingQuantity])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'InvoicingQuantity', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 700)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[InvoicingValue]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[InvoicingValue]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[InvoicingValue] IS DISTINCT FROM i.[InvoicingValue])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'InvoicingValue', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1686)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsAdditionalWork]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsAdditionalWork]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsAdditionalWork] IS DISTINCT FROM i.[IsAdditionalWork])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsAdditionalWork', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1183)
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
				VALUES(1, @SchemaName, @TableName, N'JobID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 294)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[LastUpdatedByUserID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[LastUpdatedByUserID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[LastUpdatedByUserID] IS DISTINCT FROM i.[LastUpdatedByUserID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'LastUpdatedByUserID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 303)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[LegacyID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[LegacyID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[LegacyID] IS DISTINCT FROM i.[LegacyID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'LegacyID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 701)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[MilestoneID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[MilestoneID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[MilestoneID] IS DISTINCT FROM i.[MilestoneID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'MilestoneID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 702)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[NewExpiryDate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[NewExpiryDate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[NewExpiryDate] IS DISTINCT FROM i.[NewExpiryDate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'NewExpiryDate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2325)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Notes]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Notes]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Notes] IS DISTINCT FROM i.[Notes])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Notes', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 301)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStageId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStageId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStageId] IS DISTINCT FROM i.[RibaStageId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStageId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1184)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 291)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SurveyorID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SurveyorID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SurveyorID] IS DISTINCT FROM i.[SurveyorID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SurveyorID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 295)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Title]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Title]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Title] IS DISTINCT FROM i.[Title])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Title', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 300)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[VersionID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[VersionID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[VersionID] IS DISTINCT FROM i.[VersionID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'VersionID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 304)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_Activities_ActivityStatus] on table [SJob].[Activities]')
GO
ALTER TABLE [SJob].[Activities] WITH NOCHECK
  ADD CONSTRAINT [FK_Activities_ActivityStatus] FOREIGN KEY ([ActivityStatusID]) REFERENCES [SJob].[ActivityStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_Activities_ActivityTypes] on table [SJob].[Activities]')
GO
ALTER TABLE [SJob].[Activities] WITH NOCHECK
  ADD CONSTRAINT [FK_Activities_ActivityTypes] FOREIGN KEY ([ActivityTypeID]) REFERENCES [SJob].[ActivityTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_Activities_DataObjects] on table [SJob].[Activities]')
GO
ALTER TABLE [SJob].[Activities] WITH NOCHECK
  ADD CONSTRAINT [FK_Activities_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid]) ON DELETE CASCADE
GO

PRINT (N'Disable foreign key [FK_Activities_DataObjects] on table [SJob].[Activities]')
GO
ALTER TABLE [SJob].[Activities]
  NOCHECK CONSTRAINT [FK_Activities_DataObjects]
GO

PRINT (N'Create foreign key [FK_Activities_Identities] on table [SJob].[Activities]')
GO
ALTER TABLE [SJob].[Activities] WITH NOCHECK
  ADD CONSTRAINT [FK_Activities_Identities] FOREIGN KEY ([SurveyorID]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Activities_Identities1] on table [SJob].[Activities]')
GO
ALTER TABLE [SJob].[Activities] WITH NOCHECK
  ADD CONSTRAINT [FK_Activities_Identities1] FOREIGN KEY ([CreatedByUserID]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Activities_Identities2] on table [SJob].[Activities]')
GO
ALTER TABLE [SJob].[Activities] WITH NOCHECK
  ADD CONSTRAINT [FK_Activities_Identities2] FOREIGN KEY ([LastUpdatedByUserID]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Activities_Jobs] on table [SJob].[Activities]')
GO
ALTER TABLE [SJob].[Activities] WITH NOCHECK
  ADD CONSTRAINT [FK_Activities_Jobs] FOREIGN KEY ([JobID]) REFERENCES [SJob].[Jobs] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_Activities_Milestones] on table [SJob].[Activities]')
GO
ALTER TABLE [SJob].[Activities] WITH NOCHECK
  ADD CONSTRAINT [FK_Activities_Milestones] FOREIGN KEY ([MilestoneID]) REFERENCES [SJob].[Milestones] ([ID])
GO

PRINT (N'Create foreign key [FK_Activities_RibaStages] on table [SJob].[Activities]')
GO
ALTER TABLE [SJob].[Activities] WITH NOCHECK
  ADD CONSTRAINT [FK_Activities_RibaStages] FOREIGN KEY ([RibaStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_Activities_RowStatus] on table [SJob].[Activities]')
GO
ALTER TABLE [SJob].[Activities] WITH NOCHECK
  ADD CONSTRAINT [FK_Activities_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO