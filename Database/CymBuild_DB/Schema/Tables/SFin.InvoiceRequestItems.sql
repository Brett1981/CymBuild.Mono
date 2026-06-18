PRINT (N'Create table [SFin].[InvoiceRequestItems]')
GO
CREATE TABLE [SFin].[InvoiceRequestItems] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_InvoiceRequestItems_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_InvoiceRequestItems_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [InvoiceRequestId] [int] NOT NULL CONSTRAINT [DF_InvoiceRequestItems_InvoiceRequestItems] DEFAULT (-1),
  [MilestoneId] [bigint] NULL,
  [ActivityId] [bigint] NULL,
  [Net] [decimal](19, 2) NOT NULL CONSTRAINT [DF_InvoiceRequestItems_Net] DEFAULT (0),
  [LegacyId] [int] NULL,
  [LegacySystemID] [int] NOT NULL DEFAULT (-1),
  [ShortDescription] [nvarchar](200) NOT NULL DEFAULT (N''),
  [RIBAStageId] [int] NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_InvoiceRequestItems] on table [SFin].[InvoiceRequestItems]')
GO
ALTER TABLE [SFin].[InvoiceRequestItems] WITH NOCHECK
  ADD CONSTRAINT [PK_InvoiceRequestItems] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_InvoiceRequestItems_InvoiceRequest] on table [SFin].[InvoiceRequestItems]')
GO
CREATE INDEX [IX_InvoiceRequestItems_InvoiceRequest]
  ON [SFin].[InvoiceRequestItems] ([InvoiceRequestId], [Net], [RowStatus])
  INCLUDE ([ActivityId])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_InvoiceRequestItems_Guid] on table [SFin].[InvoiceRequestItems]')
GO
CREATE UNIQUE INDEX [IX_UQ_InvoiceRequestItems_Guid]
  ON [SFin].[InvoiceRequestItems] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_InvoiceRequestItems_RecordHistory] on table [SFin].[InvoiceRequestItems]')
GO
CREATE TRIGGER [SFin].[tg_InvoiceRequestItems_RecordHistory]
   ON  [SFin].[InvoiceRequestItems]	
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
			@TableName NVARCHAR(250) = N'InvoiceRequestItems',
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
				VALUES(1, @SchemaName, @TableName, N'ActivityId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1671)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[InvoiceRequestId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[InvoiceRequestId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[InvoiceRequestId] IS DISTINCT FROM i.[InvoiceRequestId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'InvoiceRequestId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1669)
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
				VALUES(1, @SchemaName, @TableName, N'MilestoneId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1670)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Net]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Net]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Net] IS DISTINCT FROM i.[Net])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Net', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1672)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1666)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ShortDescription]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ShortDescription]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ShortDescription] IS DISTINCT FROM i.[ShortDescription])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ShortDescription', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2571)
			END 
			
			
			END
		END
		
		
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tr_InvoiceRequestItems_RecalcPlaceholder] on table [SFin].[InvoiceRequestItems]')
GO
/* =============================================================================
   SFin.tr_InvoiceRequestItems_RecalcPlaceholder

   Purpose:
   - Keep InvoiceRequests.IsZeroValuePlaceholder in sync with the SUM(Net) of its
     active (non-deleted) InvoiceRequestItems.

   Key behaviours:
   - Supports bulk/script guard via SESSION_CONTEXT('S_disable_triggers')
   - Handles INSERT/UPDATE/DELETE
   - Ignores RowStatus = 254 items (deleted)
   - Only updates affected InvoiceRequests
   - Avoids unnecessary writes (only updates when value would change)
============================================================================= */

CREATE TRIGGER [SFin].[tr_InvoiceRequestItems_RecalcPlaceholder]
ON [SFin].[InvoiceRequestItems]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Guard: allow disabling during bulk loads / scripts
    IF (ISNULL(CONVERT(INT, SESSION_CONTEXT(N'S_disable_triggers')), 0) = 1)
        RETURN;

    ;WITH Changed AS
    (
        SELECT DISTINCT InvoiceRequestId
        FROM
        (
            SELECT InvoiceRequestId FROM inserted
            UNION ALL
            SELECT InvoiceRequestId FROM deleted
        ) x
        WHERE InvoiceRequestId IS NOT NULL
          AND InvoiceRequestId > 0
    ),
    Totals AS
    (
        SELECT
              c.InvoiceRequestId
            , TotalNet = CAST(SUM(CASE WHEN iri.RowStatus = 254 THEN 0 ELSE ISNULL(iri.Net, 0) END) AS DECIMAL(19,2))
        FROM Changed c
        LEFT JOIN SFin.InvoiceRequestItems iri
            ON iri.InvoiceRequestId = c.InvoiceRequestId
        GROUP BY c.InvoiceRequestId
    )
    UPDATE ir
        SET ir.IsZeroValuePlaceholder =
                CASE WHEN ISNULL(t.TotalNet, 0) = 0 THEN 1 ELSE 0 END
    FROM SFin.InvoiceRequests ir
    JOIN Totals t
        ON t.InvoiceRequestId = ir.ID
    WHERE ir.RowStatus NOT IN (254)  -- keep consistent with your "deleted" sentinel
      AND ir.IsZeroValuePlaceholder <>
            CASE WHEN ISNULL(t.TotalNet, 0) = 0 THEN 1 ELSE 0 END;
END;
GO

PRINT (N'Create foreign key [FK_InvoiceRequestItems_Activities] on table [SFin].[InvoiceRequestItems]')
GO
ALTER TABLE [SFin].[InvoiceRequestItems] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequestItems_Activities] FOREIGN KEY ([ActivityId]) REFERENCES [SJob].[Activities] ([ID])
GO

PRINT (N'Create foreign key [FK_InvoiceRequestItems_DataObjects] on table [SFin].[InvoiceRequestItems]')
GO
ALTER TABLE [SFin].[InvoiceRequestItems] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequestItems_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_InvoiceRequestItems_DataObjects] on table [SFin].[InvoiceRequestItems]')
GO
ALTER TABLE [SFin].[InvoiceRequestItems]
  NOCHECK CONSTRAINT [FK_InvoiceRequestItems_DataObjects]
GO

PRINT (N'Create foreign key [FK_InvoiceRequestItems_InvoiceRequests] on table [SFin].[InvoiceRequestItems]')
GO
ALTER TABLE [SFin].[InvoiceRequestItems] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequestItems_InvoiceRequests] FOREIGN KEY ([InvoiceRequestId]) REFERENCES [SFin].[InvoiceRequests] ([ID])
GO

PRINT (N'Create foreign key [FK_InvoiceRequestItems_Milestones] on table [SFin].[InvoiceRequestItems]')
GO
ALTER TABLE [SFin].[InvoiceRequestItems] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequestItems_Milestones] FOREIGN KEY ([MilestoneId]) REFERENCES [SJob].[Milestones] ([ID])
GO

PRINT (N'Create foreign key [FK_InvoiceRequestItems_RibaStages] on table [SFin].[InvoiceRequestItems]')
GO
ALTER TABLE [SFin].[InvoiceRequestItems] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequestItems_RibaStages] FOREIGN KEY ([RIBAStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_InvoiceRequestItems_RowStatus] on table [SFin].[InvoiceRequestItems]')
GO
ALTER TABLE [SFin].[InvoiceRequestItems] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequestItems_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO