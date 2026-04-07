PRINT (N'Create table [SCore].[Sectors]')
GO
CREATE TABLE [SCore].[Sectors] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Sectors_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Sectors_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Code] [nvarchar](20) NOT NULL CONSTRAINT [DF_Sectors_Code] DEFAULT (''),
  [Name] [nvarchar](150) NOT NULL CONSTRAINT [DF_Sectors_Name] DEFAULT (''),
  [Description] [nvarchar](max) NOT NULL CONSTRAINT [DF_Sectors_Description] DEFAULT ('')
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Sectors] on table [SCore].[Sectors]')
GO
ALTER TABLE [SCore].[Sectors] WITH NOCHECK
  ADD CONSTRAINT [PK_Sectors] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create foreign key [FK_Sectors_RowStatus] on table [SCore].[Sectors]')
GO
ALTER TABLE [SCore].[Sectors] WITH NOCHECK
  ADD CONSTRAINT [FK_Sectors_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO