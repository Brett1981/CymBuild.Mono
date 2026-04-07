PRINT (N'Create table [SJob].[PurchaseOrders]')
GO
CREATE TABLE [SJob].[PurchaseOrders] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_PurchaseOrders_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_PurchaseOrders_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Number] [nvarchar](15) NOT NULL CONSTRAINT [DF_PurchaseOrders_Number] DEFAULT (''),
  [Description] [nvarchar](max) NOT NULL CONSTRAINT [DF_PurchaseOrders_Description] DEFAULT (''),
  [StageId] [int] NOT NULL CONSTRAINT [DF_PurchaseOrders_StageId] DEFAULT (-1),
  [SiteId] [int] NOT NULL CONSTRAINT [DF_PurchaseOrders_SiteId] DEFAULT (-1),
  [Value] [decimal](19, 2) NOT NULL CONSTRAINT [DF_PurchaseOrders_Value] DEFAULT (0.0),
  [DateReceived] [date] NULL,
  [ValidUntilDate] [date] NULL,
  [ActivityId] [bigint] NOT NULL CONSTRAINT [DF_PurchaseOrders_ActivityId] DEFAULT (-1),
  [JobId] [int] NOT NULL CONSTRAINT [DF_PurchaseOrders_JobId] DEFAULT (-1)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_PurchaseOrders] on table [SJob].[PurchaseOrders]')
GO
ALTER TABLE [SJob].[PurchaseOrders] WITH NOCHECK
  ADD CONSTRAINT [PK_PurchaseOrders] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create foreign key [FK_PurchaseOrders_ActivityId] on table [SJob].[PurchaseOrders]')
GO
ALTER TABLE [SJob].[PurchaseOrders] WITH NOCHECK
  ADD CONSTRAINT [FK_PurchaseOrders_ActivityId] FOREIGN KEY ([ActivityId]) REFERENCES [SJob].[Activities] ([ID])
GO

PRINT (N'Create foreign key [FK_PurchaseOrders_DataObjects] on table [SJob].[PurchaseOrders]')
GO
ALTER TABLE [SJob].[PurchaseOrders] WITH NOCHECK
  ADD CONSTRAINT [FK_PurchaseOrders_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_PurchaseOrders_DataObjects] on table [SJob].[PurchaseOrders]')
GO
ALTER TABLE [SJob].[PurchaseOrders]
  NOCHECK CONSTRAINT [FK_PurchaseOrders_DataObjects]
GO

PRINT (N'Create foreign key [FK_PurchaseOrders_JobId] on table [SJob].[PurchaseOrders]')
GO
ALTER TABLE [SJob].[PurchaseOrders] WITH NOCHECK
  ADD CONSTRAINT [FK_PurchaseOrders_JobId] FOREIGN KEY ([JobId]) REFERENCES [SJob].[Jobs] ([ID])
GO

PRINT (N'Create foreign key [FK_PurchaseOrders_RowStatus] on table [SJob].[PurchaseOrders]')
GO
ALTER TABLE [SJob].[PurchaseOrders] WITH NOCHECK
  ADD CONSTRAINT [FK_PurchaseOrders_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_PurchaseOrders_SiteId] on table [SJob].[PurchaseOrders]')
GO
ALTER TABLE [SJob].[PurchaseOrders] WITH NOCHECK
  ADD CONSTRAINT [FK_PurchaseOrders_SiteId] FOREIGN KEY ([SiteId]) REFERENCES [SJob].[Assets] ([ID])
GO

PRINT (N'Create foreign key [FK_PurchaseOrders_StageId] on table [SJob].[PurchaseOrders]')
GO
ALTER TABLE [SJob].[PurchaseOrders] WITH NOCHECK
  ADD CONSTRAINT [FK_PurchaseOrders_StageId] FOREIGN KEY ([StageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO