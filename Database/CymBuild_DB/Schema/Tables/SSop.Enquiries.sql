PRINT (N'Create table [SSop].[Enquiries]')
GO
PRINT (N'Create table [SSop].[Enquiries]')
GO
CREATE TABLE [SSop].[Enquiries] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Enquiries_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Enquiries_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [OrganisationalUnitID] [int] NOT NULL CONSTRAINT [DF_Enquiries_OrganisationalUnitID] DEFAULT (-1),
  [Date] [datetime2] NOT NULL CONSTRAINT [DF_Enquiries_Date] DEFAULT (getdate()),
  [CreatedByUserId] [int] NOT NULL CONSTRAINT [DF_Enquiries_CreatedByUserId] DEFAULT (-1),
  [Number] [nvarchar](50) NOT NULL CONSTRAINT [DF_Enquiries_Number] DEFAULT (0),
  [Revision] [int] NOT NULL CONSTRAINT [DF_Enquiries_Revision] DEFAULT (0),
  [OriginalEnquiryId] [int] NOT NULL CONSTRAINT [DF_Enquiries_OriginalEnquiryId] DEFAULT (-1),
  [PropertyId] [int] NOT NULL CONSTRAINT [DF_Enquiries_PropertyId] DEFAULT (-1),
  [PropertyNameNumber] [nvarchar](100) NOT NULL CONSTRAINT [DF_Enquiries_PropertyNameNumber] DEFAULT (''),
  [PropertyAddressLine1] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_PropertyAddressLine1] DEFAULT (''),
  [PropertyAddressLine2] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_PropertyAddressLine2] DEFAULT (''),
  [PropertyAddressLine3] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_PropertyAddressLine3] DEFAULT (''),
  [PropertyTown] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_PropertyTown] DEFAULT (''),
  [PropertyCountyId] [int] NOT NULL CONSTRAINT [DF_Enquiries_PropertyCountyId] DEFAULT (-1),
  [PropertyPostCode] [nvarchar](30) NOT NULL CONSTRAINT [DF_Enquiries_PropertyPostCode] DEFAULT (''),
  [PropertyCountryId] [int] NOT NULL CONSTRAINT [DF_Enquiries_PropertyCountryId] DEFAULT (-1),
  [ClientAccountId] [int] NOT NULL CONSTRAINT [DF_Enquiries_ClientAccountId] DEFAULT (-1),
  [ClientAddressId] [int] NOT NULL CONSTRAINT [DF_Enquiries_ClientAddressId] DEFAULT (-1),
  [ClientAccountContactId] [int] NOT NULL CONSTRAINT [DF_Enquiries_ClientAccountContactId] DEFAULT (-1),
  [ClientName] [nvarchar](250) NOT NULL CONSTRAINT [DF_Enquiries_ClientName] DEFAULT (''),
  [ClientAddressNameNumber] [nvarchar](100) NOT NULL CONSTRAINT [DF_Enquiries_ClientAddressNameNumber] DEFAULT (''),
  [ClientAddressLine1] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_ClientAddressLine1] DEFAULT (''),
  [ClientAddressLine2] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_ClientAddressLine2] DEFAULT (''),
  [ClientAddressLine3] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_ClientAddressLine3] DEFAULT (''),
  [ClientAddressTown] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_ClientAdressTown] DEFAULT (''),
  [ClientAddressCountyId] [int] NOT NULL CONSTRAINT [DF_Enquiries_ClientAddressCountyId] DEFAULT (-1),
  [ClientAddressPostCode] [nvarchar](30) NOT NULL CONSTRAINT [DF_Enquiries_ClientAddressPostCode] DEFAULT (''),
  [ClientAddressCountryId] [int] NOT NULL CONSTRAINT [DF_Enquiries_ClientAddressCountryId] DEFAULT (-1),
  [AgentAccountId] [int] NOT NULL CONSTRAINT [DF_Enquiries_AgentAccountId] DEFAULT (-1),
  [AgentAddressId] [int] NOT NULL CONSTRAINT [DF_Enquiries_AgentAddressId] DEFAULT (-1),
  [AgentAccountContactId] [int] NOT NULL CONSTRAINT [DF_Enquiries_AgentAccountContactId] DEFAULT (-1),
  [AgentName] [nvarchar](250) NOT NULL CONSTRAINT [DF_Enquiries_AgentName] DEFAULT (''),
  [AgentAddressNameNumber] [nvarchar](100) NOT NULL CONSTRAINT [DF_Enquiries_AgentAddressNameNumber] DEFAULT (''),
  [AgentAddressLine1] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_AgentAddressLine1] DEFAULT (''),
  [AgentAddressLine2] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_AgentAddressLine2] DEFAULT (''),
  [AgentAddressLine3] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_AgentAddressLine3] DEFAULT (''),
  [AgentTown] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_AgentTown] DEFAULT (''),
  [AgentCountyId] [int] NOT NULL CONSTRAINT [DF_Enquiries_AgentCountyId] DEFAULT (-1),
  [AgentAddressPostCode] [nvarchar](30) NOT NULL CONSTRAINT [DF_Enquiries_AgentAddressPostCode] DEFAULT (''),
  [AgentCountryId] [int] NOT NULL CONSTRAINT [DF_Enquiries_AgentCountryId] DEFAULT (-1),
  [DescriptionOfWorks] [nvarchar](4000) NOT NULL CONSTRAINT [DF_Enquiries_DescriptionOfWorks] DEFAULT (''),
  [ValueOfWork] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Enquiries_ValueOfWork] DEFAULT (0),
  [CurrentProjectRibaStageID] [int] NOT NULL CONSTRAINT [DF_Enquiries_CurrentProjectRibaStageID] DEFAULT (-1),
  [RibaStage0Months] [int] NOT NULL CONSTRAINT [DF_Enquiries_RibaStage0Months] DEFAULT (0),
  [RibaStage1Months] [int] NOT NULL CONSTRAINT [DF_Enquiries_RibaStage1Months] DEFAULT (0),
  [RibaStage2Months] [int] NOT NULL CONSTRAINT [DF_Enquiries_RibaStage2Months] DEFAULT (0),
  [RibaStage3Months] [int] NOT NULL CONSTRAINT [DF_Enquiries_RibaStage3Months] DEFAULT (0),
  [RibaStage4Months] [int] NOT NULL CONSTRAINT [DF_Enquiries_RibaStage4Months] DEFAULT (0),
  [RibaStage5Months] [int] NOT NULL CONSTRAINT [DF_Enquiries_RibaStage5Months] DEFAULT (0),
  [RibaStage6Months] [int] NOT NULL CONSTRAINT [DF_Enquiries_RibaStage6Months] DEFAULT (0),
  [RibaStage7Months] [int] NOT NULL CONSTRAINT [DF_Enquiries_RibaStage7Months] DEFAULT (0),
  [PreConstructionStageMonths] [int] NOT NULL CONSTRAINT [DF_Enquiries_PreConstructionStageMonths] DEFAULT (0),
  [ConstructionStageMonths] [int] NOT NULL CONSTRAINT [DF_Enquiries_ConstructionStageMonths] DEFAULT (0),
  [SendInfoToClient] [bit] NOT NULL CONSTRAINT [DF_Enquiries_SendInfoToClient] DEFAULT (0),
  [SendInfoToAgent] [bit] NOT NULL CONSTRAINT [DF_Enquiries_SendInfoToAgent] DEFAULT (0),
  [KeyDates] [nvarchar](2000) NOT NULL CONSTRAINT [DF_Enquiries_KeyDates] DEFAULT (''),
  [ExpectedProcurementRoute] [nvarchar](200) NOT NULL CONSTRAINT [DF_Enquiries_ExpectedProcurementRoute] DEFAULT (''),
  [Notes] [nvarchar](max) NOT NULL CONSTRAINT [DF_Enquiries_Notes] DEFAULT (''),
  [EnquirySourceId] [int] NOT NULL CONSTRAINT [DF_Enquiries_EnquirySourceId] DEFAULT (-1),
  [IsReadyForQuoteReview] [bit] NOT NULL CONSTRAINT [DF_Enquiries_IsReadyForQuoteReview] DEFAULT (0),
  [QuotingDeadlineDate] [date] NULL,
  [DeclinedToQuoteDate] [date] NULL,
  [DeclinedToQuoteReason] [nvarchar](4000) NOT NULL CONSTRAINT [DF_Enquiries_DeclinedToQuoteReason] DEFAULT (''),
  [ExternalReference] [nvarchar](50) NOT NULL CONSTRAINT [DF_Enquiries_ExternalReference] DEFAULT (''),
  [ProjectId] [int] NOT NULL CONSTRAINT [DF_Enquiries_ProjectId] DEFAULT (-1),
  [IsSubjectToNDA] [bit] NOT NULL CONSTRAINT [DF_Enquiries_IsSubjectToNDA] DEFAULT (0),
  [DeadDate] [date] NULL,
  [ChaseDate1] [date] NULL,
  [ChaseDate2] [date] NULL,
  [IsClientFinanceAccount] [bit] NOT NULL CONSTRAINT [DF_Enquiries_IsClientFinanceAccount] DEFAULT (0),
  [FinanceAccountId] [int] NOT NULL CONSTRAINT [DF_Enquiries_FinanceAccountId] DEFAULT (-1),
  [FinanceAddressId] [int] NOT NULL CONSTRAINT [DF_Enquiries_FinanceAddressId] DEFAULT (-1),
  [FinanceContactId] [int] NOT NULL CONSTRAINT [DF_Enquiries_FinanceContactId] DEFAULT (-1),
  [FinanceAccountName] [nvarchar](250) NOT NULL CONSTRAINT [DF_Enquiries_FinanceAccountName] DEFAULT (''),
  [FinanceAddressNameNumber] [nvarchar](100) NOT NULL CONSTRAINT [DF_Enquiries_FinanceAddressNameNumber] DEFAULT (''),
  [FinanceAddressLine1] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_FinanceAddressLine1] DEFAULT (''),
  [FinanceAddressLine2] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_FinanceAddressLine2] DEFAULT (''),
  [FinanceAddressLine3] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_FinanceAddressLine3] DEFAULT (''),
  [FinanceTown] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_FinanceTown] DEFAULT (''),
  [FinanceCountyId] [int] NOT NULL CONSTRAINT [DF_Enquiries_FinanceCountyId] DEFAULT (-1),
  [FinancePostCode] [nvarchar](30) NOT NULL CONSTRAINT [DF_Enquiries_FinancePostCode] DEFAULT (''),
  [EnterNewClientDetails] [bit] NOT NULL CONSTRAINT [DF_Enquiries_EnterNewClientDetails] DEFAULT (0),
  [EnterNewAgentDetails] [bit] NOT NULL CONSTRAINT [DF_Enquiries_EnterNewAgentDetails] DEFAULT (0),
  [EnterNewFinanceDetails] [bit] NOT NULL CONSTRAINT [DF_Enquiries_EnterNewFinanceDetails] DEFAULT (0),
  [EnterNewStructureDetails] [bit] NOT NULL CONSTRAINT [DF_Enquiries_EntityNewStructureDetails] DEFAULT (0),
  [SignatoryIdentityId] [int] NOT NULL CONSTRAINT [DF_Enquiries_SignatoryIdentityId] DEFAULT (-1),
  [ProposalLetter] [nvarchar](max) NOT NULL CONSTRAINT [DF_Enquiries_ProposalLetter] DEFAULT (''),
  [ClientContactDisplayName] [nvarchar](250) NOT NULL DEFAULT (''),
  [ClientContactDetailType] [smallint] NOT NULL DEFAULT (-1),
  [ClientContactDetailTypeName] [nvarchar](100) NOT NULL DEFAULT (''),
  [ClientContactDetailTypeValue] [nvarchar](250) NOT NULL DEFAULT (''),
  [AgentContactDisplayName] [nvarchar](250) NOT NULL DEFAULT (''),
  [AgentContactDetailType] [smallint] NOT NULL DEFAULT (-1),
  [AgentContactDetailTypeName] [nvarchar](100) NOT NULL DEFAULT (''),
  [AgentContactDetailTypeValue] [nvarchar](250) NOT NULL DEFAULT (''),
  [FinanceContactDisplayName] [nvarchar](250) NOT NULL DEFAULT (''),
  [FinanceContactDetailType] [smallint] NOT NULL DEFAULT (-1),
  [FinanceContactDetailTypeName] [nvarchar](100) NOT NULL DEFAULT (''),
  [FinanceContactDetailTypeValue] [nvarchar](250) NOT NULL DEFAULT (''),
  [ContractID] [int] NOT NULL CONSTRAINT [DF_Enquiries_ContractID] DEFAULT (-1),
  [AgentContractID] [int] NOT NULL CONSTRAINT [DF_Enquiries_AgentContractID] DEFAULT (-1),
  [AssetJSONDetails] [nvarchar](500) NOT NULL CONSTRAINT [DF_Enquiries_AssetJSONDetails] DEFAULT ('')
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Enquiries] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [PK_Enquiries] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_Enquiries_Date] on table [SSop].[Enquiries]')
GO
CREATE INDEX [IX_Enquiries_Date]
  ON [SSop].[Enquiries] ([Date] DESC)
  INCLUDE ([OrganisationalUnitID], [Number], [Revision], [PropertyId], [PropertyNameNumber], [PropertyAddressLine1], [ClientAccountId], [AgentAccountId], [ExternalReference])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SSop_Enquiries_1149450607] on table [SSop].[Enquiries]')
