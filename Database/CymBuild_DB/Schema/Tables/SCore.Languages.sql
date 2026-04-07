CREATE TABLE [SCore].[Languages] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Languages_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Languages_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_Languages_Name] DEFAULT (''),
  [Locale] [nvarchar](50) NOT NULL CONSTRAINT [DF_Languages_Local] DEFAULT (''),
  CONSTRAINT [PK_Languages] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
)
ON [METADATA]
GO

CREATE UNIQUE INDEX [IX_UQ_Languages_Guid]
  ON [SCore].[Languages] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_Languages_Name]
  ON [SCore].[Languages] ([Name])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SCore].[Languages] WITH NOCHECK
  ADD CONSTRAINT [FK_Languages_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SCore].[Languages]
  NOCHECK CONSTRAINT [FK_Languages_DataObjects]
GO

ALTER TABLE [SCore].[Languages]
  ADD CONSTRAINT [FK_Languages_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

EXEC sys.sp_addextendedproperty N'MS_Description', N'A List of Languages to be used with Language Labels', 'SCHEMA', N'SCore', 'TABLE', N'Languages'
GO