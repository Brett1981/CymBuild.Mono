SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create table [SJob].[Jobs]')
GO
SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create table [SJob].[Jobs]')
GO
CREATE TABLE [SJob].[Jobs] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Jobs_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Jobs_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [OrganisationalUnitID] [int] NOT NULL CONSTRAINT [DF_Jobs_OrganisationalUnitID] DEFAULT (-1),
  [JobTypeID] [int] NOT NULL CONSTRAINT [DF_Jobs_JobTypeID] DEFAULT (-1),
  [Number] [nvarchar](50) NOT NULL CONSTRAINT [DF_Jobs_Number] DEFAULT (0),
  [UprnID] [int] NOT NULL CONSTRAINT [DF_Jobs_UprnID] DEFAULT (-1),
  [ClientAccountID] [int] NOT NULL CONSTRAINT [DF_Jobs_ClientAccountID] DEFAULT (-1),
  [ClientAddressID] [int] NOT NULL CONSTRAINT [DF_Jobs_ClientAddressID] DEFAULT (-1),
  [ClientContactID] [int] NOT NULL CONSTRAINT [DF_Jobs_ClientContactID] DEFAULT (-1),
  [AgentAccountID] [int] NOT NULL CONSTRAINT [DF_Jobs_AgentAccountID] DEFAULT (-1),
  [AgentAddressID] [int] NOT NULL CONSTRAINT [DF_Jobs_AgentAddressID] DEFAULT (-1),
  [AgentContactID] [int] NOT NULL CONSTRAINT [DF_Jobs_AgentContactID] DEFAULT (-1),
  [FinanceAccountID] [int] NOT NULL CONSTRAINT [DF_Jobs_FinanceAccountID] DEFAULT (-1),
  [FinanceAddressID] [int] NOT NULL CONSTRAINT [DF_Jobs_FinanceAddressID] DEFAULT (-1),
  [FinanceContactID] [int] NOT NULL CONSTRAINT [DF_Jobs_FinanceContactID] DEFAULT (-1),
  [SurveyorID] [int] NOT NULL CONSTRAINT [DF_Jobs_SurveyorID] DEFAULT (-1),
  [JobDescription] [nvarchar](1000) NOT NULL CONSTRAINT [DF_Jobs_JobDescription] DEFAULT (''),
  [IsSubjectToNDA] [bit] NOT NULL CONSTRAINT [DF_Jobs_IsSubjectToNDA] DEFAULT (0),
  [JobStarted] [datetime2] NULL,
  [JobCompleted] [datetime2] NULL,
  [JobCancelled] [datetime2] NULL,
  [ValueOfWorkID] [smallint] NOT NULL CONSTRAINT [DF_Jobs_ValueOfWorkID] DEFAULT (-1),
  [RibaStage1Fee] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Jobs_RibaStage1Fee] DEFAULT (0),
  [RibaStage2Fee] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Jobs_RibaStage2Fee] DEFAULT (0),
  [RibaStage3Fee] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Jobs_RibaStage3Fee] DEFAULT (0),
  [RibaStage4Fee] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Jobs_RibaStage4Fee] DEFAULT (0),
  [RibaStage5Fee] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Jobs_RibaStage5Fee] DEFAULT (0),
  [RibaStage6Fee] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Jobs_RibaStage6Fee] DEFAULT (0),
  [RibaStage7Fee] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Jobs_RibaStage7Fee] DEFAULT (0),
  [PreConstructionStageFee] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Jobs_PreConstructionStageFee] DEFAULT (0),
  [ConstructionStageFee] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Jobs_ConstructionStageFee] DEFAULT (0),
  [AgreedFee] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Jobs_AgreedFee] DEFAULT (0),
  [FeeCap] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Jobs_FeeCap] DEFAULT (0),
  [ArchiveReferenceLink] [nvarchar](500) NOT NULL CONSTRAINT [DF_Jobs_ArchiveReferenceLink] DEFAULT (''),
  [ArchiveBoxReference] [nvarchar](100) NOT NULL CONSTRAINT [DF_Jobs_ArchiveBoxReference] DEFAULT (''),
  [CreatedByUserID] [int] NOT NULL CONSTRAINT [DF_Jobs_CreatedByUserID] DEFAULT (-1),
  [CreatedOn] [datetime2] NULL,
  [ExternalReference] [nvarchar](50) NOT NULL CONSTRAINT [DF_Jobs_ExternalReference] DEFAULT (''),
  [VersionID] [int] NOT NULL CONSTRAINT [DF_Jobs_VersionID] DEFAULT (-1),
  [IsCompleteForReview] [bit] NOT NULL CONSTRAINT [DF_Jobs_IsCompleteForReview] DEFAULT (0),
  [ReviewedByUserID] [int] NOT NULL CONSTRAINT [DF_Jobs_ReviewedByUserID] DEFAULT (-1),
  [ReviewedDateTimeUTC] [datetime2] NULL,
  [LegacyID] [int] NULL,
  [ContractID] [int] NOT NULL CONSTRAINT [DF_Jobs_ContractID] DEFAULT (-1),
  [AppFormReceived] [bit] NOT NULL CONSTRAINT [DF_Jobs_AppFormReceived] DEFAULT (0),
  [CurrentRibaStageId] [int] NOT NULL CONSTRAINT [DF_Jobs_CurrentRibaStageId] DEFAULT (-1),
  [AppointedFromStageId] [int] NOT NULL CONSTRAINT [DF_Jobs_AppointedFromStageId] DEFAULT (-1),
  [JobDormant] [datetime2] NULL,
  [PurchaseOrderNumber] [nvarchar](28) NOT NULL CONSTRAINT [DF_Jobs_PurchaseOrderNumber] DEFAULT (''),
  [ProjectId] [int] NOT NULL CONSTRAINT [DF_Jobs_ProjectId] DEFAULT (-1),
  [ValueOfWork] [decimal](19, 2) NOT NULL CONSTRAINT [DF__Jobs__ValueOfWor__58F2C25C] DEFAULT (0),
  [ClientAppointmentReceived] [bit] NOT NULL CONSTRAINT [DF__Jobs__ClientAppo__78015961] DEFAULT (0),
  [DeadDate] [date] NULL,
  [IsActive] AS (CONVERT([bit],case when [JobCompleted] IS NULL AND [JobCancelled] IS NULL AND [JobDormant] IS NULL AND [DeadDate] IS NULL then (1) else (0) end)) PERSISTED,
  [IsComplete] AS (CONVERT([bit],case when [JobCompleted] IS NOT NULL OR [JobCancelled] IS NOT NULL OR [DeadDate] IS NOT NULL then (1) else (0) end)) PERSISTED,
  [IsCancelled] AS (CONVERT([bit],case when [JobCancelled] IS NOT NULL then (1) else (0) end)) PERSISTED,
  [IsPendingCompletion] AS (CONVERT([bit],case when [IsCompleteForReview]=(1) OR [ReviewedByUserID]>(0) then (1) else (0) end)) PERSISTED,
  [LegacySystemID] [int] NOT NULL DEFAULT (-1),
  [BillingInstruction] [nvarchar](max) NULL CONSTRAINT [DF_Jobs_BillingInstruction] DEFAULT (''),
  [CannotBeInvoiced] [bit] NOT NULL CONSTRAINT [DF_Jobs_CannotBeInvoiced] DEFAULT (0),
  [CannotBeInvoicedReason] [nvarchar](max) NOT NULL CONSTRAINT [DF_Jobs_CannotBeInvoicedReason] DEFAULT (''),
  [AgentContractID] [int] NOT NULL CONSTRAINT [DF_Jobs_AgentContractID] DEFAULT (-1),
  [CompletedForReviewDate] [datetime] NULL CONSTRAINT [DF_Jobs_CompletedForReviewDate] DEFAULT (NULL),
  [SectorId] [int] NOT NULL CONSTRAINT [DF_Jobs_SectorId] DEFAULT (-1),
  [MarketId] [int] NOT NULL CONSTRAINT [DF_Jobs_MarketId] DEFAULT (-1),
  [ManualInvoicingEnabled] [bit] NOT NULL CONSTRAINT [DF_Jobs_ManualInvoicingEnabled] DEFAULT (0),
  [InvoiceProcessingMode] [tinyint] NOT NULL CONSTRAINT [DF_Jobs_InvoiceProcessingMode] DEFAULT (1),
  [InvoicingPausedByCreditHold] [bit] NOT NULL DEFAULT (0),
  [DataClassificationID] [int] NOT NULL CONSTRAINT [DF_Jobs_DataClassificationID] DEFAULT (-1),
  [SecurityClassificationID] [int] NOT NULL CONSTRAINT [DF_Jobs_SecurityClassificationID] DEFAULT (-1)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Jobs] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [PK_Jobs] PRIMARY KEY CLUSTERED ([ID])
GO

PRINT (N'Create check constraint [CK_Jobs_InvoiceProcessingMode] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [CK_Jobs_InvoiceProcessingMode] CHECK ([InvoiceProcessingMode]=(2) OR [InvoiceProcessingMode]=(1) OR [InvoiceProcessingMode]=(0))
GO

PRINT (N'Create index [IX_Jobs_AgentAccountID] on table [SJob].[Jobs]')
GO
CREATE INDEX [IX_Jobs_AgentAccountID]
  ON [SJob].[Jobs] ([AgentAccountID])
  INCLUDE ([RowStatus], [Guid], [Number])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Jobs_Finance] on table [SJob].[Jobs]')
GO
CREATE INDEX [IX_Jobs_Finance]
  ON [SJob].[Jobs] ([FinanceAccountID], [Guid], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Jobs_Status] on table [SJob].[Jobs]')
GO
CREATE INDEX [IX_Jobs_Status]
  ON [SJob].[Jobs] ([IsActive], [IsComplete], [IsCancelled], [IsPendingCompletion], [RowStatus])
  INCLUDE ([UprnID], [SurveyorID], [Guid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Jobs_Surveyor] on table [SJob].[Jobs]')
GO
CREATE INDEX [IX_Jobs_Surveyor]
  ON [SJob].[Jobs] ([SurveyorID], [RowStatus])
  INCLUDE ([Guid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_Jobs_Guid] on table [SJob].[Jobs]')
GO
CREATE UNIQUE INDEX [IX_UQ_Jobs_Guid]
  ON [SJob].[Jobs] ([Guid])
  INCLUDE ([RowStatus])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_Jobs_Number] on table [SJob].[Jobs]')
GO
CREATE UNIQUE INDEX [IX_UQ_Jobs_Number]
  ON [SJob].[Jobs] ([Number], [RowStatus])
  WHERE ([RowStatus]<>(0))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_Jobs_RecordHistory] on table [SJob].[Jobs]')
GO
CREATE TRIGGER [SJob].[tg_Jobs_RecordHistory]
   ON  [SJob].[Jobs]	
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
			@TableName NVARCHAR(250) = N'Jobs',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AgentAccountID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AgentAccountID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AgentAccountID] IS DISTINCT FROM i.[AgentAccountID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AgentAccountID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 93)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AgentAddressID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AgentAddressID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AgentAddressID] IS DISTINCT FROM i.[AgentAddressID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AgentAddressID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 783)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AgentContactID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AgentContactID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AgentContactID] IS DISTINCT FROM i.[AgentContactID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AgentContactID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 94)
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
				VALUES(1, @SchemaName, @TableName, N'AgentContractID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2161)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AgreedFee]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AgreedFee]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AgreedFee] IS DISTINCT FROM i.[AgreedFee])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AgreedFee', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 105)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AppFormReceived]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AppFormReceived]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AppFormReceived] IS DISTINCT FROM i.[AppFormReceived])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AppFormReceived', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 877)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AppointedFromStageId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AppointedFromStageId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AppointedFromStageId] IS DISTINCT FROM i.[AppointedFromStageId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AppointedFromStageId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1692)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ArchiveBoxReference]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ArchiveBoxReference]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ArchiveBoxReference] IS DISTINCT FROM i.[ArchiveBoxReference])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ArchiveBoxReference', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 108)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ArchiveReferenceLink]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ArchiveReferenceLink]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ArchiveReferenceLink] IS DISTINCT FROM i.[ArchiveReferenceLink])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ArchiveReferenceLink', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 107)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[BillingInstruction]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[BillingInstruction]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[BillingInstruction] IS DISTINCT FROM i.[BillingInstruction])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'BillingInstruction', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2029)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CannotBeInvoiced]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CannotBeInvoiced]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CannotBeInvoiced] IS DISTINCT FROM i.[CannotBeInvoiced])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CannotBeInvoiced', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2158)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CannotBeInvoicedReason]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CannotBeInvoicedReason]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CannotBeInvoicedReason] IS DISTINCT FROM i.[CannotBeInvoicedReason])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CannotBeInvoicedReason', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2159)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ClientAccountID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ClientAccountID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ClientAccountID] IS DISTINCT FROM i.[ClientAccountID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ClientAccountID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 91)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ClientAddressID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ClientAddressID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ClientAddressID] IS DISTINCT FROM i.[ClientAddressID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ClientAddressID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 784)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ClientAppointmentReceived]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ClientAppointmentReceived]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ClientAppointmentReceived] IS DISTINCT FROM i.[ClientAppointmentReceived])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ClientAppointmentReceived', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1396)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ClientContactID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ClientContactID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ClientContactID] IS DISTINCT FROM i.[ClientContactID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ClientContactID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 92)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CompletedForReviewDate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CompletedForReviewDate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CompletedForReviewDate] IS DISTINCT FROM i.[CompletedForReviewDate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CompletedForReviewDate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2174)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ConstructionStageFee]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ConstructionStageFee]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ConstructionStageFee] IS DISTINCT FROM i.[ConstructionStageFee])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ConstructionStageFee', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1175)
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
				VALUES(1, @SchemaName, @TableName, N'ContractID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 607)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CreatedByUserID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CreatedByUserID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CreatedByUserID] IS DISTINCT FROM i.[CreatedByUserID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CreatedByUserID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 110)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CreatedOn]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CreatedOn]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CreatedOn] IS DISTINCT FROM i.[CreatedOn])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CreatedOn', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 111)
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
				VALUES(1, @SchemaName, @TableName, N'CurrentRibaStageId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1025)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DataClassificationID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DataClassificationID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DataClassificationID] IS DISTINCT FROM i.[DataClassificationID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DataClassificationID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2840)
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
				VALUES(1, @SchemaName, @TableName, N'DeadDate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1696)
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
				VALUES(1, @SchemaName, @TableName, N'ExternalReference', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 112)
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
				VALUES(1, @SchemaName, @TableName, N'FeeCap', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 878)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FinanceAccountID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FinanceAccountID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FinanceAccountID] IS DISTINCT FROM i.[FinanceAccountID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FinanceAccountID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1155)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FinanceAddressID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FinanceAddressID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FinanceAddressID] IS DISTINCT FROM i.[FinanceAddressID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FinanceAddressID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1156)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FinanceContactID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FinanceContactID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FinanceContactID] IS DISTINCT FROM i.[FinanceContactID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FinanceContactID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1157)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[InvoiceProcessingMode]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[InvoiceProcessingMode]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[InvoiceProcessingMode] IS DISTINCT FROM i.[InvoiceProcessingMode])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'InvoiceProcessingMode', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2597)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsCompleteForReview]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsCompleteForReview]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsCompleteForReview] IS DISTINCT FROM i.[IsCompleteForReview])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsCompleteForReview', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 601)
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
				VALUES(1, @SchemaName, @TableName, N'IsSubjectToNDA', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 100)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[JobCancelled]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[JobCancelled]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[JobCancelled] IS DISTINCT FROM i.[JobCancelled])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'JobCancelled', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 103)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[JobCompleted]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[JobCompleted]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[JobCompleted] IS DISTINCT FROM i.[JobCompleted])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'JobCompleted', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 102)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[JobDescription]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[JobDescription]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[JobDescription] IS DISTINCT FROM i.[JobDescription])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'JobDescription', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 98)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[JobDormant]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[JobDormant]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[JobDormant] IS DISTINCT FROM i.[JobDormant])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'JobDormant', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1026)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[JobStarted]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[JobStarted]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[JobStarted] IS DISTINCT FROM i.[JobStarted])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'JobStarted', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 101)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[JobTypeID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[JobTypeID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[JobTypeID] IS DISTINCT FROM i.[JobTypeID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'JobTypeID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 88)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[LegacyID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[LegacyID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[LegacyID] IS DISTINCT FROM i.[LegacyID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'LegacyID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 602)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ManualInvoicingEnabled]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ManualInvoicingEnabled]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ManualInvoicingEnabled] IS DISTINCT FROM i.[ManualInvoicingEnabled])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ManualInvoicingEnabled', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2598)
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
				VALUES(1, @SchemaName, @TableName, N'MarketId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2570)
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
				VALUES(1, @SchemaName, @TableName, N'Number', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 89)
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
				VALUES(1, @SchemaName, @TableName, N'OrganisationalUnitID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 87)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PreConstructionStageFee]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PreConstructionStageFee]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PreConstructionStageFee] IS DISTINCT FROM i.[PreConstructionStageFee])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PreConstructionStageFee', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1176)
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
				VALUES(1, @SchemaName, @TableName, N'ProjectId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1230)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PurchaseOrderNumber]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PurchaseOrderNumber]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PurchaseOrderNumber] IS DISTINCT FROM i.[PurchaseOrderNumber])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PurchaseOrderNumber', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1158)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ReviewedByUserID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ReviewedByUserID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ReviewedByUserID] IS DISTINCT FROM i.[ReviewedByUserID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ReviewedByUserID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 603)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ReviewedDateTimeUTC]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ReviewedDateTimeUTC]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ReviewedDateTimeUTC] IS DISTINCT FROM i.[ReviewedDateTimeUTC])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ReviewedDateTimeUTC', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 604)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage1Fee]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage1Fee]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage1Fee] IS DISTINCT FROM i.[RibaStage1Fee])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage1Fee', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 869)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage2Fee]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage2Fee]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage2Fee] IS DISTINCT FROM i.[RibaStage2Fee])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage2Fee', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 870)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage3Fee]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage3Fee]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage3Fee] IS DISTINCT FROM i.[RibaStage3Fee])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage3Fee', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 871)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage4Fee]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage4Fee]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage4Fee] IS DISTINCT FROM i.[RibaStage4Fee])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage4Fee', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 872)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage5Fee]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage5Fee]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage5Fee] IS DISTINCT FROM i.[RibaStage5Fee])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage5Fee', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 873)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage6Fee]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage6Fee]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage6Fee] IS DISTINCT FROM i.[RibaStage6Fee])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage6Fee', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 874)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStage7Fee]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStage7Fee]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStage7Fee] IS DISTINCT FROM i.[RibaStage7Fee])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStage7Fee', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 875)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 84)
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
				VALUES(1, @SchemaName, @TableName, N'SectorId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2558)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SecurityClassificationID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SecurityClassificationID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SecurityClassificationID] IS DISTINCT FROM i.[SecurityClassificationID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SecurityClassificationID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2841)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SurveyorID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SurveyorID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SurveyorID] IS DISTINCT FROM i.[SurveyorID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SurveyorID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 95)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[UprnID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[UprnID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[UprnID] IS DISTINCT FROM i.[UprnID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'UprnID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 90)
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
				VALUES(1, @SchemaName, @TableName, N'ValueOfWork', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1380)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ValueOfWorkID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ValueOfWorkID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ValueOfWorkID] IS DISTINCT FROM i.[ValueOfWorkID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ValueOfWorkID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 104)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[VersionID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[VersionID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[VersionID] IS DISTINCT FROM i.[VersionID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'VersionID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 113)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_Jobs_Accounts] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Accounts] FOREIGN KEY ([AgentAccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Accounts1] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Accounts1] FOREIGN KEY ([ClientAccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Accounts2] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Accounts2] FOREIGN KEY ([FinanceAccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Addresses] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Addresses] FOREIGN KEY ([ClientAddressID]) REFERENCES [SCrm].[AccountAddresses] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Addresses1] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Addresses1] FOREIGN KEY ([AgentAddressID]) REFERENCES [SCrm].[AccountAddresses] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Addresses2] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Addresses2] FOREIGN KEY ([FinanceAddressID]) REFERENCES [SCrm].[AccountAddresses] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_AgentContractID] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_AgentContractID] FOREIGN KEY ([AgentContractID]) REFERENCES [SSop].[Contracts] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Contacts] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Contacts] FOREIGN KEY ([AgentContactID]) REFERENCES [SCrm].[AccountContacts] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Contacts1] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Contacts1] FOREIGN KEY ([ClientContactID]) REFERENCES [SCrm].[AccountContacts] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Contacts3] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Contacts3] FOREIGN KEY ([FinanceContactID]) REFERENCES [SCrm].[AccountContacts] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Contracts] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Contracts] FOREIGN KEY ([ContractID]) REFERENCES [SSop].[Contracts] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_DataClassifications] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_DataClassifications] FOREIGN KEY ([DataClassificationID]) REFERENCES [SCore].[DataClassifications] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_DataObjects] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_Jobs_DataObjects] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs]
  NOCHECK CONSTRAINT [FK_Jobs_DataObjects]
GO

PRINT (N'Create foreign key [FK_Jobs_Identities] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Identities] FOREIGN KEY ([SurveyorID]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Identities1] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Identities1] FOREIGN KEY ([CreatedByUserID]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Identities2] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Identities2] FOREIGN KEY ([ReviewedByUserID]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_JobTypes] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_JobTypes] FOREIGN KEY ([JobTypeID]) REFERENCES [SJob].[JobTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Markets] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Markets] FOREIGN KEY ([MarketId]) REFERENCES [SCore].[Markets] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_OrganisationalUnits] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_OrganisationalUnits] FOREIGN KEY ([OrganisationalUnitID]) REFERENCES [SCore].[OrganisationalUnits] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Projects] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Projects] FOREIGN KEY ([ProjectId]) REFERENCES [SSop].[Projects] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Properties] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Properties] FOREIGN KEY ([UprnID]) REFERENCES [SJob].[Assets] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_RibaStages] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_RibaStages] FOREIGN KEY ([CurrentRibaStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_RibaStages1] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_RibaStages1] FOREIGN KEY ([AppointedFromStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_RowStatus] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Sectors] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Sectors] FOREIGN KEY ([SectorId]) REFERENCES [SCore].[Sectors] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_SecurityClassifications] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_SecurityClassifications] FOREIGN KEY ([SecurityClassificationID]) REFERENCES [SCore].[SecurityClassifications] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_ValuesOfWork] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_ValuesOfWork] FOREIGN KEY ([ValueOfWorkID]) REFERENCES [SJob].[ValuesOfWork] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Versioning] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Versioning] FOREIGN KEY ([VersionID]) REFERENCES [SCore].[Versioning] ([ID])
GO