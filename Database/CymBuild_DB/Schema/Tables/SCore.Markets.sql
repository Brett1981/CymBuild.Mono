PRINT (N'Create table [SCore].[Markets]')
GO
CREATE TABLE [SCore].[Markets] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Markets_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Markets_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](150) NOT NULL CONSTRAINT [DF_Markets_Name] DEFAULT ('')
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Markets] on table [SCore].[Markets]')
GO
ALTER TABLE [SCore].[Markets] WITH NOCHECK
  ADD CONSTRAINT [PK_Markets] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create foreign key [FK_Markets_RowStatus] on table [SCore].[Markets]')
GO
ALTER TABLE [SCore].[Markets] WITH NOCHECK
  ADD CONSTRAINT [FK_Markets_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO