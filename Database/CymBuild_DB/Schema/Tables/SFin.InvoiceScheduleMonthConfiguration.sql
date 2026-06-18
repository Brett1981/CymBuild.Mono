PRINT (N'Create table [SFin].[InvoiceScheduleMonthConfiguration]')
GO
PRINT (N'Create table [SFin].[InvoiceScheduleMonthConfiguration]')
GO
PRINT (N'Create table [SFin].[InvoiceScheduleMonthConfiguration]')
GO
CREATE TABLE [SFin].[InvoiceScheduleMonthConfiguration] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_InvoiceScheduleMonthConfiguration_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_InvoiceScheduleMonthConfiguration_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [InvoiceScheduleId] [int] NOT NULL CONSTRAINT [DF_InvoiceScheduleMonthConfiguration_InvoiceScheduleId] DEFAULT (-1),
  [PeriodNumber] [int] NOT NULL CONSTRAINT [DF_InvoiceScheduleMonthConfiguration_PeriodNumber] DEFAULT (0),
  [Amount] [decimal](19, 2) NOT NULL CONSTRAINT [DF_InvoiceScheduleMonthConfiguration_Amount] DEFAULT (0.0),
  [OnDayOfMonth] [date] NULL,
  [Description] [nvarchar](max) NOT NULL CONSTRAINT [DF_InvoiceScheduleMonthConfiguration_Description] DEFAULT (''),
  [RIBAStageId] [int] NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_InvoiceScheduleMonthConfiguration] on table [SFin].[InvoiceScheduleMonthConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceScheduleMonthConfiguration] WITH NOCHECK
  ADD CONSTRAINT [PK_InvoiceScheduleMonthConfiguration] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 90)
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_InvoiceScheduleMonthConfiguration_RecordHistory] on table [SFin].[InvoiceScheduleMonthConfiguration]')
GO
CREATE TRIGGER [SFin].[tg_InvoiceScheduleMonthConfiguration_RecordHistory]
   ON  [SFin].[InvoiceScheduleMonthConfiguration]	
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
			@TableName NVARCHAR(250) = N'InvoiceScheduleMonthConfiguration',
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
				VALUES(1, @SchemaName, @TableName, N'Amount', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2395)
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
				VALUES(1, @SchemaName, @TableName, N'Description', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2388)
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
				VALUES(1, @SchemaName, @TableName, N'InvoiceScheduleId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2391)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[OnDayOfMonth]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[OnDayOfMonth]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[OnDayOfMonth] IS DISTINCT FROM i.[OnDayOfMonth])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'OnDayOfMonth', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2392)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PeriodNumber]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PeriodNumber]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PeriodNumber] IS DISTINCT FROM i.[PeriodNumber])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PeriodNumber', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2394)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2389)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_InvoiceScheduleMonthConfiguration_DataObjects] on table [SFin].[InvoiceScheduleMonthConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceScheduleMonthConfiguration] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceScheduleMonthConfiguration_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_InvoiceScheduleMonthConfiguration_DataObjects] on table [SFin].[InvoiceScheduleMonthConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceScheduleMonthConfiguration]
  NOCHECK CONSTRAINT [FK_InvoiceScheduleMonthConfiguration_DataObjects]
GO

PRINT (N'Create foreign key [FK_InvoiceScheduleMonthConfiguration_InvoiceScheduleId] on table [SFin].[InvoiceScheduleMonthConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceScheduleMonthConfiguration] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceScheduleMonthConfiguration_InvoiceScheduleId] FOREIGN KEY ([InvoiceScheduleId]) REFERENCES [SFin].[InvoiceSchedules] ([ID])
GO

PRINT (N'Create foreign key [FK_InvoiceScheduleMonthConfiguration_RibaStages] on table [SFin].[InvoiceScheduleMonthConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceScheduleMonthConfiguration] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceScheduleMonthConfiguration_RibaStages] FOREIGN KEY ([RIBAStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_InvoiceScheduleMonthConfiguration_RowStatus] on table [SFin].[InvoiceScheduleMonthConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceScheduleMonthConfiguration] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceScheduleMonthConfiguration_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO