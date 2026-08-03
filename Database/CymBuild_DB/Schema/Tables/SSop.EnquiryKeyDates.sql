PRINT (N'Create table [SSop].[EnquiryKeyDates]')
GO
PRINT (N'Create table [SSop].[EnquiryKeyDates]')
GO
CREATE TABLE [SSop].[EnquiryKeyDates] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DC_EnquiryKeyDates_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DC_EnquiryKeyDates_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [EnquiryId] [int] NOT NULL CONSTRAINT [DC_EnquiryKeyDates_EnquiryId] DEFAULT (-1),
  [Details] [varchar](500) NOT NULL DEFAULT (''),
  [DateTime] [datetime2] NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_EnquiryKeyDates_ID] on table [SSop].[EnquiryKeyDates]')
GO
ALTER TABLE [SSop].[EnquiryKeyDates] WITH NOCHECK
  ADD CONSTRAINT [PK_EnquiryKeyDates_ID] PRIMARY KEY CLUSTERED ([ID])
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_EnquiryKeyDatea_Enquiry] on table [SSop].[EnquiryKeyDates]')
GO
CREATE INDEX [IX_EnquiryKeyDatea_Enquiry]
  ON [SSop].[EnquiryKeyDates] ([EnquiryId], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_EnquiryKeyDates_RecordHistory] on table [SSop].[EnquiryKeyDates]')
GO
CREATE TRIGGER [SSop].[tg_EnquiryKeyDates_RecordHistory]
   ON  [SSop].[EnquiryKeyDates]	
   AFTER UPDATE
AS 
BEGIN
	SET NOCOUNT ON;

    IF (ISNULL(CONVERT(int, SESSION_CONTEXT(N'S_disable_triggers')), 0) = 1)
    BEGIN 
        RETURN
    END

    DECLARE	@PreviousValue NVARCHAR(MAX),
			@NewValue NVARCHAR(MAX),
			@UserID INT = 0,
			@SchemaName NVARCHAR(250) = N'SSop',
			@TableName NVARCHAR(250) = N'EnquiryKeyDates',
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1400)
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
				VALUES(1, @SchemaName, @TableName, N'EnquiryId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1403)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Details]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Details]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Details] IS DISTINCT FROM i.[Details])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Details', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1404)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DateTime]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DateTime]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DateTime] IS DISTINCT FROM i.[DateTime])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DateTime', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1405)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_EnquiryKeyDates_EnquiryId] on table [SSop].[EnquiryKeyDates]')
GO
ALTER TABLE [SSop].[EnquiryKeyDates] WITH NOCHECK
  ADD CONSTRAINT [FK_EnquiryKeyDates_EnquiryId] FOREIGN KEY ([EnquiryId]) REFERENCES [SSop].[Enquiries] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_EnquiryKeyDates_Guid] on table [SSop].[EnquiryKeyDates]')
GO
ALTER TABLE [SSop].[EnquiryKeyDates] WITH NOCHECK
  ADD CONSTRAINT [FK_EnquiryKeyDates_Guid] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_EnquiryKeyDates_Guid] on table [SSop].[EnquiryKeyDates]')
GO
ALTER TABLE [SSop].[EnquiryKeyDates]
  NOCHECK CONSTRAINT [FK_EnquiryKeyDates_Guid]
GO

PRINT (N'Create foreign key [FK_EnquiryKeyDates_RowStatus] on table [SSop].[EnquiryKeyDates]')
GO
ALTER TABLE [SSop].[EnquiryKeyDates] WITH NOCHECK
  ADD CONSTRAINT [FK_EnquiryKeyDates_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO