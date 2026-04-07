PRINT (N'Create table [SJob].[SubContractorInvoices]')
GO
CREATE TABLE [SJob].[SubContractorInvoices] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_SubContractorInvoices_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_SubContractorInvoices_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [SubContractorName] [nvarchar](100) NOT NULL CONSTRAINT [DF_SubContractorInvoices_SubContractorName] DEFAULT (''),
  [InvoiceDate] [date] NULL,
  [InvoiceNumber] [nvarchar](50) NOT NULL CONSTRAINT [DF_SubContractorInvoices_InvoiceNumber] DEFAULT (''),
  [DescriptionOfWork] [nvarchar](max) NOT NULL CONSTRAINT [DF_SubContractorInvoices_DescriptionOfWork] DEFAULT (''),
  [ValueWithVAT] [decimal](19, 2) NOT NULL CONSTRAINT [DF_SubContractorInvoices_ValueWithVAT] DEFAULT (0.0),
  [ValueWithoutVAT] [decimal](19, 2) NOT NULL CONSTRAINT [DF_SubContractorInvoices_ValueWithoutVAT] DEFAULT (0.0),
  [ActivityId] [bigint] NOT NULL CONSTRAINT [DF_SubContractorInvoices_ActivityId] DEFAULT (-1),
  [MilestoneId] [bigint] NOT NULL CONSTRAINT [DF_SubContractorInvoices_MilestoneId] DEFAULT (-1),
  [SupportingComments] [nvarchar](max) NOT NULL CONSTRAINT [DF_SubContractorInvoices_SupportingComments] DEFAULT (''),
  [JobId] [int] NOT NULL CONSTRAINT [DF_SubContractorInvoices_JobId] DEFAULT (-1)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SubContractorInvoices] on table [SJob].[SubContractorInvoices]')
GO
ALTER TABLE [SJob].[SubContractorInvoices] WITH NOCHECK
  ADD CONSTRAINT [PK_SubContractorInvoices] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create foreign key [FK_SubContractorInvoices_ActivityId] on table [SJob].[SubContractorInvoices]')
GO
ALTER TABLE [SJob].[SubContractorInvoices] WITH NOCHECK
  ADD CONSTRAINT [FK_SubContractorInvoices_ActivityId] FOREIGN KEY ([ActivityId]) REFERENCES [SJob].[Activities] ([ID])
GO

PRINT (N'Create foreign key [FK_SubContractorInvoices_DataObjects] on table [SJob].[SubContractorInvoices]')
GO
ALTER TABLE [SJob].[SubContractorInvoices] WITH NOCHECK
  ADD CONSTRAINT [FK_SubContractorInvoices_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_SubContractorInvoices_DataObjects] on table [SJob].[SubContractorInvoices]')
GO
ALTER TABLE [SJob].[SubContractorInvoices]
  NOCHECK CONSTRAINT [FK_SubContractorInvoices_DataObjects]
GO

PRINT (N'Create foreign key [FK_SubContractorInvoices_JobId] on table [SJob].[SubContractorInvoices]')
GO
ALTER TABLE [SJob].[SubContractorInvoices] WITH NOCHECK
  ADD CONSTRAINT [FK_SubContractorInvoices_JobId] FOREIGN KEY ([JobId]) REFERENCES [SJob].[Jobs] ([ID])
GO

PRINT (N'Create foreign key [FK_SubContractorInvoices_MilestoneId] on table [SJob].[SubContractorInvoices]')
GO
ALTER TABLE [SJob].[SubContractorInvoices] WITH NOCHECK
  ADD CONSTRAINT [FK_SubContractorInvoices_MilestoneId] FOREIGN KEY ([MilestoneId]) REFERENCES [SJob].[Milestones] ([ID])
GO

PRINT (N'Create foreign key [FK_SubContractorInvoices_RowStatus] on table [SJob].[SubContractorInvoices]')
GO
ALTER TABLE [SJob].[SubContractorInvoices] WITH NOCHECK
  ADD CONSTRAINT [FK_SubContractorInvoices_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO