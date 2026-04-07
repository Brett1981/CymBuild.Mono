CREATE TABLE [SCore].[MergeDocuments] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_MergeDocuments_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_MergeDocuments_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_MergeDocuments_Name] DEFAULT (''),
  [FilenameTemplate] [nvarchar](250) NOT NULL CONSTRAINT [DF_MergeDocuments_FilenameTemplate] DEFAULT (''),
  [EntityTypeId] [int] NOT NULL CONSTRAINT [DF_MergeDocuments_EntityTypeId] DEFAULT (-1),
  [DocumentId] [nvarchar](500) NOT NULL CONSTRAINT [DF_MergeDocuments_DocumentId] DEFAULT (''),
  [LinkedEntityTypeId] [int] NOT NULL CONSTRAINT [DF_MergeDocuments_LinkedEntityTypeId] DEFAULT (-1),
  [SharepointSiteId] [int] NOT NULL CONSTRAINT [DF_MergeDocuments_SharepointSiteId] DEFAULT (-1),
  [AllowPDFOutputOnly] [bit] NOT NULL CONSTRAINT [DF_MergeDocuments_AllowPDFOutputOnly] DEFAULT (0),
  [ProduceOneOutputPerRow] [bit] NOT NULL CONSTRAINT [DF_MergeDocuments_ProduceOneOutputPerRow] DEFAULT (0),
  [AllowExcelOutputOnly] [bit] NOT NULL CONSTRAINT [DF_MergeDocuments_AllowExcelOutputOnly] DEFAULT (0),
  CONSTRAINT [PK_MergeDocuments] PRIMARY KEY CLUSTERED ([ID]),
  CONSTRAINT [UQ__MergeDocuments_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 90)
)
ON [PRIMARY]
GO

ALTER TABLE [SCore].[MergeDocuments] WITH NOCHECK
  ADD CONSTRAINT [FK_MergeDocuments_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SCore].[MergeDocuments]
  NOCHECK CONSTRAINT [FK_MergeDocuments_DataObjects]
GO

ALTER TABLE [SCore].[MergeDocuments]
  ADD CONSTRAINT [FK_MergeDocuments_EntityTypes] FOREIGN KEY ([EntityTypeId]) REFERENCES [SCore].[EntityTypes] ([ID])
GO

ALTER TABLE [SCore].[MergeDocuments]
  ADD CONSTRAINT [FK_MergeDocuments_EntityTypes1] FOREIGN KEY ([LinkedEntityTypeId]) REFERENCES [SCore].[EntityTypes] ([ID])
GO

ALTER TABLE [SCore].[MergeDocuments]
  ADD CONSTRAINT [FK_MergeDocuments_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

ALTER TABLE [SCore].[MergeDocuments]
  ADD CONSTRAINT [FK_MergeDocuments_SharepointSites] FOREIGN KEY ([SharepointSiteId]) REFERENCES [SCore].[SharepointSites] ([ID])
GO

EXEC sys.sp_addextendedproperty N'MS_Description', N'The definitions of Merge Documents ', 'SCHEMA', N'SCore', 'TABLE', N'MergeDocuments'
GO