CREATE TABLE [SJob].[AssetPossibleDuplicates] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_AssetPossibleDuplicates_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_AssetPossibleDuplicates_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [SourceAssetID] [int] NOT NULL CONSTRAINT [DF_AssetPossibleDuplicates_SourceAssetID] DEFAULT (-1),
  [TargetAssetID] [int] NOT NULL CONSTRAINT [DF_AssetPossibleDuplicates_TargetAssetID] DEFAULT (-1),
  [IsDifferent] [bit] NOT NULL CONSTRAINT [DF_Table_1_Ignore] DEFAULT (0),
  [IsDuplicate] [bit] NOT NULL CONSTRAINT [DF_AssetPossibleDuplicates_IsComplete] DEFAULT (0),
  CONSTRAINT [PK_AssetPossibleDuplicates] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_AssetPossibleDuplicates]
  ON [SJob].[AssetPossibleDuplicates] ([SourceAssetID], [TargetAssetID])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SJob].[AssetPossibleDuplicates]
  ADD CONSTRAINT [FK_AssetPossibleDuplicates_Assets] FOREIGN KEY ([SourceAssetID]) REFERENCES [SJob].[Assets] ([ID])
GO

ALTER TABLE [SJob].[AssetPossibleDuplicates]
  ADD CONSTRAINT [FK_AssetPossibleDuplicates_Assets1] FOREIGN KEY ([TargetAssetID]) REFERENCES [SJob].[Assets] ([ID])
GO