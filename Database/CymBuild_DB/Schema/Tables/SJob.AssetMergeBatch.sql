CREATE TABLE [SJob].[AssetMergeBatch] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_AssetMergeBatch_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_AssetMergeBatch_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [SourceAssetId] [int] NOT NULL CONSTRAINT [DF_AssetMergeBatch_SourceAssetId] DEFAULT (-1),
  [TargetAssetId] [int] NOT NULL CONSTRAINT [DF_AssetMergeBatch_TargetAssetId] DEFAULT (-1),
  [CreatedByUserId] [int] NOT NULL CONSTRAINT [DF_AssetMergeBatch_CreatedByUserId] DEFAULT (-1),
  [CheckedByUserId] [int] NOT NULL CONSTRAINT [DF_AssetMergeBatch_CheckedByUserId] DEFAULT (-1),
  [IsComplete] [bit] NOT NULL CONSTRAINT [DF_AssetMergeBatch_IsComplete] DEFAULT (0),
  CONSTRAINT [PK_AssetMergeBatch] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

ALTER TABLE [SJob].[AssetMergeBatch]
  ADD CONSTRAINT [FK_AssetMergeBatch_Accounts] FOREIGN KEY ([SourceAssetId]) REFERENCES [SJob].[Assets] ([ID])
GO

ALTER TABLE [SJob].[AssetMergeBatch]
  ADD CONSTRAINT [FK_AssetMergeBatch_Accounts1] FOREIGN KEY ([TargetAssetId]) REFERENCES [SJob].[Assets] ([ID])
GO

ALTER TABLE [SJob].[AssetMergeBatch] WITH NOCHECK
  ADD CONSTRAINT [FK_AssetMergeBatch_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SJob].[AssetMergeBatch]
  NOCHECK CONSTRAINT [FK_AssetMergeBatch_DataObjects]
GO

ALTER TABLE [SJob].[AssetMergeBatch]
  ADD CONSTRAINT [FK_AssetMergeBatch_Identities] FOREIGN KEY ([CreatedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

ALTER TABLE [SJob].[AssetMergeBatch]
  ADD CONSTRAINT [FK_AssetMergeBatch_Identities1] FOREIGN KEY ([CheckedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

ALTER TABLE [SJob].[AssetMergeBatch]
  ADD CONSTRAINT [FK_AssetMergeBatch_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO