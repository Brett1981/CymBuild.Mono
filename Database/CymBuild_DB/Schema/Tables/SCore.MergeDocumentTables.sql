CREATE TABLE [SCore].[MergeDocumentTables] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_MergeDocumentTables_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_MergeDocumentTables_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [MergeDocumentId] [int] NOT NULL CONSTRAINT [DF_MergeDocumentTables_MergeDocumentId] DEFAULT (-1),
  [TableName] [nvarchar](50) NOT NULL CONSTRAINT [DF_MergeDocumentTables_TableName] DEFAULT (''),
  [LinkedEntityTypeId] [int] NOT NULL CONSTRAINT [DF_MergeDocumentTables_LinkedEntityTypeId] DEFAULT (-1),
  CONSTRAINT [PK_MergeDocumentTables] PRIMARY KEY CLUSTERED ([ID]),
  CONSTRAINT [UQ__MergeDocumentTables_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 90)
)
ON [PRIMARY]
GO

ALTER TABLE [SCore].[MergeDocumentTables] WITH NOCHECK
  ADD CONSTRAINT [FK_MergeDocumentTables_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SCore].[MergeDocumentTables]
  NOCHECK CONSTRAINT [FK_MergeDocumentTables_DataObjects]
GO

ALTER TABLE [SCore].[MergeDocumentTables]
  ADD CONSTRAINT [FK_MergeDocumentTables_EntityTypes] FOREIGN KEY ([LinkedEntityTypeId]) REFERENCES [SCore].[EntityTypes] ([ID])
GO

ALTER TABLE [SCore].[MergeDocumentTables]
  ADD CONSTRAINT [FK_MergeDocumentTables_MergeDocuments] FOREIGN KEY ([MergeDocumentId]) REFERENCES [SCore].[MergeDocuments] ([ID]) ON DELETE CASCADE
GO

ALTER TABLE [SCore].[MergeDocumentTables]
  ADD CONSTRAINT [FK_MergeDocumentTables_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

EXEC sys.sp_addextendedproperty N'MS_Description', N'The definitions of Talbes for Merge Documents ', 'SCHEMA', N'SCore', 'TABLE', N'MergeDocumentTables'
GO