GO
CREATE INDEX [IX_SSop_Enquiries_1149450607]
  ON [SSop].[Enquiries] ([ProjectId])
  INCLUDE ([RowStatus], [RowVersion], [Guid], [Number], [PropertyId], [ClientAccountId], [ClientName], [AgentAccountId], [AgentName], [DescriptionOfWorks], [ExternalReference])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SSop_Enquiries_140435483] on table [SSop].[Enquiries]')
GO
CREATE INDEX [IX_SSop_Enquiries_140435483]
  ON [SSop].[Enquiries] ([RowStatus])
  INCLUDE ([Guid], [PropertyId])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SSop_Enquiries_1669830940] on table [SSop].[Enquiries]')
GO
CREATE INDEX [IX_SSop_Enquiries_1669830940]
  ON [SSop].[Enquiries] ([PropertyId])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SSop_Enquiries_1881690932] on table [SSop].[Enquiries]')
GO
CREATE INDEX [IX_SSop_Enquiries_1881690932]
  ON [SSop].[Enquiries] ([RowStatus])
  INCLUDE ([Guid], [ProjectId])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SSop_Enquiries_1969117338] on table [SSop].[Enquiries]')
GO
CREATE INDEX [IX_SSop_Enquiries_1969117338]
  ON [SSop].[Enquiries] ([PropertyId])
  INCLUDE ([RowStatus], [RowVersion], [Guid], [Number], [ClientAccountId], [ClientName], [AgentAccountId], [AgentName], [DescriptionOfWorks], [ExternalReference])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SSop_Enquiries_1970593348] on table [SSop].[Enquiries]')
GO
CREATE INDEX [IX_SSop_Enquiries_1970593348]
  ON [SSop].[Enquiries] ([ProjectId])
  INCLUDE ([RowStatus], [Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SSop_Enquiries_2106442749] on table [SSop].[Enquiries]')
GO
CREATE INDEX [IX_SSop_Enquiries_2106442749]
  ON [SSop].[Enquiries] ([DeclinedToQuoteDate], [DeadDate], [ID], [RowStatus], [Date])
  INCLUDE ([Guid], [PropertyId], [ClientAccountId], [AgentAccountId])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SSop_Enquiries_56310441] on table [SSop].[Enquiries]')
GO
CREATE INDEX [IX_SSop_Enquiries_56310441]
  ON [SSop].[Enquiries] ([DeclinedToQuoteDate], [DeadDate], [ID], [RowStatus], [Date])
  INCLUDE ([RowVersion], [Guid], [Number], [Revision], [PropertyId], [PropertyNameNumber], [PropertyAddressLine1], [ClientAccountId], [ClientName], [AgentAccountId], [AgentName], [DescriptionOfWorks], [QuotingDeadlineDate], [ExternalReference])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SSop_Enquiries_758767566] on table [SSop].[Enquiries]')
GO
CREATE INDEX [IX_SSop_Enquiries_758767566]
  ON [SSop].[Enquiries] ([PropertyId])
  INCLUDE ([RowStatus], [Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SSop_Enquiries_793073017] on table [SSop].[Enquiries]')
GO
CREATE INDEX [IX_SSop_Enquiries_793073017]
  ON [SSop].[Enquiries] ([ProjectId])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [Ix_UQ_Enquiries_Guid] on table [SSop].[Enquiries]')
GO
CREATE UNIQUE INDEX [Ix_UQ_Enquiries_Guid]
  ON [SSop].[Enquiries] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_Enquiries_RecordHistory] on table [SSop].[Enquiries]')
GO
CREATE TRIGGER [SSop].[tg_Enquiries_RecordHistory]
   ON  [SSop].[Enquiries]	
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
			@TableName NVARCHAR(250) = N'Enquiries',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AgentAccountContactId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AgentAccountContactId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AgentAccountContactId] IS DISTINCT FROM i.[AgentAccountContactId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AgentAccountContactId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1141)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AgentAccountId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AgentAccountId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AgentAccountId] IS DISTINCT FROM i.[AgentAccountId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AgentAccountId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 963)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AgentAddressId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AgentAddressId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AgentAddressId] IS DISTINCT FROM i.[AgentAddressId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AgentAddressId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 964)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AgentAddressLine1]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AgentAddressLine1]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AgentAddressLine1] IS DISTINCT FROM i.[AgentAddressLine1])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AgentAddressLine1', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 965)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AgentAddressLine2]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AgentAddressLine2]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AgentAddressLine2] IS DISTINCT FROM i.[AgentAddressLine2])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AgentAddressLine2', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 966)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AgentAddressLine3]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AgentAddressLine3]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AgentAddressLine3] IS DISTINCT FROM i.[AgentAddressLine3])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AgentAddressLine3', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 967)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AgentAddressNameNumber]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AgentAddressNameNumber]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AgentAddressNameNumber] IS DISTINCT FROM i.[AgentAddressNameNumber])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AgentAddressNameNumber', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 968)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AgentAddressPostCode]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AgentAddressPostCode]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AgentAddressPostCode] IS DISTINCT FROM i.[AgentAddressPostCode])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AgentAddressPostCode', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 969)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AgentContactDetailType]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AgentContactDetailType]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AgentContactDetailType] IS DISTINCT FROM i.[AgentContactDetailType])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AgentContactDetailType', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2150)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AgentContactDetailTypeName]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AgentContactDetailTypeName]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AgentContactDetailTypeName] IS DISTINCT FROM i.[AgentContactDetailTypeName])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AgentContactDetailTypeName', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2151)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AgentContactDetailTypeValue]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AgentContactDetailTypeValue]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AgentContactDetailTypeValue] IS DISTINCT FROM i.[AgentContactDetailTypeValue])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AgentContactDetailTypeValue', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2152)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AgentContactDisplayName]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AgentContactDisplayName]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AgentContactDisplayName] IS DISTINCT FROM i.[AgentContactDisplayName])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AgentContactDisplayName', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2149)
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
				VALUES(1, @SchemaName, @TableName, N'AgentContractID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2171)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AgentCountryId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AgentCountryId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AgentCountryId] IS DISTINCT FROM i.[AgentCountryId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AgentCountryId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 970)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AgentCountyId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AgentCountyId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AgentCountyId] IS DISTINCT FROM i.[AgentCountyId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AgentCountyId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 971)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AgentName]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AgentName]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AgentName] IS DISTINCT FROM i.[AgentName])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AgentName', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 972)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AgentTown]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AgentTown]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AgentTown] IS DISTINCT FROM i.[AgentTown])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AgentTown', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1032)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AssetJSONDetails]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AssetJSONDetails]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AssetJSONDetails] IS DISTINCT FROM i.[AssetJSONDetails])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AssetJSONDetails', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2330)
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
				VALUES(1, @SchemaName, @TableName, N'ChaseDate1', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1825)
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
				VALUES(1, @SchemaName, @TableName, N'ChaseDate2', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1826)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ClientAccountContactId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ClientAccountContactId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ClientAccountContactId] IS DISTINCT FROM i.[ClientAccountContactId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ClientAccountContactId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1142)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ClientAccountId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ClientAccountId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ClientAccountId] IS DISTINCT FROM i.[ClientAccountId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ClientAccountId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 973)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ClientAddressCountryId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ClientAddressCountryId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ClientAddressCountryId] IS DISTINCT FROM i.[ClientAddressCountryId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ClientAddressCountryId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 974)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ClientAddressCountyId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ClientAddressCountyId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ClientAddressCountyId] IS DISTINCT FROM i.[ClientAddressCountyId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ClientAddressCountyId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 975)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ClientAddressId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ClientAddressId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ClientAddressId] IS DISTINCT FROM i.[ClientAddressId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ClientAddressId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 976)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ClientAddressLine1]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ClientAddressLine1]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ClientAddressLine1] IS DISTINCT FROM i.[ClientAddressLine1])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ClientAddressLine1', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 977)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ClientAddressLine2]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ClientAddressLine2]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ClientAddressLine2] IS DISTINCT FROM i.[ClientAddressLine2])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ClientAddressLine2', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 978)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ClientAddressLine3]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ClientAddressLine3]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ClientAddressLine3] IS DISTINCT FROM i.[ClientAddressLine3])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ClientAddressLine3', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 979)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ClientAddressNameNumber]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ClientAddressNameNumber]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ClientAddressNameNumber] IS DISTINCT FROM i.[ClientAddressNameNumber])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ClientAddressNameNumber', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 980)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ClientAddressPostCode]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ClientAddressPostCode]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ClientAddressPostCode] IS DISTINCT FROM i.[ClientAddressPostCode])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ClientAddressPostCode', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 981)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ClientAddressTown]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ClientAddressTown]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ClientAddressTown] IS DISTINCT FROM i.[ClientAddressTown])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ClientAddressTown', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1033)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ClientContactDetailType]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ClientContactDetailType]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ClientContactDetailType] IS DISTINCT FROM i.[ClientContactDetailType])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ClientContactDetailType', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2114)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ClientContactDetailTypeName]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ClientContactDetailTypeName]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ClientContactDetailTypeName] IS DISTINCT FROM i.[ClientContactDetailTypeName])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ClientContactDetailTypeName', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2115)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ClientContactDetailTypeValue]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ClientContactDetailTypeValue]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ClientContactDetailTypeValue] IS DISTINCT FROM i.[ClientContactDetailTypeValue])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ClientContactDetailTypeValue', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2116)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ClientContactDisplayName]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ClientContactDisplayName]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ClientContactDisplayName] IS DISTINCT FROM i.[ClientContactDisplayName])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ClientContactDisplayName', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2113)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ClientName]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ClientName]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ClientName] IS DISTINCT FROM i.[ClientName])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ClientName', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 982)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ConstructionStageMonths]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ConstructionStageMonths]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ConstructionStageMonths] IS DISTINCT FROM i.[ConstructionStageMonths])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ConstructionStageMonths', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1205)
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
				VALUES(1, @SchemaName, @TableName, N'ContractID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2170)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CreatedByUserId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CreatedByUserId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CreatedByUserId] IS DISTINCT FROM i.[CreatedByUserId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CreatedByUserId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 983)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CurrentProjectRibaStageID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CurrentProjectRibaStageID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CurrentProjectRibaStageID] IS DISTINCT FROM i.[CurrentProjectRibaStageID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CurrentProjectRibaStageID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 984)
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
				VALUES(1, @SchemaName, @TableName, N'Date', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 985)
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
				VALUES(1, @SchemaName, @TableName, N'DeadDate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1694)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DeclinedToQuoteDate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DeclinedToQuoteDate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DeclinedToQuoteDate] IS DISTINCT FROM i.[DeclinedToQuoteDate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DeclinedToQuoteDate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1213)
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
				VALUES(1, @SchemaName, @TableName, N'DeclinedToQuoteReason', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1214)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DescriptionOfWorks]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DescriptionOfWorks]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DescriptionOfWorks] IS DISTINCT FROM i.[DescriptionOfWorks])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DescriptionOfWorks', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 986)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[EnquirySourceId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[EnquirySourceId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[EnquirySourceId] IS DISTINCT FROM i.[EnquirySourceId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EnquirySourceId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1034)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[EnterNewAgentDetails]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[EnterNewAgentDetails]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[EnterNewAgentDetails] IS DISTINCT FROM i.[EnterNewAgentDetails])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EnterNewAgentDetails', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1838)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[EnterNewClientDetails]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[EnterNewClientDetails]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[EnterNewClientDetails] IS DISTINCT FROM i.[EnterNewClientDetails])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EnterNewClientDetails', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1839)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[EnterNewFinanceDetails]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[EnterNewFinanceDetails]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[EnterNewFinanceDetails] IS DISTINCT FROM i.[EnterNewFinanceDetails])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EnterNewFinanceDetails', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1840)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[EnterNewStructureDetails]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[EnterNewStructureDetails]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[EnterNewStructureDetails] IS DISTINCT FROM i.[EnterNewStructureDetails])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EnterNewStructureDetails', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1841)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ExpectedProcurementRoute]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ExpectedProcurementRoute]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ExpectedProcurementRoute] IS DISTINCT FROM i.[ExpectedProcurementRoute])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ExpectedProcurementRoute', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 987)
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
				VALUES(1, @SchemaName, @TableName, N'ExternalReference', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1215)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FinanceAccountId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FinanceAccountId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FinanceAccountId] IS DISTINCT FROM i.[FinanceAccountId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FinanceAccountId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1827)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FinanceAccountName]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FinanceAccountName]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FinanceAccountName] IS DISTINCT FROM i.[FinanceAccountName])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FinanceAccountName', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1828)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FinanceAddressId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FinanceAddressId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FinanceAddressId] IS DISTINCT FROM i.[FinanceAddressId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FinanceAddressId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1829)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FinanceAddressLine1]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FinanceAddressLine1]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FinanceAddressLine1] IS DISTINCT FROM i.[FinanceAddressLine1])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FinanceAddressLine1', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1830)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FinanceAddressLine2]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FinanceAddressLine2]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FinanceAddressLine2] IS DISTINCT FROM i.[FinanceAddressLine2])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FinanceAddressLine2', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1831)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FinanceAddressLine3]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FinanceAddressLine3]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FinanceAddressLine3] IS DISTINCT FROM i.[FinanceAddressLine3])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FinanceAddressLine3', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1832)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FinanceAddressNameNumber]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FinanceAddressNameNumber]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FinanceAddressNameNumber] IS DISTINCT FROM i.[FinanceAddressNameNumber])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FinanceAddressNameNumber', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1833)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FinanceContactDetailType]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FinanceContactDetailType]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FinanceContactDetailType] IS DISTINCT FROM i.[FinanceContactDetailType])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FinanceContactDetailType', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2154)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FinanceContactDetailTypeName]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FinanceContactDetailTypeName]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FinanceContactDetailTypeName] IS DISTINCT FROM i.[FinanceContactDetailTypeName])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FinanceContactDetailTypeName', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2155)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FinanceContactDetailTypeValue]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FinanceContactDetailTypeValue]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FinanceContactDetailTypeValue] IS DISTINCT FROM i.[FinanceContactDetailTypeValue])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FinanceContactDetailTypeValue', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2156)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FinanceContactDisplayName]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FinanceContactDisplayName]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FinanceContactDisplayName] IS DISTINCT FROM i.[FinanceContactDisplayName])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FinanceContactDisplayName', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2153)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FinanceContactId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FinanceContactId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FinanceContactId] IS DISTINCT FROM i.[FinanceContactId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FinanceContactId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1834)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FinanceCountyId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FinanceCountyId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FinanceCountyId] IS DISTINCT FROM i.[FinanceCountyId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FinanceCountyId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1835)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FinancePostCode]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FinancePostCode]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FinancePostCode] IS DISTINCT FROM i.[FinancePostCode])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FinancePostCode', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1836)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FinanceTown]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FinanceTown]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FinanceTown] IS DISTINCT FROM i.[FinanceTown])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FinanceTown', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1851)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsClientFinanceAccount]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsClientFinanceAccount]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsClientFinanceAccount] IS DISTINCT FROM i.[IsClientFinanceAccount])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsClientFinanceAccount', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1837)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsReadyForQuoteReview]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsReadyForQuoteReview]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsReadyForQuoteReview] IS DISTINCT FROM i.[IsReadyForQuoteReview])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsReadyForQuoteReview', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1073)
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
				VALUES(1, @SchemaName, @TableName, N'IsSubjectToNDA', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1693)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[KeyDates]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[KeyDates]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[KeyDates] IS DISTINCT FROM i.[KeyDates])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'KeyDates', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 990)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Notes]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Notes]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Notes] IS DISTINCT FROM i.[Notes])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Notes', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 991)
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
				VALUES(1, @SchemaName, @TableName, N'Number', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 992)
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
				VALUES(1, @SchemaName, @TableName, N'OrganisationalUnitID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 993)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PreConstructionStageMonths]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PreConstructionStageMonths]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PreConstructionStageMonths] IS DISTINCT FROM i.[PreConstructionStageMonths])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PreConstructionStageMonths', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1206)
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
				VALUES(1, @SchemaName, @TableName, N'ProjectId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1228)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PropertyAddressLine1]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PropertyAddressLine1]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PropertyAddressLine1] IS DISTINCT FROM i.[PropertyAddressLine1])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PropertyAddressLine1', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 994)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PropertyAddressLine2]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PropertyAddressLine2]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PropertyAddressLine2] IS DISTINCT FROM i.[PropertyAddressLine2])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PropertyAddressLine2', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 995)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PropertyAddressLine3]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PropertyAddressLine3]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PropertyAddressLine3] IS DISTINCT FROM i.[PropertyAddressLine3])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PropertyAddressLine3', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 996)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PropertyCountryId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PropertyCountryId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PropertyCountryId] IS DISTINCT FROM i.[PropertyCountryId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PropertyCountryId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 997)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PropertyCountyId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PropertyCountyId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PropertyCountyId] IS DISTINCT FROM i.[PropertyCountyId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PropertyCountyId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 998)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PropertyId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PropertyId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PropertyId] IS DISTINCT FROM i.[PropertyId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PropertyId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 999)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PropertyNameNumber]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PropertyNameNumber]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PropertyNameNumber] IS DISTINCT FROM i.[PropertyNameNumber])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PropertyNameNumber', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1000)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PropertyPostCode]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PropertyPostCode]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PropertyPostCode] IS DISTINCT FROM i.[PropertyPostCode])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PropertyPostCode', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1001)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PropertyTown]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PropertyTown]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PropertyTown] IS DISTINCT FROM i.[PropertyTown])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PropertyTown', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1035)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ProposalLetter]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ProposalLetter]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ProposalLetter] IS DISTINCT FROM i.[ProposalLetter])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ProposalLetter', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1859)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[QuotingDeadlineDate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[QuotingDeadlineDate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[QuotingDeadlineDate] IS DISTINCT FROM i.[QuotingDeadlineDate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'QuotingDeadlineDate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1212)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage0Months]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage0Months]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage0Months] IS DISTINCT FROM i.[RibaStage0Months])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage0Months', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1002)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage1Months]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage1Months]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage1Months] IS DISTINCT FROM i.[RibaStage1Months])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage1Months', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1003)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage2Months]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage2Months]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage2Months] IS DISTINCT FROM i.[RibaStage2Months])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage2Months', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1004)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage3Months]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage3Months]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage3Months] IS DISTINCT FROM i.[RibaStage3Months])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage3Months', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1005)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage4Months]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage4Months]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage4Months] IS DISTINCT FROM i.[RibaStage4Months])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage4Months', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1006)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage5Months]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage5Months]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage5Months] IS DISTINCT FROM i.[RibaStage5Months])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage5Months', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1007)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage6Months]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage6Months]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage6Months] IS DISTINCT FROM i.[RibaStage6Months])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage6Months', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1008)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage7Months]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage7Months]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage7Months] IS DISTINCT FROM i.[RibaStage7Months])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage7Months', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1009)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1010)
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
				VALUES(1, @SchemaName, @TableName, N'SendInfoToAgent', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1012)
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
				VALUES(1, @SchemaName, @TableName, N'SendInfoToClient', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1013)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SignatoryIdentityId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SignatoryIdentityId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SignatoryIdentityId] IS DISTINCT FROM i.[SignatoryIdentityId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SignatoryIdentityId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1860)
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
				VALUES(1, @SchemaName, @TableName, N'ValueOfWork', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1014)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_Enquiries_AccountAddresses] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_AccountAddresses] FOREIGN KEY ([FinanceAddressId]) REFERENCES [SCrm].[AccountAddresses] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_AccountContacts] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_AccountContacts] FOREIGN KEY ([AgentAccountContactId]) REFERENCES [SCrm].[AccountContacts] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_AccountContacts1] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_AccountContacts1] FOREIGN KEY ([ClientAccountContactId]) REFERENCES [SCrm].[AccountContacts] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_AccountContacts2] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_AccountContacts2] FOREIGN KEY ([FinanceContactId]) REFERENCES [SCrm].[AccountContacts] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Accounts] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Accounts] FOREIGN KEY ([ClientAccountId]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Accounts1] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Accounts1] FOREIGN KEY ([AgentAccountId]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Accounts2] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Accounts2] FOREIGN KEY ([FinanceAccountId]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Addresses] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Addresses] FOREIGN KEY ([ClientAddressId]) REFERENCES [SCrm].[AccountAddresses] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Addresses1] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Addresses1] FOREIGN KEY ([AgentAddressId]) REFERENCES [SCrm].[AccountAddresses] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_AgentContractID] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_AgentContractID] FOREIGN KEY ([AgentContractID]) REFERENCES [SSop].[Contracts] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_ContractID] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_ContractID] FOREIGN KEY ([ContractID]) REFERENCES [SSop].[Contracts] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Counties] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Counties] FOREIGN KEY ([PropertyCountyId]) REFERENCES [SCrm].[Counties] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Counties1] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Counties1] FOREIGN KEY ([ClientAddressCountyId]) REFERENCES [SCrm].[Counties] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Counties2] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Counties2] FOREIGN KEY ([AgentCountyId]) REFERENCES [SCrm].[Counties] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Countries] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Countries] FOREIGN KEY ([PropertyCountryId]) REFERENCES [SCrm].[Countries] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Countries1] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Countries1] FOREIGN KEY ([ClientAddressCountryId]) REFERENCES [SCrm].[Countries] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Countries2] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Countries2] FOREIGN KEY ([AgentCountryId]) REFERENCES [SCrm].[Countries] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_DataObjects] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid]) ON DELETE CASCADE
GO

PRINT (N'Disable foreign key [FK_Enquiries_DataObjects] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries]
  NOCHECK CONSTRAINT [FK_Enquiries_DataObjects]
GO

PRINT (N'Create foreign key [FK_Enquiries_Identities] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Identities] FOREIGN KEY ([CreatedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Identities1] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Identities1] FOREIGN KEY ([SignatoryIdentityId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_OrganisationalUnits] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_OrganisationalUnits] FOREIGN KEY ([OrganisationalUnitID]) REFERENCES [SCore].[OrganisationalUnits] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Projects] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Projects] FOREIGN KEY ([ProjectId]) REFERENCES [SSop].[Projects] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Properties] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Properties] FOREIGN KEY ([PropertyId]) REFERENCES [SJob].[Assets] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_QuoteSources] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_QuoteSources] FOREIGN KEY ([EnquirySourceId]) REFERENCES [SSop].[QuoteSources] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_RibaStages] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_RibaStages] FOREIGN KEY ([CurrentProjectRibaStageID]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_RowStatus] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO