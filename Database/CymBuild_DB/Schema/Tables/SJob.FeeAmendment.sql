PRINT (N'Create table [SJob].[FeeAmendment]')
GO
CREATE TABLE [SJob].[FeeAmendment] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_FeeAmendment_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_FeeAmendment_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobID] [int] NOT NULL CONSTRAINT [DEFAULT_FeeAmendment_JobID] DEFAULT (-1),
  [CreatedByUserID] [int] NOT NULL CONSTRAINT [DEFAULT_FeeAmendment_CreatedByUserID] DEFAULT (-1),
  [CreatedDateTime] [datetime2] NOT NULL CONSTRAINT [DF_FeeAmendment_CreatedDateTime] DEFAULT (getutcdate()),
  [RibaStage0Change] [decimal](9, 2) NOT NULL CONSTRAINT [DF_FeeAmendment_RibaStage0Change] DEFAULT (0),
  [RibaStage1Change] [decimal](9, 2) NOT NULL CONSTRAINT [DF_FeeAmendment_RibaStage1Change] DEFAULT (0),
  [RibaStage2Change] [decimal](9, 2) NOT NULL CONSTRAINT [DF_FeeAmendment_RibaStage2Change] DEFAULT (0),
  [RibaStage3Change] [decimal](9, 2) NOT NULL CONSTRAINT [DF_FeeAmendment_RibaStage3Change] DEFAULT (0),
  [RibaStage4Change] [decimal](9, 2) NOT NULL CONSTRAINT [DF_FeeAmendment_RibaStage4Change] DEFAULT (0),
  [RibaStage5Change] [decimal](9, 2) NOT NULL CONSTRAINT [DF_FeeAmendment_RibaStage5Change] DEFAULT (0),
  [RibaStage6Change] [decimal](9, 2) NOT NULL CONSTRAINT [DF_FeeAmendment_RibaStage6Change] DEFAULT (0),
  [RibaStage7Change] [decimal](9, 2) NOT NULL CONSTRAINT [DF_FeeAmendment_RibaStage7Change] DEFAULT (0),
  [FeeCapChange] [decimal](9, 2) NOT NULL CONSTRAINT [DF_FeeAmendment_FeeCapChange] DEFAULT (0),
  [PreConstructionStageChange] [decimal](9, 2) NOT NULL CONSTRAINT [DF_FeeAmendment_PreConstructionStageChange] DEFAULT (0),
  [ConstructionStageChange] [decimal](9, 2) NOT NULL CONSTRAINT [DF_FeeAmendment_ConstructionStageChange] DEFAULT (0),
  [RibaStage0MeetingChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage0VisitChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage1MeetingChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage1VisitChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage2MeetingChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage2VisitChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage3MeetingChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage3VisitChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage4MeetingChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage4VisitChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage5MeetingChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage5VisitChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage6MeetingChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage6VisitChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage7MeetingChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [RibaStage7VisitChange] [decimal](9, 2) NOT NULL DEFAULT (0.00),
  [PreConstructionStageMeetingChange] [decimal](9, 2) NOT NULL DEFAULT (0),
  [PreConstructionStageVisitChange] [decimal](9, 2) NOT NULL DEFAULT (0),
  [ConstructionStageMeetingChange] [decimal](9, 2) NOT NULL DEFAULT (0),
  [ConstructionStageVisitChange] [decimal](9, 2) NOT NULL DEFAULT (0),
  [Reason] [nvarchar](max) NOT NULL CONSTRAINT [DF_FeeAmendment_Reason] DEFAULT (N'')
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_FeeAmendment] on table [SJob].[FeeAmendment]')
GO
ALTER TABLE [SJob].[FeeAmendment] WITH NOCHECK
  ADD CONSTRAINT [PK_FeeAmendment] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [Ix_FeeAmendment_JobId] on table [SJob].[FeeAmendment]')
GO
CREATE INDEX [Ix_FeeAmendment_JobId]
  ON [SJob].[FeeAmendment] ([JobID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_FeeAmendments_Guid] on table [SJob].[FeeAmendment]')
GO
CREATE UNIQUE INDEX [IX_UQ_FeeAmendments_Guid]
  ON [SJob].[FeeAmendment] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_FeeAmendment_RecordHistory] on table [SJob].[FeeAmendment]')
GO
CREATE TRIGGER [SJob].[tg_FeeAmendment_RecordHistory]
   ON  [SJob].[FeeAmendment]	
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
			@TableName NVARCHAR(250) = N'FeeAmendment',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ConstructionStageChange]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ConstructionStageChange]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ConstructionStageChange] IS DISTINCT FROM i.[ConstructionStageChange])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ConstructionStageChange', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1200)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ConstructionStageMeetingChange]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ConstructionStageMeetingChange]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ConstructionStageMeetingChange] IS DISTINCT FROM i.[ConstructionStageMeetingChange])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ConstructionStageMeetingChange', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2026)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ConstructionStageVisitChange]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ConstructionStageVisitChange]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ConstructionStageVisitChange] IS DISTINCT FROM i.[ConstructionStageVisitChange])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ConstructionStageVisitChange', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2027)
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
				VALUES(1, @SchemaName, @TableName, N'CreatedByUserID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1125)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CreatedDateTime]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CreatedDateTime]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CreatedDateTime] IS DISTINCT FROM i.[CreatedDateTime])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CreatedDateTime', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1126)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FeeCapChange]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FeeCapChange]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FeeCapChange] IS DISTINCT FROM i.[FeeCapChange])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FeeCapChange', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1127)
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
				VALUES(1, @SchemaName, @TableName, N'JobID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1130)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PreConstructionStageChange]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PreConstructionStageChange]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PreConstructionStageChange] IS DISTINCT FROM i.[PreConstructionStageChange])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PreConstructionStageChange', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1201)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PreConstructionStageMeetingChange]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PreConstructionStageMeetingChange]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PreConstructionStageMeetingChange] IS DISTINCT FROM i.[PreConstructionStageMeetingChange])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PreConstructionStageMeetingChange', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2024)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PreConstructionStageVisitChange]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PreConstructionStageVisitChange]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PreConstructionStageVisitChange] IS DISTINCT FROM i.[PreConstructionStageVisitChange])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PreConstructionStageVisitChange', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2025)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage0Change]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage0Change]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage0Change] IS DISTINCT FROM i.[RibaStage0Change])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage0Change', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1131)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage0MeetingChange]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage0MeetingChange]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage0MeetingChange] IS DISTINCT FROM i.[RibaStage0MeetingChange])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage0MeetingChange', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2003)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage0VisitChange]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage0VisitChange]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage0VisitChange] IS DISTINCT FROM i.[RibaStage0VisitChange])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage0VisitChange', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2012)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage1Change]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage1Change]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage1Change] IS DISTINCT FROM i.[RibaStage1Change])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage1Change', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1132)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage1MeetingChange]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage1MeetingChange]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage1MeetingChange] IS DISTINCT FROM i.[RibaStage1MeetingChange])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage1MeetingChange', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2004)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage1VisitChange]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage1VisitChange]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage1VisitChange] IS DISTINCT FROM i.[RibaStage1VisitChange])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage1VisitChange', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2014)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage2Change]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage2Change]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage2Change] IS DISTINCT FROM i.[RibaStage2Change])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage2Change', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1133)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage2MeetingChange]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage2MeetingChange]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage2MeetingChange] IS DISTINCT FROM i.[RibaStage2MeetingChange])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage2MeetingChange', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2005)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage2VisitChange]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage2VisitChange]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage2VisitChange] IS DISTINCT FROM i.[RibaStage2VisitChange])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage2VisitChange', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2017)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage3Change]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage3Change]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage3Change] IS DISTINCT FROM i.[RibaStage3Change])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage3Change', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1134)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage3MeetingChange]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage3MeetingChange]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage3MeetingChange] IS DISTINCT FROM i.[RibaStage3MeetingChange])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage3MeetingChange', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2006)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage3VisitChange]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage3VisitChange]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage3VisitChange] IS DISTINCT FROM i.[RibaStage3VisitChange])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage3VisitChange', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2018)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage4Change]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage4Change]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage4Change] IS DISTINCT FROM i.[RibaStage4Change])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage4Change', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1135)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage4MeetingChange]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage4MeetingChange]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage4MeetingChange] IS DISTINCT FROM i.[RibaStage4MeetingChange])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage4MeetingChange', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2008)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage4VisitChange]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage4VisitChange]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage4VisitChange] IS DISTINCT FROM i.[RibaStage4VisitChange])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage4VisitChange', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2019)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage5Change]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage5Change]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage5Change] IS DISTINCT FROM i.[RibaStage5Change])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage5Change', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1136)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage5MeetingChange]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage5MeetingChange]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage5MeetingChange] IS DISTINCT FROM i.[RibaStage5MeetingChange])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage5MeetingChange', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2009)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage5VisitChange]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage5VisitChange]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage5VisitChange] IS DISTINCT FROM i.[RibaStage5VisitChange])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage5VisitChange', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2020)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage6Change]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage6Change]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage6Change] IS DISTINCT FROM i.[RibaStage6Change])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage6Change', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1137)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage6MeetingChange]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage6MeetingChange]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage6MeetingChange] IS DISTINCT FROM i.[RibaStage6MeetingChange])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage6MeetingChange', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2010)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage6VisitChange]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage6VisitChange]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage6VisitChange] IS DISTINCT FROM i.[RibaStage6VisitChange])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage6VisitChange', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2021)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage7Change]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage7Change]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage7Change] IS DISTINCT FROM i.[RibaStage7Change])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage7Change', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1138)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage7MeetingChange]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage7MeetingChange]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage7MeetingChange] IS DISTINCT FROM i.[RibaStage7MeetingChange])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage7MeetingChange', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2011)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage7VisitChange]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage7VisitChange]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage7VisitChange] IS DISTINCT FROM i.[RibaStage7VisitChange])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage7VisitChange', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2022)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1139)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_FeeAmendment_DataObjects] on table [SJob].[FeeAmendment]')
GO
ALTER TABLE [SJob].[FeeAmendment] WITH NOCHECK
  ADD CONSTRAINT [FK_FeeAmendment_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_FeeAmendment_DataObjects] on table [SJob].[FeeAmendment]')
GO
ALTER TABLE [SJob].[FeeAmendment]
  NOCHECK CONSTRAINT [FK_FeeAmendment_DataObjects]
GO

PRINT (N'Create foreign key [FK_FeeAmendment_Identities] on table [SJob].[FeeAmendment]')
GO
ALTER TABLE [SJob].[FeeAmendment] WITH NOCHECK
  ADD CONSTRAINT [FK_FeeAmendment_Identities] FOREIGN KEY ([CreatedByUserID]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_FeeAmendment_Jobs] on table [SJob].[FeeAmendment]')
GO
ALTER TABLE [SJob].[FeeAmendment] WITH NOCHECK
  ADD CONSTRAINT [FK_FeeAmendment_Jobs] FOREIGN KEY ([JobID]) REFERENCES [SJob].[Jobs] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_FeeAmendment_RowStatus] on table [SJob].[FeeAmendment]')
GO
ALTER TABLE [SJob].[FeeAmendment] WITH NOCHECK
  ADD CONSTRAINT [FK_FeeAmendment_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO