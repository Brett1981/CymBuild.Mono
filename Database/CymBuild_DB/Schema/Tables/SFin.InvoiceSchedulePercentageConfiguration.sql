PRINT (N'Create table [SFin].[InvoiceSchedulePercentageConfiguration]')
GO
PRINT (N'Create table [SFin].[InvoiceSchedulePercentageConfiguration]')
GO
PRINT (N'Create table [SFin].[InvoiceSchedulePercentageConfiguration]')
GO
CREATE TABLE [SFin].[InvoiceSchedulePercentageConfiguration] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_InvoiceSchedulePercentageConfiguration_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_InvoiceSchedulePercentageConfiguration_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [InvoiceScheduleId] [int] NOT NULL CONSTRAINT [DF_InvoiceSchedulePercentageConfiguration_InvoiceScheduleId] DEFAULT (-1),
  [PeriodNumber] [int] NOT NULL CONSTRAINT [DF_InvoiceSchedulePercentageConfiguration_PeriodNumber] DEFAULT (1),
  [Percentage] [decimal](19, 2) NOT NULL CONSTRAINT [DF_InvoiceSchedulePercentageConfiguration_Percentage] DEFAULT (0.0),
  [OnDayOfMonth] [date] NULL,
  [Description] [nvarchar](max) NOT NULL CONSTRAINT [DF_InvoiceSchedulePercentageConfiguration_Description] DEFAULT (''),
  [RIBAStageId] [int] NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_InvoiceSchedulePercentageConfiguration] on table [SFin].[InvoiceSchedulePercentageConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceSchedulePercentageConfiguration] WITH NOCHECK
  ADD CONSTRAINT [PK_InvoiceSchedulePercentageConfiguration] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 90)
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_InvoiceSchedulePercentageConfiguration_RecordHistory] on table [SFin].[InvoiceSchedulePercentageConfiguration]')
GO
CREATE TRIGGER [SFin].[tg_InvoiceSchedulePercentageConfiguration_RecordHistory]
   ON  [SFin].[InvoiceSchedulePercentageConfiguration]	
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
			@TableName NVARCHAR(250) = N'InvoiceSchedulePercentageConfiguration',
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
				VALUES(1, @SchemaName, @TableName, N'Description', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2406)
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
				VALUES(1, @SchemaName, @TableName, N'InvoiceScheduleId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2410)
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
				VALUES(1, @SchemaName, @TableName, N'OnDayOfMonth', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2411)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Percentage]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Percentage]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Percentage] IS DISTINCT FROM i.[Percentage])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Percentage', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2409)
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
				VALUES(1, @SchemaName, @TableName, N'PeriodNumber', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2413)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2407)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_InvoiceSchedulePercentageConfiguration_DataObjects] on table [SFin].[InvoiceSchedulePercentageConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceSchedulePercentageConfiguration] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedulePercentageConfiguration_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_InvoiceSchedulePercentageConfiguration_DataObjects] on table [SFin].[InvoiceSchedulePercentageConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceSchedulePercentageConfiguration]
  NOCHECK CONSTRAINT [FK_InvoiceSchedulePercentageConfiguration_DataObjects]
GO

PRINT (N'Create foreign key [FK_InvoiceSchedulePercentageConfiguration_InvoiceScheduleId] on table [SFin].[InvoiceSchedulePercentageConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceSchedulePercentageConfiguration] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedulePercentageConfiguration_InvoiceScheduleId] FOREIGN KEY ([InvoiceScheduleId]) REFERENCES [SFin].[InvoiceSchedules] ([ID])
GO

PRINT (N'Create foreign key [FK_InvoiceSchedulePercentageConfiguration_RibaStages] on table [SFin].[InvoiceSchedulePercentageConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceSchedulePercentageConfiguration] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedulePercentageConfiguration_RibaStages] FOREIGN KEY ([RIBAStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_InvoiceSchedulePercentageConfiguration_RowStatus] on table [SFin].[InvoiceSchedulePercentageConfiguration]')
GO
ALTER TABLE [SFin].[InvoiceSchedulePercentageConfiguration] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceSchedulePercentageConfiguration_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO