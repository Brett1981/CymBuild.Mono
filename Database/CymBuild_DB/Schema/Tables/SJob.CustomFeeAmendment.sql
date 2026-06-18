PRINT (N'Create table [SJob].[CustomFeeAmendment]')
GO
CREATE TABLE [SJob].[CustomFeeAmendment] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_CustomFeeAmendment_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_CustomFeeAmendment_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobID] [int] NOT NULL CONSTRAINT [DEFAULT_CustomFeeAmendment_JobID] DEFAULT (-1),
  [CreatedByUserID] [int] NOT NULL CONSTRAINT [DEFAULT_CustomFeeAmendment_CreatedByUserID] DEFAULT (-1),
  [CreatedDateTime] [datetime2] NOT NULL CONSTRAINT [DF_CustomFeeAmendment_CreatedDateTime] DEFAULT (getutcdate()),
  [StageChange] [decimal](9, 2) NOT NULL CONSTRAINT [DF_CustomFeeAmendment_StageChange] DEFAULT (0),
  [StageMeetingChange] [decimal](9, 2) NOT NULL CONSTRAINT [DF_CustomFeeAmendment_StageMeetingChange] DEFAULT (0.00),
  [StageVisitChange] [decimal](9, 2) NOT NULL CONSTRAINT [DF_CustomFeeAmendment_StageVisitChange] DEFAULT (0.00),
  [Reason] [nvarchar](max) NOT NULL CONSTRAINT [DF_CustomFeeAmendment_Reason] DEFAULT (N''),
  [StageId] [int] NOT NULL CONSTRAINT [DF_CustomFeeAmendment_StageId] DEFAULT (-1),
  [FeeAmendmentId] [bigint] NOT NULL CONSTRAINT [DF_CustomFeeAmendment_FeeAmendmentId] DEFAULT (-1)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_CustomFeeAmendment] on table [SJob].[CustomFeeAmendment]')
GO
ALTER TABLE [SJob].[CustomFeeAmendment] WITH NOCHECK
  ADD CONSTRAINT [PK_CustomFeeAmendment] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create foreign key [FK_CustomFeeAmendment_FeeAmendment_FeeAmendmentId] on table [SJob].[CustomFeeAmendment]')
GO
ALTER TABLE [SJob].[CustomFeeAmendment] WITH NOCHECK
  ADD CONSTRAINT [FK_CustomFeeAmendment_FeeAmendment_FeeAmendmentId] FOREIGN KEY ([FeeAmendmentId]) REFERENCES [SJob].[FeeAmendment] ([ID])
GO

PRINT (N'Create foreign key [FK_CustomFeeAmendment_RibaStages_StageId] on table [SJob].[CustomFeeAmendment]')
GO
ALTER TABLE [SJob].[CustomFeeAmendment] WITH NOCHECK
  ADD CONSTRAINT [FK_CustomFeeAmendment_RibaStages_StageId] FOREIGN KEY ([StageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO