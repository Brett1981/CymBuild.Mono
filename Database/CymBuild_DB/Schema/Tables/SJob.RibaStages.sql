CREATE TABLE [SJob].[RibaStages] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_RIBAStages_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_RIBAStages_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Number] [int] NOT NULL CONSTRAINT [DF_RibaStages_Number] DEFAULT (0),
  [Description] [nvarchar](500) NOT NULL CONSTRAINT [DF_RibaStages_Description] DEFAULT (N''),
  [IsRealStage] [bit] NOT NULL CONSTRAINT [DF_RibaStages_IsRealStage] DEFAULT (0),
  CONSTRAINT [PK_RIBAStages] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_RibaStages_Guid]
  ON [SJob].[RibaStages] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SJob].[RibaStages] WITH NOCHECK
  ADD CONSTRAINT [FK_RibaStages_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SJob].[RibaStages]
  NOCHECK CONSTRAINT [FK_RibaStages_DataObjects]
GO

ALTER TABLE [SJob].[RibaStages]
  ADD CONSTRAINT [FK_RibaStages_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO