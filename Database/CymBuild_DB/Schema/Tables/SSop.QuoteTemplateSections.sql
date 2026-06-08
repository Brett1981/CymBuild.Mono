PRINT (N'Create table [SSop].[QuoteTemplateSections]')
GO
CREATE TABLE [SSop].[QuoteTemplateSections] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_QuoteTemplateSections_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_QuoteTemplateSections_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [QuoteTemplateId] [int] NOT NULL CONSTRAINT [DF_QuoteTemplateSections_QuoteId] DEFAULT (-1),
  [Name] [nvarchar](200) NOT NULL CONSTRAINT [DF_QuoteTemplateSections_Name] DEFAULT (''),
  [Overview] [nvarchar](max) NOT NULL CONSTRAINT [DF_QuoteTemplateSections_Overview] DEFAULT (''),
  [ShowProducts] [bit] NOT NULL CONSTRAINT [DF_QuoteTemplateSections_ShowProducts] DEFAULT (0),
  [ConsolidateJobs] [bit] NOT NULL CONSTRAINT [DF_QuoteTemplateSections_ConsolidateJobs] DEFAULT (0),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF_QuoteTemplateSections_SortOrder] DEFAULT (0),
  [ValueOfWorkId] [smallint] NOT NULL CONSTRAINT [DF_QuoteTemplateSections_ValueOfWorkId] DEFAULT (-1),
  [RibaStageId] [int] NOT NULL CONSTRAINT [DF_QuoteTemplateSections_RibaStage] DEFAULT (-1),
  [CombineWithSectionId] [int] NOT NULL CONSTRAINT [DF_QuoteTemplateSections_CombineWithSecionId] DEFAULT (-1),
  [NumberOfMeetings] [int] NOT NULL CONSTRAINT [DF_QuoteTemplateSections_NumberOfMeetings] DEFAULT (0),
  [NumberOfSiteVisits] [int] NOT NULL CONSTRAINT [DF_QuoteTemplateSections_NumberOfSiteVisits] DEFAULT (0),
  [InvoiceScheduleId] [int] NOT NULL CONSTRAINT [DF_QuoteTemplateSections_InvoiceScheduleId] DEFAULT (-1)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_QuoteTemplateSections] on table [SSop].[QuoteTemplateSections]')
GO
ALTER TABLE [SSop].[QuoteTemplateSections] WITH NOCHECK
  ADD CONSTRAINT [PK_QuoteTemplateSections] PRIMARY KEY CLUSTERED ([ID])
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_QuoteTemplateSections_RecordHistory] on table [SSop].[QuoteTemplateSections]')
GO
CREATE TRIGGER [SSop].[tg_QuoteTemplateSections_RecordHistory]
   ON  [SSop].[QuoteTemplateSections]	
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
			@TableName NVARCHAR(250) = N'QuoteTemplateSections',
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
				VALUES(1, @SchemaName, @TableName, N'CombineWithSectionId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 893)
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
				VALUES(1, @SchemaName, @TableName, N'ConsolidateJobs', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 894)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[InvoiceScheduleId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[InvoiceScheduleId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[InvoiceScheduleId] IS DISTINCT FROM i.[InvoiceScheduleId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'InvoiceScheduleId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 897)
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
				VALUES(1, @SchemaName, @TableName, N'Name', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 898)
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
				VALUES(1, @SchemaName, @TableName, N'NumberOfMeetings', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 899)
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
				VALUES(1, @SchemaName, @TableName, N'NumberOfSiteVisits', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 900)
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
				VALUES(1, @SchemaName, @TableName, N'Overview', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 901)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[QuoteTemplateId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[QuoteTemplateId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[QuoteTemplateId] IS DISTINCT FROM i.[QuoteTemplateId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'QuoteTemplateId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 902)
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
				VALUES(1, @SchemaName, @TableName, N'RibaStageId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 903)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 904)
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
				VALUES(1, @SchemaName, @TableName, N'ShowProducts', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 906)
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
				VALUES(1, @SchemaName, @TableName, N'SortOrder', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 907)
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
				VALUES(1, @SchemaName, @TableName, N'ValueOfWorkId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 908)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_QuoteTemplateSections_DataObjects] on table [SSop].[QuoteTemplateSections]')
GO
ALTER TABLE [SSop].[QuoteTemplateSections] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteTemplateSections_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_QuoteTemplateSections_DataObjects] on table [SSop].[QuoteTemplateSections]')
GO
ALTER TABLE [SSop].[QuoteTemplateSections]
  NOCHECK CONSTRAINT [FK_QuoteTemplateSections_DataObjects]
GO

PRINT (N'Create foreign key [FK_QuoteTemplateSections_InvoiceSchedules] on table [SSop].[QuoteTemplateSections]')
GO
ALTER TABLE [SSop].[QuoteTemplateSections] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteTemplateSections_InvoiceSchedules] FOREIGN KEY ([InvoiceScheduleId]) REFERENCES [SSop].[InvoiceSchedules] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteTemplateSections_QuoteTemplates] on table [SSop].[QuoteTemplateSections]')
GO
ALTER TABLE [SSop].[QuoteTemplateSections] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteTemplateSections_QuoteTemplates] FOREIGN KEY ([QuoteTemplateId]) REFERENCES [SSop].[QuoteTemplates] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteTemplateSections_QuoteTemplateSections] on table [SSop].[QuoteTemplateSections]')
GO
ALTER TABLE [SSop].[QuoteTemplateSections] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteTemplateSections_QuoteTemplateSections] FOREIGN KEY ([CombineWithSectionId]) REFERENCES [SSop].[QuoteTemplateSections] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteTemplateSections_RibaStages] on table [SSop].[QuoteTemplateSections]')
GO
ALTER TABLE [SSop].[QuoteTemplateSections] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteTemplateSections_RibaStages] FOREIGN KEY ([RibaStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteTemplateSections_RowStatus] on table [SSop].[QuoteTemplateSections]')
GO
ALTER TABLE [SSop].[QuoteTemplateSections] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteTemplateSections_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteTemplateSections_ValuesOfWork] on table [SSop].[QuoteTemplateSections]')
GO
ALTER TABLE [SSop].[QuoteTemplateSections] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteTemplateSections_ValuesOfWork] FOREIGN KEY ([ValueOfWorkId]) REFERENCES [SJob].[ValuesOfWork] ([ID])
GO