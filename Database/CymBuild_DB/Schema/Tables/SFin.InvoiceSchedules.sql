PRINT (N'Create table [SFin].[InvoiceSchedules]')
GO
CREATE TABLE [SFin].[InvoiceSchedules] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_InvoiceSchedules_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_InvoiceSchedules_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DF_InvoiceSchedules_Name] DEFAULT (''),
  [DescriptionOfWork] [nvarchar](max) NOT NULL CONSTRAINT [DF_InvoiceSchedule_DescriptionOfWork] DEFAULT (''),
  [Amount] [decimal](19, 2) NOT NULL CONSTRAINT [DF_InvoiceSchedule_Amount] DEFAULT (0),
  [TriggerId] [int] NOT NULL CONSTRAINT [DF_InvoiceSchedules_TriggerId] DEFAULT (-1),
  [ExpectedDate] [date] NULL,
  [QuoteId] [int] NOT NULL CONSTRAINT [DF_InvoiceSchedules_QuoteId] DEFAULT (-1),
  [RibaConfigurationId] [int] NOT NULL CONSTRAINT [DF_InvoiceSchedules_RibaConfigurationId] DEFAULT (-1),
  [ActivityMilestoneConfigurationId] [int] NOT NULL CONSTRAINT [DF_InvoiceSchedules_ActivityMilestoneConfigurationId] DEFAULT (-1),
  [ScheduleReenabled] [bit] NOT NULL CONSTRAINT [DF_InvoiceSchedules_ScheduleReenabled] DEFAULT (0)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_InvoiceSchedules] on table [SFin].[InvoiceSchedules]')
GO
ALTER TABLE [SFin].[InvoiceSchedules] WITH NOCHECK
  ADD CONSTRAINT [PK_InvoiceSchedules] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 90)
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_InvoiceSchedules_RecordHistory] on table [SFin].[InvoiceSchedules]')
GO
CREATE TRIGGER [SFin].[tg_InvoiceSchedules_RecordHistory]
   ON  [SFin].[InvoiceSchedules]	
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
			@SchemaName NVARCHAR(250) = N'SFin',
			@TableName NVARCHAR(250) = N'InvoiceSchedules',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Amount]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Amount]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Amount] IS DISTINCT FROM i.[Amount])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Amount', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2378)
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
				VALUES(1, @SchemaName, @TableName, N'DescriptionOfWork', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2376)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ExpectedDate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ExpectedDate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ExpectedDate] IS DISTINCT FROM i.[ExpectedDate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ExpectedDate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2374)
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
				VALUES(1, @SchemaName, @TableName, N'Name', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2380)
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
				VALUES(1, @SchemaName, @TableName, N'QuoteId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2379)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2373)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[TriggerId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[TriggerId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[TriggerId] IS DISTINCT FROM i.[TriggerId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'TriggerId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2371)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_InvoiceSchedules_ActivityMilestoneConfigurationId] on table [SFin].[InvoiceSchedules]')
GO
ALTER TABLE [SFin].[InvoiceSchedules] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedules_ActivityMilestoneConfigurationId] FOREIGN KEY ([ActivityMilestoneConfigurationId]) REFERENCES [SFin].[InvoiceScheduleActivityMilestoneConfiguration] ([ID])
GO

PRINT (N'Disable foreign key [FK_InvoiceSchedules_ActivityMilestoneConfigurationId] on table [SFin].[InvoiceSchedules]')
GO
ALTER TABLE [SFin].[InvoiceSchedules]
  NOCHECK CONSTRAINT [FK_InvoiceSchedules_ActivityMilestoneConfigurationId]
GO

PRINT (N'Create foreign key [FK_InvoiceSchedules_DataObjects] on table [SFin].[InvoiceSchedules]')
GO
ALTER TABLE [SFin].[InvoiceSchedules] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedules_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_InvoiceSchedules_DataObjects] on table [SFin].[InvoiceSchedules]')
GO
ALTER TABLE [SFin].[InvoiceSchedules]
  NOCHECK CONSTRAINT [FK_InvoiceSchedules_DataObjects]
GO

PRINT (N'Create foreign key [FK_InvoiceSchedules_QuoteId] on table [SFin].[InvoiceSchedules]')
GO
ALTER TABLE [SFin].[InvoiceSchedules] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedules_QuoteId] FOREIGN KEY ([QuoteId]) REFERENCES [SSop].[Quotes] ([ID])
GO

PRINT (N'Create foreign key [FK_InvoiceSchedules_RibaConfigurationId] on table [SFin].[InvoiceSchedules]')
GO
ALTER TABLE [SFin].[InvoiceSchedules] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedules_RibaConfigurationId] FOREIGN KEY ([RibaConfigurationId]) REFERENCES [SFin].[InvoiceScheduleRibaConfiguration] ([ID])
GO

PRINT (N'Disable foreign key [FK_InvoiceSchedules_RibaConfigurationId] on table [SFin].[InvoiceSchedules]')
GO
ALTER TABLE [SFin].[InvoiceSchedules]
  NOCHECK CONSTRAINT [FK_InvoiceSchedules_RibaConfigurationId]
GO

PRINT (N'Create foreign key [FK_InvoiceSchedules_RowStatus] on table [SFin].[InvoiceSchedules]')
GO
ALTER TABLE [SFin].[InvoiceSchedules] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedules_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_InvoiceSchedules_TriggerId] on table [SFin].[InvoiceSchedules]')
GO
ALTER TABLE [SFin].[InvoiceSchedules] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedules_TriggerId] FOREIGN KEY ([TriggerId]) REFERENCES [SFin].[InvoiceScheduleTrigger] ([ID])
GO

PRINT (N'Disable foreign key [FK_InvoiceSchedules_TriggerId] on table [SFin].[InvoiceSchedules]')
GO
ALTER TABLE [SFin].[InvoiceSchedules]
  NOCHECK CONSTRAINT [FK_InvoiceSchedules_TriggerId]
GO