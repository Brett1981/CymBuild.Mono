CREATE TABLE [SUserInterface].[GridViewTypes] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_GridViewTypes_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_GridViewTypes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DF_GridViewTypes_Name] DEFAULT (''),
  CONSTRAINT [PK_GridViewTypes] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
)
ON [METADATA]
GO

ALTER TABLE [SUserInterface].[GridViewTypes]
  ADD CONSTRAINT [FK_GridViewTypes_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO