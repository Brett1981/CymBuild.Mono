PRINT (N'Create table [SSop].[QuoteSections]')
GO
CREATE TABLE [SSop].[QuoteSections] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_QuoteSections_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_QuoteSections_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [QuoteId] [int] NOT NULL CONSTRAINT [DF_QuoteSections_QuoteId] DEFAULT (-1),
  [Name] [nvarchar](200) NOT NULL CONSTRAINT [DF_QuoteSections_Name] DEFAULT (''),
  [Overview] [nvarchar](max) NOT NULL CONSTRAINT [DF_QuoteSections_Overview] DEFAULT (''),
  [ShowProducts] [bit] NOT NULL CONSTRAINT [DF_QuoteSections_ShowProducts] DEFAULT (0),
  [ConsolidateJobs] [bit] NOT NULL CONSTRAINT [DF_QuoteSections_ConsolidateJobs] DEFAULT (0),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF_QuoteSections_SortOrder] DEFAULT (0),
  [ValueOfWorkId] [smallint] NOT NULL CONSTRAINT [DF_QuoteSections_ValueOfWorkId] DEFAULT (-1),
  [RibaStageId] [int] NOT NULL CONSTRAINT [DF_QuoteSections_RibaStage] DEFAULT (-1),
  [CombineWithSectionId] [int] NOT NULL CONSTRAINT [DF_QuoteSections_CombineWithSecionId] DEFAULT (-1),
  [NumberOfMeetings] [int] NOT NULL CONSTRAINT [DF_QuoteSections_NumberOfMeetings] DEFAULT (0),
  [NumberOfSiteVisits] [int] NOT NULL CONSTRAINT [DF_QuoteSections_NumberOfSiteVisits] DEFAULT (0),
  [InvoiceScheduleId] [int] NOT NULL CONSTRAINT [DF_QuoteSections_InvoiceScheduleId] DEFAULT (-1),
  [LegacyId] [int] NULL,
  [LegacySystemID] [int] NOT NULL DEFAULT (-1)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_QuoteSections] on table [SSop].[QuoteSections]')
GO
ALTER TABLE [SSop].[QuoteSections] WITH NOCHECK
  ADD CONSTRAINT [PK_QuoteSections] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 90)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_QuoteSections_QuoteId] on table [SSop].[QuoteSections]')
GO
CREATE INDEX [IX_QuoteSections_QuoteId]
  ON [SSop].[QuoteSections] ([QuoteId], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_QuoteSections_Guid] on table [SSop].[QuoteSections]')
GO
CREATE UNIQUE INDEX [IX_UQ_QuoteSections_Guid]
  ON [SSop].[QuoteSections] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_QuoteSections_DataObjects] on table [SSop].[QuoteSections]')
GO
ALTER TABLE [SSop].[QuoteSections] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteSections_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_QuoteSections_DataObjects] on table [SSop].[QuoteSections]')
GO
ALTER TABLE [SSop].[QuoteSections]
  NOCHECK CONSTRAINT [FK_QuoteSections_DataObjects]
GO

PRINT (N'Create foreign key [FK_QuoteSections_InvoiceSchedules] on table [SSop].[QuoteSections]')
GO
ALTER TABLE [SSop].[QuoteSections] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteSections_InvoiceSchedules] FOREIGN KEY ([InvoiceScheduleId]) REFERENCES [SSop].[InvoiceSchedules] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteSections_Quotes] on table [SSop].[QuoteSections]')
GO
ALTER TABLE [SSop].[QuoteSections] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteSections_Quotes] FOREIGN KEY ([QuoteId]) REFERENCES [SSop].[Quotes] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_QuoteSections_QuoteSections] on table [SSop].[QuoteSections]')
GO
ALTER TABLE [SSop].[QuoteSections] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteSections_QuoteSections] FOREIGN KEY ([CombineWithSectionId]) REFERENCES [SSop].[QuoteSections] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteSections_RibaStages] on table [SSop].[QuoteSections]')
GO
ALTER TABLE [SSop].[QuoteSections] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteSections_RibaStages] FOREIGN KEY ([RibaStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteSections_RowStatus] on table [SSop].[QuoteSections]')
GO
ALTER TABLE [SSop].[QuoteSections] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteSections_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteSections_ValuesOfWork] on table [SSop].[QuoteSections]')
GO
ALTER TABLE [SSop].[QuoteSections] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteSections_ValuesOfWork] FOREIGN KEY ([ValueOfWorkId]) REFERENCES [SJob].[ValuesOfWork] ([ID])
GO