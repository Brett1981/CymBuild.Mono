CREATE TABLE [SProd].[Products] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Products_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Products_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Code] [nvarchar](30) NOT NULL CONSTRAINT [DF_Products_Code] DEFAULT (''),
  [Description] [nvarchar](2000) NOT NULL CONSTRAINT [DF_Products_Description] DEFAULT (''),
  [CreatedJobType] [int] NOT NULL CONSTRAINT [DF_Products_CreatedJobType] DEFAULT (-1),
  [NeverConsolidate] [bit] NOT NULL CONSTRAINT [DF_Products_NeverConsolidate] DEFAULT (0),
  [RibaStageId] [int] NOT NULL CONSTRAINT [DF_Products_RibaStageId] DEFAULT (-1),
  CONSTRAINT [PK_Products] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_Products_Code]
  ON [SProd].[Products] ([Code])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_Products_Guid]
  ON [SProd].[Products] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

ALTER TABLE [SProd].[Products] WITH NOCHECK
  ADD CONSTRAINT [FK_Products_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SProd].[Products]
  NOCHECK CONSTRAINT [FK_Products_DataObjects]
GO

ALTER TABLE [SProd].[Products]
  ADD CONSTRAINT [FK_Products_RibaStages] FOREIGN KEY ([RibaStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

ALTER TABLE [SProd].[Products]
  ADD CONSTRAINT [FK_Products_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO