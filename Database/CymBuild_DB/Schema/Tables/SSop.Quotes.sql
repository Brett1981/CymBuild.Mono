SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create table [SSop].[Quotes]')
GO
SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create table [SSop].[Quotes]')
GO
SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create table [SSop].[Quotes]')
GO
CREATE TABLE [SSop].[Quotes] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Quotes_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Quotes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Number] [nvarchar](50) NOT NULL CONSTRAINT [DF_Quotes_Number] DEFAULT (0),
  [RevisionNumber] [int] NOT NULL CONSTRAINT [DF_Quotes_RevisionNumber] DEFAULT (0),
  [OriginalQuoteId] [int] NOT NULL CONSTRAINT [DF_Quotes_OriginalQuoteId] DEFAULT (-1),
  [EnquiryServiceID] [int] NOT NULL CONSTRAINT [DF_Quotes_EnquiryServiceID] DEFAULT (-1),
  [QuotingUserId] [int] NOT NULL CONSTRAINT [DF_Quotes_QuoteingUserId] DEFAULT (-1),
  [QuotingConsultantId] [int] NOT NULL CONSTRAINT [DF_Quotes_QuotingConsultantId] DEFAULT (-1),
  [IsFinal] [bit] NOT NULL CONSTRAINT [DF_Quotes_IsFinal] DEFAULT (0),
  [FeeCap] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Quotes_FeeCap] DEFAULT (0),
  [AppointmentFromRibaStageId] [int] NOT NULL CONSTRAINT [DF_Quotes_AppointedFromRibaStageId] DEFAULT (-1),
  [Date] [date] NOT NULL CONSTRAINT [DF_Quotes_Date] DEFAULT (getdate()),
  [ExpiryDate] [date] NOT NULL CONSTRAINT [DF_Quotes_ExpiryDate] DEFAULT (getdate()),
  [DateSent] [date] NULL,
  [DateAccepted] [date] NULL,
  [DateRejected] [date] NULL,
  [DeadDate] [date] NULL,
  [RejectionReason] [nvarchar](max) NOT NULL CONSTRAINT [DF_Quotes_RejectionReason] DEFAULT (''),
  [ExclusionsAndLimitations] [nvarchar](max) NOT NULL CONSTRAINT [DF_Quotes_ExclusionsAndLimitations] DEFAULT (''),
  [OrganisationalUnitID] [int] NOT NULL CONSTRAINT [DF_Quotes_OrganisationalUnitID] DEFAULT (-1),
  [ContractID] [int] NOT NULL CONSTRAINT [DF_Quotes_ContractID] DEFAULT (-1),
  [LegacyId] [int] NULL,
  [LegacySystemID] [int] NOT NULL CONSTRAINT [DF_Quotes_LegacySystem] DEFAULT (-1),
  [UprnId] [int] NOT NULL CONSTRAINT [DF_Quotes_UprnId] DEFAULT (-1),
  [ClientAccountId] [int] NOT NULL CONSTRAINT [DF_Quotes_ClientAccountId] DEFAULT (-1),
  [ClientAddressId] [int] NOT NULL CONSTRAINT [DF_Quotes_CLientAddressId] DEFAULT (-1),
  [ClientContactId] [int] NOT NULL CONSTRAINT [DF_Quotes_ClientContactId] DEFAULT (-1),
  [Overview] [nvarchar](max) NOT NULL CONSTRAINT [DF_Quotes_Overview] DEFAULT (''),
  [QuoteSourceId] [int] NOT NULL CONSTRAINT [DF_Quotes_QuoteSourceId] DEFAULT (-1),
  [IsSubjectToNDA] [bit] NOT NULL CONSTRAINT [DF_Quotes_IsSubjectToNDA] DEFAULT (0),
  [AgentAccountId] [int] NOT NULL CONSTRAINT [DF_Quotes_AgentAccountId] DEFAULT (-1),
  [AgentAddressId] [int] NOT NULL CONSTRAINT [DF_Quotes_AgentAddressId] DEFAULT (-1),
  [AgentContactId] [int] NOT NULL CONSTRAINT [DF_Quotes_AgentContactId] DEFAULT (-1),
  [ExternalReference] [nvarchar](50) NOT NULL CONSTRAINT [DF_Quotes_ExternalReference] DEFAULT (''),
  [ChaseDate1] [date] NULL,
  [ChaseDate2] [date] NULL,
  [SendInfoToClient] [bit] NOT NULL CONSTRAINT [DF_Quotes_SendInfoToClient] DEFAULT (0),
  [SendInfoToAgent] [bit] NOT NULL CONSTRAINT [DF_Quotes_SendInfoToAgent] DEFAULT (0),
  [CurrentRibaStageId] [int] NOT NULL CONSTRAINT [DF_Quotes_CurrentRibaStageId] DEFAULT (-1),
  [ProjectId] [int] NOT NULL CONSTRAINT [DF_Quotes_ProjectId] DEFAULT (-1),
  [ValueOfWork] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Quotes_ValueOfWork] DEFAULT (0),
  [DateDeclinedToQuote] [date] NULL,
  [DeclinedToQuoteReason] [nvarchar](4000) NOT NULL CONSTRAINT [DF_Quotes_Declined] DEFAULT (''),
  [DescriptionOfWorks] [nvarchar](4000) NOT NULL CONSTRAINT [DF_Quotes_Description] DEFAULT (''),
  [FullNumber] AS ([Number]+case when [RevisionNumber]>(0) then (N' ('+CONVERT([nvarchar](50),[RevisionNumber]))+N')' else N'' end) PERSISTED,
  [AgentContractID] [int] NOT NULL CONSTRAINT [DF_Quotes_AgentContractId] DEFAULT (-1),
  [SectorId] [int] NOT NULL CONSTRAINT [DF_Quotes_SectorId] DEFAULT (-1),
  [MarketId] [int] NOT NULL CONSTRAINT [DF_Quotes_MarketId] DEFAULT (-1),
  [DataClassificationID] [int] NOT NULL CONSTRAINT [DF_Quotes_DataClassificationID] DEFAULT (-1),
  [SecurityClassificationID] [int] NOT NULL CONSTRAINT [DF_Quotes_SecurityClassificationID] DEFAULT (-1),
  [JobTypeId] [int] NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Quotes] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [PK_Quotes] PRIMARY KEY CLUSTERED ([ID]) WITH (PAD_INDEX = ON, FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_Quote_Status] on table [SSop].[Quotes]')
GO
CREATE UNIQUE INDEX [IX_Quote_Status]
  ON [SSop].[Quotes] ([ID])
  INCLUDE ([IsFinal], [ExpiryDate], [DateSent], [DateAccepted], [DateRejected], [DeadDate], [DateDeclinedToQuote])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Quotes_DateAccepted] on table [SSop].[Quotes]')
GO
CREATE INDEX [IX_Quotes_DateAccepted]
  ON [SSop].[Quotes] ([DateAccepted], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_Quotes_DateRejected_ID_RowStatus_ExpiryDate] on table [SSop].[Quotes]')
GO
CREATE INDEX [IX_Quotes_DateRejected_ID_RowStatus_ExpiryDate]
  ON [SSop].[Quotes] ([DateRejected], [ID], [RowStatus], [ExpiryDate])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_Quotes_DW] on table [SSop].[Quotes]')
GO
CREATE INDEX [IX_Quotes_DW]
  ON [SSop].[Quotes] ([DateSent])
  INCLUDE ([OrganisationalUnitID], [QuotingUserId], [UprnId], [ClientAccountId], [DateAccepted], [DateRejected], [AgentAccountId])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_Quotes_EnquiryService] on table [SSop].[Quotes]')
GO
CREATE INDEX [IX_Quotes_EnquiryService]
  ON [SSop].[Quotes] ([EnquiryServiceID], [DateSent], [DateRejected], [DateAccepted])
  INCLUDE ([RevisionNumber])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_Quotes_EnquiryServiceId_RowStatus_Dates] on table [SSop].[Quotes]')
GO
CREATE INDEX [IX_Quotes_EnquiryServiceId_RowStatus_Dates]
  ON [SSop].[Quotes] ([EnquiryServiceID], [RowStatus])
  INCLUDE ([DateSent])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_Quotes_EnquiryServiceId_StatusDates] on table [SSop].[Quotes]')
GO
CREATE INDEX [IX_Quotes_EnquiryServiceId_StatusDates]
  ON [SSop].[Quotes] ([EnquiryServiceID])
  INCLUDE ([DateAccepted], [DateDeclinedToQuote], [DateRejected], [DateSent])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_Quotes_Guid] on table [SSop].[Quotes]')
GO
CREATE UNIQUE INDEX [IX_UQ_Quotes_Guid]
  ON [SSop].[Quotes] ([Guid])
  INCLUDE ([RowStatus])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [Quotes_Number] on table [SSop].[Quotes]')
GO
CREATE INDEX [Quotes_Number]
  ON [SSop].[Quotes] ([Number] DESC, [RevisionNumber], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_Quotes_RecordHistory] on table [SSop].[Quotes]')
GO
CREATE TRIGGER [SSop].[tg_Quotes_RecordHistory]
   ON  [SSop].[Quotes]	
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
			@TableName NVARCHAR(250) = N'Quotes',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AgentContractID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AgentContractID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AgentContractID] IS DISTINCT FROM i.[AgentContractID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AgentContractID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2160)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AppointmentFromRibaStageId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AppointmentFromRibaStageId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AppointmentFromRibaStageId] IS DISTINCT FROM i.[AppointmentFromRibaStageId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AppointmentFromRibaStageId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1211)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ChaseDate1]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ChaseDate1]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ChaseDate1] IS DISTINCT FROM i.[ChaseDate1])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ChaseDate1', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 863)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ChaseDate2]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ChaseDate2]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ChaseDate2] IS DISTINCT FROM i.[ChaseDate2])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ChaseDate2', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 864)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ContractID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ContractID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ContractID] IS DISTINCT FROM i.[ContractID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ContractID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 646)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CurrentRibaStageId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CurrentRibaStageId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CurrentRibaStageId] IS DISTINCT FROM i.[CurrentRibaStageId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CurrentRibaStageId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1691)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Date]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Date]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Date] IS DISTINCT FROM i.[Date])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Date', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 647)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DateAccepted]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DateAccepted]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DateAccepted] IS DISTINCT FROM i.[DateAccepted])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DateAccepted', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 709)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DateDeclinedToQuote]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DateDeclinedToQuote]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DateDeclinedToQuote] IS DISTINCT FROM i.[DateDeclinedToQuote])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DateDeclinedToQuote', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2058)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DateRejected]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DateRejected]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DateRejected] IS DISTINCT FROM i.[DateRejected])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DateRejected', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 710)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DateSent]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DateSent]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DateSent] IS DISTINCT FROM i.[DateSent])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DateSent', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 711)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DeadDate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DeadDate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DeadDate] IS DISTINCT FROM i.[DeadDate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DeadDate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1695)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DeclinedToQuoteReason]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DeclinedToQuoteReason]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DeclinedToQuoteReason] IS DISTINCT FROM i.[DeclinedToQuoteReason])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DeclinedToQuoteReason', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2061)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[EnquiryServiceID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[EnquiryServiceID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[EnquiryServiceID] IS DISTINCT FROM i.[EnquiryServiceID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EnquiryServiceID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1842)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ExclusionsAndLimitations]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ExclusionsAndLimitations]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ExclusionsAndLimitations] IS DISTINCT FROM i.[ExclusionsAndLimitations])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ExclusionsAndLimitations', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1843)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ExpiryDate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ExpiryDate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ExpiryDate] IS DISTINCT FROM i.[ExpiryDate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ExpiryDate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 712)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ExternalReference]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ExternalReference]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ExternalReference] IS DISTINCT FROM i.[ExternalReference])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ExternalReference', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 721)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FeeCap]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FeeCap]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FeeCap] IS DISTINCT FROM i.[FeeCap])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FeeCap', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 865)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsFinal]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsFinal]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsFinal] IS DISTINCT FROM i.[IsFinal])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsFinal', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1074)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsSubjectToNDA]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsSubjectToNDA]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsSubjectToNDA] IS DISTINCT FROM i.[IsSubjectToNDA])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsSubjectToNDA', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 722)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[LegacyId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[LegacyId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[LegacyId] IS DISTINCT FROM i.[LegacyId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'LegacyId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1207)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[LegacySystemID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[LegacySystemID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[LegacySystemID] IS DISTINCT FROM i.[LegacySystemID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'LegacySystemID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1844)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[MarketId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[MarketId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[MarketId] IS DISTINCT FROM i.[MarketId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'MarketId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2569)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Number]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Number]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Number] IS DISTINCT FROM i.[Number])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Number', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 650)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[OrganisationalUnitID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[OrganisationalUnitID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[OrganisationalUnitID] IS DISTINCT FROM i.[OrganisationalUnitID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'OrganisationalUnitID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 651)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[OriginalQuoteId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[OriginalQuoteId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[OriginalQuoteId] IS DISTINCT FROM i.[OriginalQuoteId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'OriginalQuoteId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1600)
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
				VALUES(1, @SchemaName, @TableName, N'Overview', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 652)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ProjectId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ProjectId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ProjectId] IS DISTINCT FROM i.[ProjectId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ProjectId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1229)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[QuoteSourceId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[QuoteSourceId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[QuoteSourceId] IS DISTINCT FROM i.[QuoteSourceId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'QuoteSourceId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 713)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[QuotingConsultantId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[QuotingConsultantId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[QuotingConsultantId] IS DISTINCT FROM i.[QuotingConsultantId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'QuotingConsultantId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1210)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[QuotingUserId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[QuotingUserId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[QuotingUserId] IS DISTINCT FROM i.[QuotingUserId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'QuotingUserId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 653)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RejectionReason]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RejectionReason]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RejectionReason] IS DISTINCT FROM i.[RejectionReason])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RejectionReason', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 714)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RevisionNumber]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RevisionNumber]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RevisionNumber] IS DISTINCT FROM i.[RevisionNumber])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RevisionNumber', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1601)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 654)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SectorId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SectorId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SectorId] IS DISTINCT FROM i.[SectorId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SectorId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2557)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SendInfoToAgent]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SendInfoToAgent]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SendInfoToAgent] IS DISTINCT FROM i.[SendInfoToAgent])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SendInfoToAgent', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1208)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SendInfoToClient]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SendInfoToClient]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SendInfoToClient] IS DISTINCT FROM i.[SendInfoToClient])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SendInfoToClient', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1209)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ValueOfWork]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ValueOfWork]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ValueOfWork] IS DISTINCT FROM i.[ValueOfWork])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ValueOfWork', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1381)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_Quotes_AccountAddresses] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_AccountAddresses] FOREIGN KEY ([ClientAddressId]) REFERENCES [SCrm].[AccountAddresses] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_AccountAddresses1] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_AccountAddresses1] FOREIGN KEY ([AgentAddressId]) REFERENCES [SCrm].[AccountAddresses] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_AccountContacts] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_AccountContacts] FOREIGN KEY ([AgentContactId]) REFERENCES [SCrm].[AccountContacts] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_AccountContacts1] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_AccountContacts1] FOREIGN KEY ([ClientContactId]) REFERENCES [SCrm].[AccountContacts] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_Accounts] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_Accounts] FOREIGN KEY ([ClientAccountId]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_Accounts1] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_Accounts1] FOREIGN KEY ([AgentAccountId]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_AgentContractID] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_AgentContractID] FOREIGN KEY ([AgentContractID]) REFERENCES [SSop].[Contracts] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_Contracts] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_Contracts] FOREIGN KEY ([ContractID]) REFERENCES [SSop].[Contracts] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_DataClassifications] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_DataClassifications] FOREIGN KEY ([DataClassificationID]) REFERENCES [SCore].[DataClassifications] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_DataObjects] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid]) ON DELETE CASCADE
GO

PRINT (N'Disable foreign key [FK_Quotes_DataObjects] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes]
  NOCHECK CONSTRAINT [FK_Quotes_DataObjects]
GO

PRINT (N'Create foreign key [FK_Quotes_EnquiryServices] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_EnquiryServices] FOREIGN KEY ([EnquiryServiceID]) REFERENCES [SSop].[EnquiryServices] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_Identities] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_Identities] FOREIGN KEY ([QuotingUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_Identities1] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_Identities1] FOREIGN KEY ([QuotingConsultantId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_JobTypes] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_JobTypes] FOREIGN KEY ([JobTypeId]) REFERENCES [SJob].[JobTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_Markets] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_Markets] FOREIGN KEY ([MarketId]) REFERENCES [SCore].[Markets] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_OrganisationalUnits] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_OrganisationalUnits] FOREIGN KEY ([OrganisationalUnitID]) REFERENCES [SCore].[OrganisationalUnits] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_Projects] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_Projects] FOREIGN KEY ([ProjectId]) REFERENCES [SSop].[Projects] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_Properties] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_Properties] FOREIGN KEY ([UprnId]) REFERENCES [SJob].[Assets] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_QuoteSources] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_QuoteSources] FOREIGN KEY ([QuoteSourceId]) REFERENCES [SSop].[QuoteSources] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_RibaStages] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_RibaStages] FOREIGN KEY ([AppointmentFromRibaStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_RibaStages1] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_RibaStages1] FOREIGN KEY ([CurrentRibaStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_RowStatus] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_Sectors] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_Sectors] FOREIGN KEY ([SectorId]) REFERENCES [SCore].[Sectors] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_SecurityClassifications] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_SecurityClassifications] FOREIGN KEY ([SecurityClassificationID]) REFERENCES [SCore].[SecurityClassifications] ([ID])
GO