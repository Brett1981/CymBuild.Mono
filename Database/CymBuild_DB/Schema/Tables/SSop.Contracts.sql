PRINT (N'Create table [SSop].[Contracts]')
GO
CREATE TABLE [SSop].[Contracts] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Contracts_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Contracts_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [AccountID] [int] NOT NULL CONSTRAINT [DF_Contracts_AccountID] DEFAULT (-1),
  [StartDate] [date] NOT NULL CONSTRAINT [DF_Contracts_StartDate] DEFAULT (getdate()),
  [EndDate] [date] NULL,
  [NextReviewDate] [date] NOT NULL CONSTRAINT [DF_Contracts_NextReviewDate] DEFAULT (getdate()),
  [SignatoryId] [int] NOT NULL CONSTRAINT [DF_Contracts_SignatoryId] DEFAULT (-1),
  [Details] [nvarchar](2000) NOT NULL CONSTRAINT [DF_Contracts_Details] DEFAULT (''),
  [PriceListId] [int] NOT NULL CONSTRAINT [DF_Contracts_PriceListId] DEFAULT (-1),
  [MinValueOfWork] [decimal](19, 2) NOT NULL DEFAULT (0),
  [MaxValueOfWork] [decimal](19, 2) NOT NULL DEFAULT (0),
  [HasCustomTerms] [bit] NOT NULL DEFAULT (0),
  [ContractTypeId] [int] NOT NULL DEFAULT (-1),
  [CommercialReviewUndertakenByUserId] [int] NOT NULL DEFAULT (-1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Contracts] on table [SSop].[Contracts]')
GO
ALTER TABLE [SSop].[Contracts] WITH NOCHECK
  ADD CONSTRAINT [PK_Contracts] PRIMARY KEY CLUSTERED ([ID])
GO

PRINT (N'Create index [IX_UQ_Contracts_Guid] on table [SSop].[Contracts]')
GO
CREATE UNIQUE INDEX [IX_UQ_Contracts_Guid]
  ON [SSop].[Contracts] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_Contracts_RecordHistory] on table [SSop].[Contracts]')
GO
CREATE TRIGGER [SSop].[tg_Contracts_RecordHistory]
   ON  [SSop].[Contracts]	
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
			@TableName NVARCHAR(250) = N'Contracts',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AccountID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AccountID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AccountID] IS DISTINCT FROM i.[AccountID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AccountID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 608)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ContractTypeID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ContractTypeID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ContractTypeID] IS DISTINCT FROM i.[ContractTypeID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ContractTypeID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2162)
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
				VALUES(1, @SchemaName, @TableName, N'Details', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 609)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[EndDate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[EndDate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[EndDate] IS DISTINCT FROM i.[EndDate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EndDate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 610)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[NextReviewDate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[NextReviewDate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[NextReviewDate] IS DISTINCT FROM i.[NextReviewDate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'NextReviewDate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 613)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PriceListId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PriceListId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PriceListId] IS DISTINCT FROM i.[PriceListId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PriceListId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 679)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 614)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SignatoryId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SignatoryId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SignatoryId] IS DISTINCT FROM i.[SignatoryId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SignatoryId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 616)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[StartDate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[StartDate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[StartDate] IS DISTINCT FROM i.[StartDate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'StartDate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 617)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_Contracts_Accounts] on table [SSop].[Contracts]')
GO
ALTER TABLE [SSop].[Contracts] WITH NOCHECK
  ADD CONSTRAINT [FK_Contracts_Accounts] FOREIGN KEY ([AccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_Contracts_CommercialReviewUndertakenByUserId] on table [SSop].[Contracts]')
GO
ALTER TABLE [SSop].[Contracts] WITH NOCHECK
  ADD CONSTRAINT [FK_Contracts_CommercialReviewUndertakenByUserId] FOREIGN KEY ([CommercialReviewUndertakenByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Contracts_ContractTypeId] on table [SSop].[Contracts]')
GO
ALTER TABLE [SSop].[Contracts] WITH NOCHECK
  ADD CONSTRAINT [FK_Contracts_ContractTypeId] FOREIGN KEY ([ContractTypeId]) REFERENCES [SSop].[ContractTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_Contracts_DataObjects] on table [SSop].[Contracts]')
GO
ALTER TABLE [SSop].[Contracts] WITH NOCHECK
  ADD CONSTRAINT [FK_Contracts_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_Contracts_DataObjects] on table [SSop].[Contracts]')
GO
ALTER TABLE [SSop].[Contracts]
  NOCHECK CONSTRAINT [FK_Contracts_DataObjects]
GO

PRINT (N'Create foreign key [FK_Contracts_Identities] on table [SSop].[Contracts]')
GO
ALTER TABLE [SSop].[Contracts] WITH NOCHECK
  ADD CONSTRAINT [FK_Contracts_Identities] FOREIGN KEY ([SignatoryId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Contracts_PriceLists] on table [SSop].[Contracts]')
GO
ALTER TABLE [SSop].[Contracts] WITH NOCHECK
  ADD CONSTRAINT [FK_Contracts_PriceLists] FOREIGN KEY ([PriceListId]) REFERENCES [SSop].[PriceLists] ([ID])
GO

PRINT (N'Create foreign key [FK_Contracts_RowStatus] on table [SSop].[Contracts]')
GO
ALTER TABLE [SSop].[Contracts] WITH NOCHECK
  ADD CONSTRAINT [FK_Contracts_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO