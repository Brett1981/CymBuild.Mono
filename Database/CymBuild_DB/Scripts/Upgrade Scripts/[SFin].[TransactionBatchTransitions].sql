USE [CymBuild_Dev]
GO

CREATE TABLE [SFin].[TransactionBatchTransitions]
(
    [ID]                        BIGINT IDENTITY(1,1) NOT NULL,
    [RowStatus]                 TINYINT NOT NULL,
    [RowVersion]                ROWVERSION NOT NULL,
    [Guid]                      UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL,
    [TransactionID]             BIGINT NOT NULL,
    [TransactionGuid]           UNIQUEIDENTIFIER NOT NULL,
    [OldBatched]                BIT NOT NULL,
    [NewBatched]                BIT NOT NULL,
    [DateTimeUTC]               DATETIME2(7) NOT NULL,
    [CreatedByUserId]           INT NOT NULL,
    [SurveyorUserId]            INT NOT NULL,
    [Comment]                   NVARCHAR(MAX) NULL,
    [IsImported]                BIT NOT NULL,
    [SourceTransactionRowVersion] BINARY(8) NOT NULL,
    CONSTRAINT [PK_TransactionBatchTransitions] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [UQ_TransactionBatchTransitions_Guid] UNIQUE NONCLUSTERED ([Guid] ASC)
);
GO

ALTER TABLE [SFin].[TransactionBatchTransitions]
    ADD CONSTRAINT [DF_TransactionBatchTransitions_RowStatus] DEFAULT ((1)) FOR [RowStatus];
GO

ALTER TABLE [SFin].[TransactionBatchTransitions]
    ADD CONSTRAINT [DF_TransactionBatchTransitions_Guid] DEFAULT (NEWID()) FOR [Guid];
GO

ALTER TABLE [SFin].[TransactionBatchTransitions]
    ADD CONSTRAINT [DF_TransactionBatchTransitions_DateTimeUTC] DEFAULT (SYSUTCDATETIME()) FOR [DateTimeUTC];
GO

ALTER TABLE [SFin].[TransactionBatchTransitions]
    ADD CONSTRAINT [DF_TransactionBatchTransitions_CreatedByUserId] DEFAULT ((-1)) FOR [CreatedByUserId];
GO

ALTER TABLE [SFin].[TransactionBatchTransitions]
    ADD CONSTRAINT [DF_TransactionBatchTransitions_SurveyorUserId] DEFAULT ((-1)) FOR [SurveyorUserId];
GO

ALTER TABLE [SFin].[TransactionBatchTransitions]
    ADD CONSTRAINT [DF_TransactionBatchTransitions_IsImported] DEFAULT ((0)) FOR [IsImported];
GO

ALTER TABLE [SFin].[TransactionBatchTransitions] WITH CHECK
    ADD CONSTRAINT [FK_TransactionBatchTransitions_Transactions]
    FOREIGN KEY ([TransactionID]) REFERENCES [SFin].[Transactions] ([ID]);
GO

ALTER TABLE [SFin].[TransactionBatchTransitions] CHECK CONSTRAINT [FK_TransactionBatchTransitions_Transactions];
GO

ALTER TABLE [SFin].[TransactionBatchTransitions] WITH NOCHECK
    ADD CONSTRAINT [FK_TransactionBatchTransitions_DataObjects]
    FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid]);
GO

ALTER TABLE [SFin].[TransactionBatchTransitions] NOCHECK CONSTRAINT [FK_TransactionBatchTransitions_DataObjects];
GO

ALTER TABLE [SFin].[TransactionBatchTransitions] WITH CHECK
    ADD CONSTRAINT [FK_TransactionBatchTransitions_CreatedBy]
    FOREIGN KEY ([CreatedByUserId]) REFERENCES [SCore].[Identities] ([ID]);
GO

ALTER TABLE [SFin].[TransactionBatchTransitions] CHECK CONSTRAINT [FK_TransactionBatchTransitions_CreatedBy];
GO

ALTER TABLE [SFin].[TransactionBatchTransitions] WITH CHECK
    ADD CONSTRAINT [FK_TransactionBatchTransitions_Surveyor]
    FOREIGN KEY ([SurveyorUserId]) REFERENCES [SCore].[Identities] ([ID]);
GO

ALTER TABLE [SFin].[TransactionBatchTransitions] CHECK CONSTRAINT [FK_TransactionBatchTransitions_Surveyor];
GO

ALTER TABLE [SFin].[TransactionBatchTransitions] WITH CHECK
    ADD CONSTRAINT [FK_TransactionBatchTransitions_RowStatus]
    FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID]);
GO

ALTER TABLE [SFin].[TransactionBatchTransitions] CHECK CONSTRAINT [FK_TransactionBatchTransitions_RowStatus];
GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_TransactionBatchTransitions_SourceRowVersion]
ON [SFin].[TransactionBatchTransitions]
(
    [TransactionGuid] ASC,
    [SourceTransactionRowVersion] ASC
)
WHERE [RowStatus] != 0 AND [RowStatus] != 254;
GO

CREATE NONCLUSTERED INDEX [IX_TransactionBatchTransitions_TransactionGuid_IdDesc]
ON [SFin].[TransactionBatchTransitions]
(
    [TransactionGuid] ASC,
    [ID] DESC
)
INCLUDE
(
    [OldBatched],
    [NewBatched],
    [DateTimeUTC],
    [Guid]
)
WHERE [RowStatus] != 0 AND [RowStatus] != 254;
GO