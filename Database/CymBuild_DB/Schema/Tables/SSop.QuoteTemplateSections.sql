CREATE TABLE [SSop].[QuoteTemplateSections] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_QuoteTemplateSections_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_QuoteTemplateSections_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [QuoteTemplateId] [int] NOT NULL CONSTRAINT [DF_QuoteTemplateSections_QuoteId] DEFAULT (-1),
  [Name] [nvarchar](200) NOT NULL CONSTRAINT [DF_QuoteTemplateSections_Name] DEFAULT (''),
  [Overview] [nvarchar](max) NOT NULL CONSTRAINT [DF_QuoteTemplateSections_Overview] DEFAULT (''),
  [ShowProducts] [bit] NOT NULL CONSTRAINT [DF_QuoteTemplateSections_ShowProducts] DEFAULT (0),
  [ConsolidateJobs] [bit] NOT NULL CONSTRAINT [DF_QuoteTemplateSections_ConsolidateJobs] DEFAULT (0),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF_QuoteTemplateSections_SortOrder] DEFAULT (0),
  [ValueOfWorkId] [smallint] NOT NULL CONSTRAINT [DF_QuoteTemplateSections_ValueOfWorkId] DEFAULT (-1),
  [RibaStageId] [int] NOT NULL CONSTRAINT [DF_QuoteTemplateSections_RibaStage] DEFAULT (-1),
  [CombineWithSectionId] [int] NOT NULL CONSTRAINT [DF_QuoteTemplateSections_CombineWithSecionId] DEFAULT (-1),
  [NumberOfMeetings] [int] NOT NULL CONSTRAINT [DF_QuoteTemplateSections_NumberOfMeetings] DEFAULT (0),
  [NumberOfSiteVisits] [int] NOT NULL CONSTRAINT [DF_QuoteTemplateSections_NumberOfSiteVisits] DEFAULT (0),
  [InvoiceScheduleId] [int] NOT NULL CONSTRAINT [DF_QuoteTemplateSections_InvoiceScheduleId] DEFAULT (-1),
  CONSTRAINT [PK_QuoteTemplateSections] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [SSop].[QuoteTemplateSections] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteTemplateSections_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SSop].[QuoteTemplateSections]
  NOCHECK CONSTRAINT [FK_QuoteTemplateSections_DataObjects]
GO

ALTER TABLE [SSop].[QuoteTemplateSections]
  ADD CONSTRAINT [FK_QuoteTemplateSections_InvoiceSchedules] FOREIGN KEY ([InvoiceScheduleId]) REFERENCES [SSop].[InvoiceSchedules] ([ID])
GO

ALTER TABLE [SSop].[QuoteTemplateSections]
  ADD CONSTRAINT [FK_QuoteTemplateSections_QuoteTemplates] FOREIGN KEY ([QuoteTemplateId]) REFERENCES [SSop].[QuoteTemplates] ([ID])
GO

ALTER TABLE [SSop].[QuoteTemplateSections]
  ADD CONSTRAINT [FK_QuoteTemplateSections_QuoteTemplateSections] FOREIGN KEY ([CombineWithSectionId]) REFERENCES [SSop].[QuoteTemplateSections] ([ID])
GO

ALTER TABLE [SSop].[QuoteTemplateSections]
  ADD CONSTRAINT [FK_QuoteTemplateSections_RibaStages] FOREIGN KEY ([RibaStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

ALTER TABLE [SSop].[QuoteTemplateSections]
  ADD CONSTRAINT [FK_QuoteTemplateSections_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

ALTER TABLE [SSop].[QuoteTemplateSections]
  ADD CONSTRAINT [FK_QuoteTemplateSections_ValuesOfWork] FOREIGN KEY ([ValueOfWorkId]) REFERENCES [SJob].[ValuesOfWork] ([ID])
GO