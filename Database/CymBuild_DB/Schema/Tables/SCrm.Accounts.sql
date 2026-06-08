SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create table [SCrm].[Accounts]')
GO
SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create table [SCrm].[Accounts]')
GO
CREATE TABLE [SCrm].[Accounts] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Accounts_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Accounts_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_Accounts_Number] DEFAULT (N''),
  [Code] [nvarchar](10) NOT NULL CONSTRAINT [DF_Accounts_Code] DEFAULT (N''),
  [AccountStatusID] [int] NOT NULL CONSTRAINT [DF_Accounts_AccountStatusID] DEFAULT (-1),
  [ParentAccountID] [int] NOT NULL CONSTRAINT [DF_Accounts_ParentAccountID] DEFAULT (-1),
  [IsPurchaseLedger] [bit] NOT NULL CONSTRAINT [DF_Accounts_IsPurchaseLedger] DEFAULT (0),
  [IsSalesLedger] [bit] NOT NULL CONSTRAINT [DF_Accounts_IsSalesLedger] DEFAULT (0),
  [IsLocalAuthority] [bit] NOT NULL CONSTRAINT [DF_Accounts_IsLocalAuthority] DEFAULT (0),
  [IsFireAuthority] [bit] NOT NULL CONSTRAINT [DF_Accounts_IsFireAuthority] DEFAULT (0),
  [IsWaterAuthority] [bit] NOT NULL CONSTRAINT [DF_Accounts_IsWaterAuthority] DEFAULT (0),
  [IsDomesticClient] [bit] NOT NULL CONSTRAINT [DF_Accounts_IsDomesticClient] DEFAULT (0),
  [LegacyID] [int] NULL,
  [RelationshipManagerUserId] [int] NOT NULL CONSTRAINT [DF_Accounts_RelationshipManagerUserId] DEFAULT (-1),
  [CompanyRegistrationNumber] [nvarchar](50) NOT NULL CONSTRAINT [DF_Accounts_CompanyRegistrationNumber] DEFAULT (''),
  [PriceListId] [int] NOT NULL CONSTRAINT [DF_Accounts_PriceListId] DEFAULT (-1),
  [MainAccountAddressId] [int] NOT NULL CONSTRAINT [DF_Accounts_MainAccountAddressId] DEFAULT (-1),
  [MainAccountContactId] [int] NOT NULL CONSTRAINT [DF_Accounts_MainAccountContactId] DEFAULT (-1),
  [DefaultCreditTermsId] [int] NOT NULL CONSTRAINT [DF_Accounts_DefaultCreditTermsId] DEFAULT (-1),
  [LegacySystemID] [int] NOT NULL DEFAULT (-1),
  [BillingInstruction] [nvarchar](max) NULL,
  [ConcatenatedNameCode] AS (case when isnull([Code],'')='' then [Name] else ([Name]+' - ')+[Code] end) PERSISTED NOT NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Accounts] on table [SCrm].[Accounts]')
GO
ALTER TABLE [SCrm].[Accounts] WITH NOCHECK
  ADD CONSTRAINT [PK_Accounts] PRIMARY KEY CLUSTERED ([ID]) WITH (PAD_INDEX = ON, FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Account_LocalAuthority] on table [SCrm].[Accounts]')
GO
CREATE INDEX [IX_Account_LocalAuthority]
  ON [SCrm].[Accounts] ([IsLocalAuthority])
  INCLUDE ([Guid], [Name])
  WHERE ([IsLocalAuthority]=(1))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Account_WaterAuthority] on table [SCrm].[Accounts]')
GO
CREATE INDEX [IX_Account_WaterAuthority]
  ON [SCrm].[Accounts] ([IsWaterAuthority])
  INCLUDE ([Guid], [Name])
  WHERE ([IsWaterAuthority]=(1))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Accounts_List] on table [SCrm].[Accounts]')
GO
CREATE INDEX [IX_Accounts_List]
  ON [SCrm].[Accounts] ([Name], [RowStatus])
  INCLUDE ([Guid], [AccountStatusID], [RelationshipManagerUserId], [MainAccountAddressId])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SCrm_Accounts_175545117] on table [SCrm].[Accounts]')
GO
CREATE INDEX [IX_SCrm_Accounts_175545117]
  ON [SCrm].[Accounts] ([RowVersion])
  INCLUDE ([Name], [Code])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_Accounts_Guid] on table [SCrm].[Accounts]')
GO
CREATE UNIQUE INDEX [IX_UQ_Accounts_Guid]
  ON [SCrm].[Accounts] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tr_Accounts_CreditHold_InvoiceModeSync] on table [SCrm].[Accounts]')
GO
CREATE TRIGGER [SCrm].[tr_Accounts_CreditHold_InvoiceModeSync]
ON [SCrm].[Accounts]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(AccountStatusID)
        RETURN;

    -------------------------------------------------------------------------
    -- Build two sets:
    --  - accounts that changed from NOT HOLD -> HOLD
    --  - accounts that changed from HOLD -> NOT HOLD
    -------------------------------------------------------------------------
    DECLARE @ToHold TABLE (AccountId INT NOT NULL PRIMARY KEY);
    DECLARE @ToRelease TABLE (AccountId INT NOT NULL PRIMARY KEY);

    INSERT INTO @ToHold (AccountId)
    SELECT i.ID
    FROM inserted i
    JOIN deleted d ON d.ID = i.ID
    JOIN SCrm.AccountStatus stNew ON stNew.ID = i.AccountStatusID
    JOIN SCrm.AccountStatus stOld ON stOld.ID = d.AccountStatusID
    WHERE ISNULL(stOld.IsHold, 0) = 0
      AND ISNULL(stNew.IsHold, 0) = 1;

    INSERT INTO @ToRelease (AccountId)
    SELECT i.ID
    FROM inserted i
    JOIN deleted d ON d.ID = i.ID
    JOIN SCrm.AccountStatus stNew ON stNew.ID = i.AccountStatusID
    JOIN SCrm.AccountStatus stOld ON stOld.ID = d.AccountStatusID
    WHERE ISNULL(stOld.IsHold, 0) = 1
      AND ISNULL(stNew.IsHold, 0) = 0;

    -------------------------------------------------------------------------
    -- Apply hold -> Pause jobs
    -------------------------------------------------------------------------
    DECLARE @A INT;

    DECLARE cHold CURSOR LOCAL FAST_FORWARD FOR
        SELECT AccountId FROM @ToHold;

    OPEN cHold;
    FETCH NEXT FROM cHold INTO @A;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SFin.JobInvoiceProcessingMode_ApplyCreditHoldPause
            @FinanceAccountId = @A;

        FETCH NEXT FROM cHold INTO @A;
    END

    CLOSE cHold;
    DEALLOCATE cHold;

    -------------------------------------------------------------------------
    -- Apply release -> set jobs to Manual (only those paused-by-hold)
    -------------------------------------------------------------------------
    DECLARE cRelease CURSOR LOCAL FAST_FORWARD FOR
        SELECT AccountId FROM @ToRelease;

    OPEN cRelease;
    FETCH NEXT FROM cRelease INTO @A;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SFin.JobInvoiceProcessingMode_ClearCreditHoldToManual
            @FinanceAccountId = @A;

        FETCH NEXT FROM cRelease INTO @A;
    END

    CLOSE cRelease;
    DEALLOCATE cRelease;
END
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_Accounts_RecordHistory] on table [SCrm].[Accounts]')
GO
CREATE TRIGGER [SCrm].[tg_Accounts_RecordHistory]
   ON  [SCrm].[Accounts]	
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
			@SchemaName NVARCHAR(250) = N'SCrm',
			@TableName NVARCHAR(250) = N'Accounts',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AccountStatusID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AccountStatusID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AccountStatusID] IS DISTINCT FROM i.[AccountStatusID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AccountStatusID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 176)
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
				VALUES(1, @SchemaName, @TableName, N'BillingInstruction', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2028)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Code]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Code]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Code] IS DISTINCT FROM i.[Code])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Code', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 175)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CompanyRegistrationNumber]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CompanyRegistrationNumber]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CompanyRegistrationNumber] IS DISTINCT FROM i.[CompanyRegistrationNumber])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CompanyRegistrationNumber', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 502)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsFireAuthority]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsFireAuthority]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsFireAuthority] IS DISTINCT FROM i.[IsFireAuthority])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsFireAuthority', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 503)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsLocalAuthority]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsLocalAuthority]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsLocalAuthority] IS DISTINCT FROM i.[IsLocalAuthority])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsLocalAuthority', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 504)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsPurchaseLedger]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsPurchaseLedger]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsPurchaseLedger] IS DISTINCT FROM i.[IsPurchaseLedger])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsPurchaseLedger', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 178)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsSalesLedger]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsSalesLedger]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsSalesLedger] IS DISTINCT FROM i.[IsSalesLedger])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsSalesLedger', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 179)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsWaterAuthority]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsWaterAuthority]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsWaterAuthority] IS DISTINCT FROM i.[IsWaterAuthority])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsWaterAuthority', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 505)
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
				VALUES(1, @SchemaName, @TableName, N'LegacyID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 506)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[MainAccountAddressId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[MainAccountAddressId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[MainAccountAddressId] IS DISTINCT FROM i.[MainAccountAddressId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'MainAccountAddressId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1195)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[MainAccountContactId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[MainAccountContactId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[MainAccountContactId] IS DISTINCT FROM i.[MainAccountContactId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'MainAccountContactId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1196)
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
				VALUES(1, @SchemaName, @TableName, N'Name', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 174)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ParentAccountID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ParentAccountID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ParentAccountID] IS DISTINCT FROM i.[ParentAccountID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ParentAccountID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 177)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RelationshipManagerUserId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RelationshipManagerUserId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RelationshipManagerUserId] IS DISTINCT FROM i.[RelationshipManagerUserId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RelationshipManagerUserId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 507)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 171)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_Accounts_AccountAddresses] on table [SCrm].[Accounts]')
GO
ALTER TABLE [SCrm].[Accounts] WITH NOCHECK
  ADD CONSTRAINT [FK_Accounts_AccountAddresses] FOREIGN KEY ([MainAccountAddressId]) REFERENCES [SCrm].[AccountAddresses] ([ID])
GO

PRINT (N'Create foreign key [FK_Accounts_AccountContacts] on table [SCrm].[Accounts]')
GO
ALTER TABLE [SCrm].[Accounts] WITH NOCHECK
  ADD CONSTRAINT [FK_Accounts_AccountContacts] FOREIGN KEY ([MainAccountContactId]) REFERENCES [SCrm].[AccountContacts] ([ID])
GO

PRINT (N'Create foreign key [FK_Accounts_AccountStatus] on table [SCrm].[Accounts]')
GO
ALTER TABLE [SCrm].[Accounts] WITH NOCHECK
  ADD CONSTRAINT [FK_Accounts_AccountStatus] FOREIGN KEY ([AccountStatusID]) REFERENCES [SCrm].[AccountStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_Accounts_CreditTerms] on table [SCrm].[Accounts]')
GO
ALTER TABLE [SCrm].[Accounts] WITH NOCHECK
  ADD CONSTRAINT [FK_Accounts_CreditTerms] FOREIGN KEY ([DefaultCreditTermsId]) REFERENCES [SFin].[CreditTerms] ([ID])
GO

PRINT (N'Create foreign key [FK_Accounts_DataObjects] on table [SCrm].[Accounts]')
GO
ALTER TABLE [SCrm].[Accounts] WITH NOCHECK
  ADD CONSTRAINT [FK_Accounts_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_Accounts_DataObjects] on table [SCrm].[Accounts]')
GO
ALTER TABLE [SCrm].[Accounts]
  NOCHECK CONSTRAINT [FK_Accounts_DataObjects]
GO

PRINT (N'Create foreign key [FK_Accounts_Identities] on table [SCrm].[Accounts]')
GO
ALTER TABLE [SCrm].[Accounts] WITH NOCHECK
  ADD CONSTRAINT [FK_Accounts_Identities] FOREIGN KEY ([RelationshipManagerUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Accounts_PriceLists] on table [SCrm].[Accounts]')
GO
ALTER TABLE [SCrm].[Accounts] WITH NOCHECK
  ADD CONSTRAINT [FK_Accounts_PriceLists] FOREIGN KEY ([PriceListId]) REFERENCES [SSop].[PriceLists] ([ID])
GO

PRINT (N'Create foreign key [FK_Accounts_RowStatus] on table [SCrm].[Accounts]')
GO
ALTER TABLE [SCrm].[Accounts] WITH NOCHECK
  ADD CONSTRAINT [FK_Accounts_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create full-text index on table [SCrm].[Accounts]')
GO
CREATE FULLTEXT INDEX
  ON [SCrm].[Accounts]([Name] LANGUAGE 1033)
  KEY INDEX [PK_Accounts]
  ON [AccountName]
  WITH CHANGE_TRACKING AUTO, STOPLIST Honorifics
GO

PRINT (N'Create full-text index on table [SCrm].[Accounts]')
GO