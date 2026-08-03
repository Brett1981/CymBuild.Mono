PRINT (N'Create table [SCore].[DataObjectTransition]')
GO
PRINT (N'Create table [SCore].[DataObjectTransition]')
GO
PRINT (N'Create table [SCore].[DataObjectTransition]')
GO
CREATE TABLE [SCore].[DataObjectTransition] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_DataObjectTransition_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [StatusID] [int] NOT NULL CONSTRAINT [DF_DataObjectTransition_StatusID] DEFAULT (-1),
  [OldStatusID] [int] NULL,
  [Comment] [nvarchar](max) NULL,
  [DateTimeUTC] [datetime2] NOT NULL DEFAULT (sysutcdatetime()),
  [CreatedByUserId] [int] NOT NULL CONSTRAINT [DF_DataObjectTransition_CreatedByUserId] DEFAULT (-1),
  [SurveyorUserId] [int] NULL,
  [DataObjectGuid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_DataObjectTransition_DataObjectGuid] DEFAULT ('00000000-0000-0000-0000-000000000000'),
  [IsImported] [bit] NOT NULL CONSTRAINT [DF_WorkflowTransition_IsImported] DEFAULT (0)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key on table [SCore].[DataObjectTransition]')
GO
ALTER TABLE [SCore].[DataObjectTransition] WITH NOCHECK
  ADD PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key on table [SCore].[DataObjectTransition]')
GO
ALTER TABLE [SCore].[DataObjectTransition] WITH NOCHECK
  ADD UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_DataObjectTransition_Active_DataObjectGuid_ID] on table [SCore].[DataObjectTransition]')
GO
CREATE INDEX [IX_DataObjectTransition_Active_DataObjectGuid_ID]
  ON [SCore].[DataObjectTransition] ([DataObjectGuid], [ID] DESC)
  INCLUDE ([StatusID], [DateTimeUTC], [Comment])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_DataObjectTransition_DataObjectGuid_IdDesc] on table [SCore].[DataObjectTransition]')
GO
CREATE INDEX [IX_DataObjectTransition_DataObjectGuid_IdDesc]
  ON [SCore].[DataObjectTransition] ([DataObjectGuid], [ID] DESC)
  INCLUDE ([RowStatus], [StatusID], [OldStatusID], [DateTimeUTC], [Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_DataObjectTransition_DataObjectGuid_Status_Date] on table [SCore].[DataObjectTransition]')
GO
CREATE INDEX [IX_DataObjectTransition_DataObjectGuid_Status_Date]
  ON [SCore].[DataObjectTransition] ([DataObjectGuid], [StatusID], [DateTimeUTC])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SCore_DataObjectTransition_1286463517] on table [SCore].[DataObjectTransition]')
GO
CREATE INDEX [IX_SCore_DataObjectTransition_1286463517]
  ON [SCore].[DataObjectTransition] ([StatusID])
  INCLUDE ([RowStatus], [DateTimeUTC], [DataObjectGuid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SCore_DataObjectTransition_1776779879] on table [SCore].[DataObjectTransition]')
GO
CREATE INDEX [IX_SCore_DataObjectTransition_1776779879]
  ON [SCore].[DataObjectTransition] ([StatusID])
  INCLUDE ([RowStatus], [DataObjectGuid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SCore_DataObjectTransition_177962981] on table [SCore].[DataObjectTransition]')
GO
CREATE INDEX [IX_SCore_DataObjectTransition_177962981]
  ON [SCore].[DataObjectTransition] ([RowStatus])
  INCLUDE ([StatusID])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SCore_DataObjectTransition_271694617] on table [SCore].[DataObjectTransition]')
GO
CREATE INDEX [IX_SCore_DataObjectTransition_271694617]
  ON [SCore].[DataObjectTransition] ([RowStatus])
  INCLUDE ([OldStatusID])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SCore_DataObjectTransition_876107671] on table [SCore].[DataObjectTransition]')
GO
CREATE INDEX [IX_SCore_DataObjectTransition_876107671]
  ON [SCore].[DataObjectTransition] ([RowStatus], [SurveyorUserId])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SCore_DataObjectTransition_943282583] on table [SCore].[DataObjectTransition]')
GO
CREATE INDEX [IX_SCore_DataObjectTransition_943282583]
  ON [SCore].[DataObjectTransition] ([RowStatus])
  INCLUDE ([CreatedByUserId])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tr_DataObjectTransition_QueueWorkflowNotifications] on table [SCore].[DataObjectTransition]')
GO
CREATE TRIGGER [SCore].[tr_DataObjectTransition_QueueWorkflowNotifications]
ON [SCore].[DataObjectTransition]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TriggerName SYSNAME = N'tr_DataObjectTransition_QueueWorkflowNotifications';

    -- Session escape hatch
    IF (ISNULL(CONVERT(int, SESSION_CONTEXT(N'S_disable_notification_triggers')), 0) = 1)
        RETURN;

    BEGIN TRY

        DECLARE @Eligible TABLE
        (
            TransitionGuid       UNIQUEIDENTIFIER NOT NULL,
            StatusId             INT              NOT NULL,
            DataObjectGuid       UNIQUEIDENTIFIER NOT NULL,
            TransitionRowStatus  INT              NOT NULL,
            SendNotification     BIT              NOT NULL,
            LatestTransitionGuid UNIQUEIDENTIFIER NULL,
            AlreadyQueued        BIT              NOT NULL,
            IsInsert             BIT              NOT NULL,
            StatusChanged        BIT              NOT NULL
        );

        INSERT INTO @Eligible
        (
            TransitionGuid,
            StatusId,
            DataObjectGuid,
            TransitionRowStatus,
            SendNotification,
            LatestTransitionGuid,
            AlreadyQueued,
            IsInsert,
            StatusChanged
        )
        SELECT
            i.Guid,
            i.StatusID,
            i.DataObjectGuid,
            i.RowStatus,
            ISNULL(ws.SendNotification, 0) AS SendNotification,
            latest.LatestGuid,
            CASE WHEN EXISTS (SELECT 1 FROM SCore.WorkflowNotificationQueue q WHERE q.TransitionGuid = i.Guid) THEN 1 ELSE 0 END AS AlreadyQueued,
            CASE WHEN d.Guid IS NULL THEN 1 ELSE 0 END AS IsInsert,
            CASE
                WHEN d.Guid IS NULL THEN 1
                WHEN ISNULL(d.StatusID, -1) <> ISNULL(i.StatusID, -1) THEN 1
                ELSE 0
            END AS StatusChanged
        FROM inserted i
        LEFT JOIN deleted d
            ON d.Guid = i.Guid
        LEFT JOIN SCore.WorkflowStatus ws
            ON ws.ID = i.StatusID
           AND ws.RowStatus NOT IN (0,254)
        OUTER APPLY
        (
            SELECT TOP (1) dot2.Guid AS LatestGuid
            FROM SCore.DataObjectTransition dot2
            WHERE dot2.RowStatus NOT IN (0,254)
              AND dot2.DataObjectGuid = i.DataObjectGuid
            ORDER BY dot2.DateTimeUTC DESC, dot2.ID DESC
        ) latest
        WHERE i.Guid IS NOT NULL;

        -- Only queue when the status is meaningful (SendNotification=1) and it is the latest transition.
        INSERT INTO SCore.WorkflowNotificationQueue (TransitionGuid, StatusId)
        SELECT e.TransitionGuid, e.StatusId
        FROM @Eligible e
        WHERE
            e.TransitionRowStatus NOT IN (0,254)
            AND e.SendNotification = 1
            AND e.LatestTransitionGuid = e.TransitionGuid         -- latest-only
            AND e.AlreadyQueued = 0                               -- idempotent
            AND e.StatusChanged = 1;                              -- catches your "update sets current stage" flow

        -- Diagnostics when nothing queued
        IF @@ROWCOUNT = 0
        BEGIN
            INSERT INTO SCore.WorkflowNotificationQueueErrorLog
            (
                CreatedOnUtc, TriggerName, TransitionGuid, StatusId,
                ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorMessage
            )
            SELECT TOP (5)
                SYSUTCDATETIME(),
                @TriggerName,
                e.TransitionGuid,
                e.StatusId,
                0,0,0,0,NULL,
                CONCAT(
                    N'No queue row inserted. ',
                    N'RowStatus=', e.TransitionRowStatus,
                    N' StatusId=', e.StatusId,
                    N' SendNotification=', CONVERT(nvarchar(5), e.SendNotification),
                    N' IsLatest=', CASE WHEN e.LatestTransitionGuid = e.TransitionGuid THEN N'1' ELSE N'0' END,
                    N' AlreadyQueued=', CASE WHEN e.AlreadyQueued = 1 THEN N'1' ELSE N'0' END,
                    N' IsInsert=', CASE WHEN e.IsInsert = 1 THEN N'1' ELSE N'0' END,
                    N' StatusChanged=', CASE WHEN e.StatusChanged = 1 THEN N'1' ELSE N'0' END,
                    N' LatestGuid=', CONVERT(nvarchar(36), e.LatestTransitionGuid)
                )
            FROM @Eligible e
            ORDER BY e.TransitionGuid DESC;
        END

    END TRY
    BEGIN CATCH
        BEGIN TRY
            INSERT INTO SCore.WorkflowNotificationQueueErrorLog
            (
                CreatedOnUtc, TriggerName, TransitionGuid, StatusId,
                ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorMessage
            )
            SELECT TOP (1)
                SYSUTCDATETIME(),
                @TriggerName,
                i.Guid,
                i.StatusID,
                ERROR_NUMBER(),
                ERROR_SEVERITY(),
                ERROR_STATE(),
                ERROR_LINE(),
                ERROR_PROCEDURE(),
                ERROR_MESSAGE()
            FROM inserted i;
        END TRY
        BEGIN CATCH
            -- swallow
        END CATCH;
        RETURN;
    END CATCH
END;
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tr_DataObjectTransition_EnqueueWorkflowStatusNotification] on table [SCore].[DataObjectTransition]')
GO
CREATE TRIGGER [SCore].[tr_DataObjectTransition_EnqueueWorkflowStatusNotification]
ON [SCore].[DataObjectTransition]
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF (ISNULL(CONVERT(int, SESSION_CONTEXT(N'S_disable_triggers')), 0) = 1)
        RETURN;

    -- Only consider inserted transitions whose To Status has SendNotification=1
    IF NOT EXISTS
    (
        SELECT 1
        FROM inserted i
        JOIN SCore.WorkflowStatus ws
            ON ws.ID = i.StatusID
           AND ws.RowStatus NOT IN (0,254)
        WHERE i.RowStatus NOT IN (0,254)
          AND ISNULL(ws.SendNotification, 0) = 1
    )
        RETURN;

    BEGIN TRY
        DECLARE @TransitionGuid UNIQUEIDENTIFIER;

        DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT i.Guid
            FROM inserted i
            JOIN SCore.WorkflowStatus ws
                ON ws.ID = i.StatusID
               AND ws.RowStatus NOT IN (0,254)
            WHERE i.RowStatus NOT IN (0,254)
              AND i.Guid IS NOT NULL
              AND ISNULL(ws.SendNotification, 0) = 1;

        OPEN cur;
        FETCH NEXT FROM cur INTO @TransitionGuid;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            BEGIN TRY
                EXEC [SCore].[IntegrationOutbox_EnqueueWorkflowStatusNotification]
                    @TransitionGuid = @TransitionGuid;
            END TRY
            BEGIN CATCH
                -- Never block core transition write if notifications fail
            END CATCH;

            FETCH NEXT FROM cur INTO @TransitionGuid;
        END

        CLOSE cur;
        DEALLOCATE cur;
    END TRY
    BEGIN CATCH
        RETURN;
    END CATCH
END;
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_DataObjectTransition_RecordHistory] on table [SCore].[DataObjectTransition]')
GO
CREATE TRIGGER [SCore].[tg_DataObjectTransition_RecordHistory]
   ON  [SCore].[DataObjectTransition]	
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
			@TableName NVARCHAR(250) = N'DataObjectTransition',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Comment]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Comment]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Comment] IS DISTINCT FROM i.[Comment])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Comment', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2272)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CreatedByUserId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CreatedByUserId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CreatedByUserId] IS DISTINCT FROM i.[CreatedByUserId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CreatedByUserId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2274)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DataObjectGuid]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DataObjectGuid]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DataObjectGuid] IS DISTINCT FROM i.[DataObjectGuid])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DataObjectGuid', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2323)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DateTimeUTC]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DateTimeUTC]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DateTimeUTC] IS DISTINCT FROM i.[DateTimeUTC])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DateTimeUTC', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2273)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsImported]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsImported]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsImported] IS DISTINCT FROM i.[IsImported])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsImported', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2322)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[OldStatusID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[OldStatusID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[OldStatusID] IS DISTINCT FROM i.[OldStatusID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'OldStatusID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2270)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2266)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[StatusID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[StatusID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[StatusID] IS DISTINCT FROM i.[StatusID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'StatusID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2269)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SurveyorUserId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SurveyorUserId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SurveyorUserId] IS DISTINCT FROM i.[SurveyorUserId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SurveyorUserId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2275)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_DataObjectTransition_CreatedBy] on table [SCore].[DataObjectTransition]')
GO
ALTER TABLE [SCore].[DataObjectTransition] WITH NOCHECK
  ADD CONSTRAINT [FK_DataObjectTransition_CreatedBy] FOREIGN KEY ([CreatedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_DataObjectTransition_DataObjects] on table [SCore].[DataObjectTransition]')
GO
ALTER TABLE [SCore].[DataObjectTransition] WITH NOCHECK
  ADD CONSTRAINT [FK_DataObjectTransition_DataObjects] FOREIGN KEY ([DataObjectGuid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_DataObjectTransition_DataObjects] on table [SCore].[DataObjectTransition]')
GO
ALTER TABLE [SCore].[DataObjectTransition]
  NOCHECK CONSTRAINT [FK_DataObjectTransition_DataObjects]
GO

PRINT (N'Create foreign key [FK_DataObjectTransition_OldStatus] on table [SCore].[DataObjectTransition]')
GO
ALTER TABLE [SCore].[DataObjectTransition] WITH NOCHECK
  ADD CONSTRAINT [FK_DataObjectTransition_OldStatus] FOREIGN KEY ([OldStatusID]) REFERENCES [SCore].[WorkflowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_DataObjectTransition_Status] on table [SCore].[DataObjectTransition]')
GO
ALTER TABLE [SCore].[DataObjectTransition] WITH NOCHECK
  ADD CONSTRAINT [FK_DataObjectTransition_Status] FOREIGN KEY ([StatusID]) REFERENCES [SCore].[WorkflowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_DataObjectTransition_Surveyor] on table [SCore].[DataObjectTransition]')
GO
ALTER TABLE [SCore].[DataObjectTransition] WITH NOCHECK
  ADD CONSTRAINT [FK_DataObjectTransition_Surveyor] FOREIGN KEY ([SurveyorUserId]) REFERENCES [SCore].[Identities] ([ID])
GO