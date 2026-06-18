PRINT (N'Create table [SSop].[EnquiryServices]')
GO
PRINT (N'Create table [SSop].[EnquiryServices]')
GO
CREATE TABLE [SSop].[EnquiryServices] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_EnquiryServices_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_EnquiryServices_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [EnquiryId] [int] NOT NULL CONSTRAINT [DF_EnquiryServices_EnquiryId] DEFAULT (-1),
  [JobTypeId] [int] NOT NULL CONSTRAINT [DF_EnquiryServices_JobTypeId] DEFAULT (-1),
  [StartRibaStageId] [int] NOT NULL CONSTRAINT [DF_EnquiryServices_StartRibaStageId] DEFAULT (-1),
  [EndRibaStageId] [int] NOT NULL CONSTRAINT [DF_EnquiryServices_EndRibaStageId] DEFAULT (-1),
  [QuoteId] [int] NOT NULL CONSTRAINT [DF_EnquiryServices_QuoteId] DEFAULT (-1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_EnquiryServices] on table [SSop].[EnquiryServices]')
GO
ALTER TABLE [SSop].[EnquiryServices] WITH NOCHECK
  ADD CONSTRAINT [PK_EnquiryServices] PRIMARY KEY CLUSTERED ([ID])
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_EnquiryService_JobTypeId] on table [SSop].[EnquiryServices]')
GO
CREATE INDEX [IX_EnquiryService_JobTypeId]
  ON [SSop].[EnquiryServices] ([JobTypeId], [EnquiryId], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_EnquiryServices_Enquiry] on table [SSop].[EnquiryServices]')
GO
CREATE INDEX [IX_EnquiryServices_Enquiry]
  ON [SSop].[EnquiryServices] ([EnquiryId], [RowStatus])
  INCLUDE ([Guid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_EnquiryServices_EnquiryId_RowStatus_JobType] on table [SSop].[EnquiryServices]')
GO
CREATE INDEX [IX_EnquiryServices_EnquiryId_RowStatus_JobType]
  ON [SSop].[EnquiryServices] ([EnquiryId], [RowStatus], [JobTypeId])
  INCLUDE ([ID])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_EnquiryServices_Guid] on table [SSop].[EnquiryServices]')
GO
CREATE UNIQUE INDEX [IX_UQ_EnquiryServices_Guid]
  ON [SSop].[EnquiryServices] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_EnquiryServices_RecordHistory] on table [SSop].[EnquiryServices]')
GO
CREATE TRIGGER [SSop].[tg_EnquiryServices_RecordHistory]
   ON  [SSop].[EnquiryServices]	
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
			@SchemaName NVARCHAR(250) = N'SSop',
			@TableName NVARCHAR(250) = N'EnquiryServices',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[EndRibaStageId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[EndRibaStageId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[EndRibaStageId] IS DISTINCT FROM i.[EndRibaStageId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EndRibaStageId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1015)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[EnquiryId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[EnquiryId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[EnquiryId] IS DISTINCT FROM i.[EnquiryId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EnquiryId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1016)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[JobTypeId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[JobTypeId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[JobTypeId] IS DISTINCT FROM i.[JobTypeId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'JobTypeId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1019)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1020)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[StartRibaStageId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[StartRibaStageId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[StartRibaStageId] IS DISTINCT FROM i.[StartRibaStageId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'StartRibaStageId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1022)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_EnquiryServices_DataObjects] on table [SSop].[EnquiryServices]')
GO
ALTER TABLE [SSop].[EnquiryServices] WITH NOCHECK
  ADD CONSTRAINT [FK_EnquiryServices_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_EnquiryServices_DataObjects] on table [SSop].[EnquiryServices]')
GO
ALTER TABLE [SSop].[EnquiryServices]
  NOCHECK CONSTRAINT [FK_EnquiryServices_DataObjects]
GO

PRINT (N'Create foreign key [FK_EnquiryServices_Enquiries] on table [SSop].[EnquiryServices]')
GO
ALTER TABLE [SSop].[EnquiryServices] WITH NOCHECK
  ADD CONSTRAINT [FK_EnquiryServices_Enquiries] FOREIGN KEY ([EnquiryId]) REFERENCES [SSop].[Enquiries] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_EnquiryServices_JobTypes] on table [SSop].[EnquiryServices]')
GO
ALTER TABLE [SSop].[EnquiryServices] WITH NOCHECK
  ADD CONSTRAINT [FK_EnquiryServices_JobTypes] FOREIGN KEY ([JobTypeId]) REFERENCES [SJob].[JobTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_EnquiryServices_Quotes] on table [SSop].[EnquiryServices]')
GO
ALTER TABLE [SSop].[EnquiryServices] WITH NOCHECK
  ADD CONSTRAINT [FK_EnquiryServices_Quotes] FOREIGN KEY ([QuoteId]) REFERENCES [SSop].[Quotes] ([ID])
GO

PRINT (N'Create foreign key [FK_EnquiryServices_RibaStages] on table [SSop].[EnquiryServices]')
GO
ALTER TABLE [SSop].[EnquiryServices] WITH NOCHECK
  ADD CONSTRAINT [FK_EnquiryServices_RibaStages] FOREIGN KEY ([StartRibaStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_EnquiryServices_RibaStages1] on table [SSop].[EnquiryServices]')
GO
ALTER TABLE [SSop].[EnquiryServices] WITH NOCHECK
  ADD CONSTRAINT [FK_EnquiryServices_RibaStages1] FOREIGN KEY ([EndRibaStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_EnquiryServices_RowStatus] on table [SSop].[EnquiryServices]')
GO
ALTER TABLE [SSop].[EnquiryServices] WITH NOCHECK
  ADD CONSTRAINT [FK_EnquiryServices_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO