PRINT (N'Create table [SSop].[EnquiryServices]')
GO
CREATE TABLE [SSop].[EnquiryServices] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_EnquiryServices_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_EnquiryServices_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [EnquiryId] [int] NOT NULL CONSTRAINT [DF_EnquiryServices_EnquiryId] DEFAULT (-1),
  [JobTypeId] [int] NOT NULL CONSTRAINT [DF_EnquiryServices_JobTypeId] DEFAULT (-1),
  [StartRibaStageId] [int] NOT NULL CONSTRAINT [DF_EnquiryServices_StartRibaStageId] DEFAULT (-1),
  [EndRibaStageId] [int] NOT NULL CONSTRAINT [DF_EnquiryServices_EndRibaStageId] DEFAULT (-1),
  [QuoteId] [int] NOT NULL CONSTRAINT [DF_EnquiryServices_QuoteId] DEFAULT (-1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_EnquiryServices] on table [SSop].[EnquiryServices]')
GO
ALTER TABLE [SSop].[EnquiryServices] WITH NOCHECK
  ADD CONSTRAINT [PK_EnquiryServices] PRIMARY KEY CLUSTERED ([ID])
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_EnquiryService_JobTypeId] on table [SSop].[EnquiryServices]')
GO
CREATE INDEX [IX_EnquiryService_JobTypeId]
  ON [SSop].[EnquiryServices] ([JobTypeId], [EnquiryId], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_EnquiryServices_Enquiry] on table [SSop].[EnquiryServices]')
GO
CREATE INDEX [IX_EnquiryServices_Enquiry]
  ON [SSop].[EnquiryServices] ([EnquiryId], [RowStatus])
  INCLUDE ([Guid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_EnquiryServices_EnquiryId_RowStatus_JobType] on table [SSop].[EnquiryServices]')
GO
CREATE INDEX [IX_EnquiryServices_EnquiryId_RowStatus_JobType]
  ON [SSop].[EnquiryServices] ([EnquiryId], [RowStatus], [JobTypeId])
  INCLUDE ([ID])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_EnquiryServices_Guid] on table [SSop].[EnquiryServices]')
GO
CREATE UNIQUE INDEX [IX_UQ_EnquiryServices_Guid]
  ON [SSop].[EnquiryServices] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_EnquiryServices_DataObjects] on table [SSop].[EnquiryServices]')
GO
ALTER TABLE [SSop].[EnquiryServices] WITH NOCHECK
  ADD CONSTRAINT [FK_EnquiryServices_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_EnquiryServices_DataObjects] on table [SSop].[EnquiryServices]')
GO
ALTER TABLE [SSop].[EnquiryServices]
  NOCHECK CONSTRAINT [FK_EnquiryServices_DataObjects]
GO

PRINT (N'Create foreign key [FK_EnquiryServices_Enquiries] on table [SSop].[EnquiryServices]')
GO
ALTER TABLE [SSop].[EnquiryServices] WITH NOCHECK
  ADD CONSTRAINT [FK_EnquiryServices_Enquiries] FOREIGN KEY ([EnquiryId]) REFERENCES [SSop].[Enquiries] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_EnquiryServices_JobTypes] on table [SSop].[EnquiryServices]')
GO
ALTER TABLE [SSop].[EnquiryServices] WITH NOCHECK
  ADD CONSTRAINT [FK_EnquiryServices_JobTypes] FOREIGN KEY ([JobTypeId]) REFERENCES [SJob].[JobTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_EnquiryServices_Quotes] on table [SSop].[EnquiryServices]')
GO
ALTER TABLE [SSop].[EnquiryServices] WITH NOCHECK
  ADD CONSTRAINT [FK_EnquiryServices_Quotes] FOREIGN KEY ([QuoteId]) REFERENCES [SSop].[Quotes] ([ID])
GO

PRINT (N'Create foreign key [FK_EnquiryServices_RibaStages] on table [SSop].[EnquiryServices]')
GO
ALTER TABLE [SSop].[EnquiryServices] WITH NOCHECK
  ADD CONSTRAINT [FK_EnquiryServices_RibaStages] FOREIGN KEY ([StartRibaStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_EnquiryServices_RibaStages1] on table [SSop].[EnquiryServices]')
GO
ALTER TABLE [SSop].[EnquiryServices] WITH NOCHECK
  ADD CONSTRAINT [FK_EnquiryServices_RibaStages1] FOREIGN KEY ([EndRibaStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_EnquiryServices_RowStatus] on table [SSop].[EnquiryServices]')
GO
ALTER TABLE [SSop].[EnquiryServices] WITH NOCHECK
  ADD CONSTRAINT [FK_EnquiryServices_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO