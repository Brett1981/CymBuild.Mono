PRINT (N'Create table [SSop].[QuoteSections]')
GO
CREATE TABLE [SSop].[QuoteSections] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_QuoteSections_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_QuoteSections_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [QuoteId] [int] NOT NULL CONSTRAINT [DF_QuoteSections_QuoteId] DEFAULT (-1),
  [Name] [nvarchar](200) NOT NULL CONSTRAINT [DF_QuoteSections_Name] DEFAULT (''),
  [Overview] [nvarchar](max) NOT NULL CONSTRAINT [DF_QuoteSections_Overview] DEFAULT (''),
  [ShowProducts] [bit] NOT NULL CONSTRAINT [DF_QuoteSections_ShowProducts] DEFAULT (0),
  [ConsolidateJobs] [bit] NOT NULL CONSTRAINT [DF_QuoteSections_ConsolidateJobs] DEFAULT (0),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF_QuoteSections_SortOrder] DEFAULT (0),
  [ValueOfWorkId] [smallint] NOT NULL CONSTRAINT [DF_QuoteSections_ValueOfWorkId] DEFAULT (-1),
  [RibaStageId] [int] NOT NULL CONSTRAINT [DF_QuoteSections_RibaStage] DEFAULT (-1),
  [CombineWithSectionId] [int] NOT NULL CONSTRAINT [DF_QuoteSections_CombineWithSecionId] DEFAULT (-1),
  [NumberOfMeetings] [int] NOT NULL CONSTRAINT [DF_QuoteSections_NumberOfMeetings] DEFAULT (0),
  [NumberOfSiteVisits] [int] NOT NULL CONSTRAINT [DF_QuoteSections_NumberOfSiteVisits] DEFAULT (0),
  [InvoiceScheduleId] [int] NOT NULL CONSTRAINT [DF_QuoteSections_InvoiceScheduleId] DEFAULT (-1),
  [LegacyId] [int] NULL,
  [LegacySystemID] [int] NOT NULL DEFAULT (-1)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_QuoteSections] on table [SSop].[QuoteSections]')
GO
ALTER TABLE [SSop].[QuoteSections] WITH NOCHECK
  ADD CONSTRAINT [PK_QuoteSections] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 90)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_QuoteSections_QuoteId] on table [SSop].[QuoteSections]')
GO
CREATE INDEX [IX_QuoteSections_QuoteId]
  ON [SSop].[QuoteSections] ([QuoteId], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_QuoteSections_Guid] on table [SSop].[QuoteSections]')
GO
CREATE UNIQUE INDEX [IX_UQ_QuoteSections_Guid]
  ON [SSop].[QuoteSections] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_QuoteSections_RecordHistory] on table [SSop].[QuoteSections]')
GO
CREATE TRIGGER [SSop].[tg_QuoteSections_RecordHistory]
   ON  [SSop].[QuoteSections]	
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
			@TableName NVARCHAR(250) = N'QuoteSections',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CombineWithSectionId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CombineWithSectionId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CombineWithSectionId] IS DISTINCT FROM i.[CombineWithSectionId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CombineWithSectionId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 867)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ConsolidateJobs]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ConsolidateJobs]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ConsolidateJobs] IS DISTINCT FROM i.[ConsolidateJobs])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ConsolidateJobs', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 656)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Name]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Name]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Name] IS DISTINCT FROM i.[Name])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Name', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 659)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[NumberOfMeetings]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[NumberOfMeetings]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[NumberOfMeetings] IS DISTINCT FROM i.[NumberOfMeetings])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'NumberOfMeetings', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 883)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[NumberOfSiteVisits]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[NumberOfSiteVisits]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[NumberOfSiteVisits] IS DISTINCT FROM i.[NumberOfSiteVisits])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'NumberOfSiteVisits', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 884)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Overview]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Overview]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Overview] IS DISTINCT FROM i.[Overview])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Overview', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 660)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[QuoteId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[QuoteId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[QuoteId] IS DISTINCT FROM i.[QuoteId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'QuoteId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 661)
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
				VALUES(1, @SchemaName, @TableName, N'RibaStageId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 868)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 662)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ShowProducts]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ShowProducts]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ShowProducts] IS DISTINCT FROM i.[ShowProducts])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ShowProducts', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 664)
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
				VALUES(1, @SchemaName, @TableName, N'SortOrder', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 665)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ValueOfWorkId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ValueOfWorkId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ValueOfWorkId] IS DISTINCT FROM i.[ValueOfWorkId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ValueOfWorkId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 717)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_QuoteSections_DataObjects] on table [SSop].[QuoteSections]')
GO
ALTER TABLE [SSop].[QuoteSections] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteSections_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_QuoteSections_DataObjects] on table [SSop].[QuoteSections]')
GO
ALTER TABLE [SSop].[QuoteSections]
  NOCHECK CONSTRAINT [FK_QuoteSections_DataObjects]
GO

PRINT (N'Create foreign key [FK_QuoteSections_InvoiceSchedules] on table [SSop].[QuoteSections]')
GO
ALTER TABLE [SSop].[QuoteSections] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteSections_InvoiceSchedules] FOREIGN KEY ([InvoiceScheduleId]) REFERENCES [SSop].[InvoiceSchedules] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteSections_Quotes] on table [SSop].[QuoteSections]')
GO
ALTER TABLE [SSop].[QuoteSections] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteSections_Quotes] FOREIGN KEY ([QuoteId]) REFERENCES [SSop].[Quotes] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_QuoteSections_QuoteSections] on table [SSop].[QuoteSections]')
GO
ALTER TABLE [SSop].[QuoteSections] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteSections_QuoteSections] FOREIGN KEY ([CombineWithSectionId]) REFERENCES [SSop].[QuoteSections] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteSections_RibaStages] on table [SSop].[QuoteSections]')
GO
ALTER TABLE [SSop].[QuoteSections] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteSections_RibaStages] FOREIGN KEY ([RibaStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteSections_RowStatus] on table [SSop].[QuoteSections]')
GO
ALTER TABLE [SSop].[QuoteSections] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteSections_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteSections_ValuesOfWork] on table [SSop].[QuoteSections]')
GO
ALTER TABLE [SSop].[QuoteSections] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteSections_ValuesOfWork] FOREIGN KEY ([ValueOfWorkId]) REFERENCES [SJob].[ValuesOfWork] ([ID])
GO