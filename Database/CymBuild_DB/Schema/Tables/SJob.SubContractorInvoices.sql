PRINT (N'Create table [SJob].[SubContractorInvoices]')
GO
CREATE TABLE [SJob].[SubContractorInvoices] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_SubContractorInvoices_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_SubContractorInvoices_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [SubContractorName] [nvarchar](100) NOT NULL CONSTRAINT [DF_SubContractorInvoices_SubContractorName] DEFAULT (''),
  [InvoiceDate] [date] NULL,
  [InvoiceNumber] [nvarchar](50) NOT NULL CONSTRAINT [DF_SubContractorInvoices_InvoiceNumber] DEFAULT (''),
  [DescriptionOfWork] [nvarchar](max) NOT NULL CONSTRAINT [DF_SubContractorInvoices_DescriptionOfWork] DEFAULT (''),
  [ValueWithVAT] [decimal](19, 2) NOT NULL CONSTRAINT [DF_SubContractorInvoices_ValueWithVAT] DEFAULT (0.0),
  [ValueWithoutVAT] [decimal](19, 2) NOT NULL CONSTRAINT [DF_SubContractorInvoices_ValueWithoutVAT] DEFAULT (0.0),
  [ActivityId] [bigint] NOT NULL CONSTRAINT [DF_SubContractorInvoices_ActivityId] DEFAULT (-1),
  [MilestoneId] [bigint] NOT NULL CONSTRAINT [DF_SubContractorInvoices_MilestoneId] DEFAULT (-1),
  [SupportingComments] [nvarchar](max) NOT NULL CONSTRAINT [DF_SubContractorInvoices_SupportingComments] DEFAULT (''),
  [JobId] [int] NOT NULL CONSTRAINT [DF_SubContractorInvoices_JobId] DEFAULT (-1)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SubContractorInvoices] on table [SJob].[SubContractorInvoices]')
GO
ALTER TABLE [SJob].[SubContractorInvoices] WITH NOCHECK
  ADD CONSTRAINT [PK_SubContractorInvoices] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_SubContractorInvoices_RecordHistory] on table [SJob].[SubContractorInvoices]')
GO
CREATE TRIGGER [SJob].[tg_SubContractorInvoices_RecordHistory]
   ON  [SJob].[SubContractorInvoices]	
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
			@TableName NVARCHAR(250) = N'SubContractorInvoices',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ActivityId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ActivityId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ActivityId] IS DISTINCT FROM i.[ActivityId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ActivityId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2512)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DescriptionOfWork]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DescriptionOfWork]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DescriptionOfWork] IS DISTINCT FROM i.[DescriptionOfWork])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DescriptionOfWork', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2516)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[InvoiceDate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[InvoiceDate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[InvoiceDate] IS DISTINCT FROM i.[InvoiceDate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'InvoiceDate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2509)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[InvoiceNumber]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[InvoiceNumber]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[InvoiceNumber] IS DISTINCT FROM i.[InvoiceNumber])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'InvoiceNumber', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2518)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[JobId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[JobId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[JobId] IS DISTINCT FROM i.[JobId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'JobId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2521)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[MilestoneId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[MilestoneId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[MilestoneId] IS DISTINCT FROM i.[MilestoneId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'MilestoneId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2517)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2511)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SubContractorName]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SubContractorName]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SubContractorName] IS DISTINCT FROM i.[SubContractorName])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SubContractorName', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2515)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SupportingComments]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SupportingComments]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SupportingComments] IS DISTINCT FROM i.[SupportingComments])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SupportingComments', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2510)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ValueWithoutVAT]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ValueWithoutVAT]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ValueWithoutVAT] IS DISTINCT FROM i.[ValueWithoutVAT])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ValueWithoutVAT', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2520)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ValueWithVAT]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ValueWithVAT]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ValueWithVAT] IS DISTINCT FROM i.[ValueWithVAT])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ValueWithVAT', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2514)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_SubContractorInvoices_ActivityId] on table [SJob].[SubContractorInvoices]')
GO
ALTER TABLE [SJob].[SubContractorInvoices] WITH NOCHECK
  ADD CONSTRAINT [FK_SubContractorInvoices_ActivityId] FOREIGN KEY ([ActivityId]) REFERENCES [SJob].[Activities] ([ID])
GO

PRINT (N'Create foreign key [FK_SubContractorInvoices_DataObjects] on table [SJob].[SubContractorInvoices]')
GO
ALTER TABLE [SJob].[SubContractorInvoices] WITH NOCHECK
  ADD CONSTRAINT [FK_SubContractorInvoices_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_SubContractorInvoices_DataObjects] on table [SJob].[SubContractorInvoices]')
GO
ALTER TABLE [SJob].[SubContractorInvoices]
  NOCHECK CONSTRAINT [FK_SubContractorInvoices_DataObjects]
GO

PRINT (N'Create foreign key [FK_SubContractorInvoices_JobId] on table [SJob].[SubContractorInvoices]')
GO
ALTER TABLE [SJob].[SubContractorInvoices] WITH NOCHECK
  ADD CONSTRAINT [FK_SubContractorInvoices_JobId] FOREIGN KEY ([JobId]) REFERENCES [SJob].[Jobs] ([ID])
GO

PRINT (N'Create foreign key [FK_SubContractorInvoices_MilestoneId] on table [SJob].[SubContractorInvoices]')
GO
ALTER TABLE [SJob].[SubContractorInvoices] WITH NOCHECK
  ADD CONSTRAINT [FK_SubContractorInvoices_MilestoneId] FOREIGN KEY ([MilestoneId]) REFERENCES [SJob].[Milestones] ([ID])
GO

PRINT (N'Create foreign key [FK_SubContractorInvoices_RowStatus] on table [SJob].[SubContractorInvoices]')
GO
ALTER TABLE [SJob].[SubContractorInvoices] WITH NOCHECK
  ADD CONSTRAINT [FK_SubContractorInvoices_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO