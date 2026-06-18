PRINT (N'Create table [SCore].[LegacySystems]')
GO
CREATE TABLE [SCore].[LegacySystems] (
  [ID] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_LegacySystems_Guid] DEFAULT (newid()),
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DF_LegacySystems_Name] DEFAULT ('')
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_LegacySystems] on table [SCore].[LegacySystems]')
GO
ALTER TABLE [SCore].[LegacySystems] WITH NOCHECK
  ADD CONSTRAINT [PK_LegacySystems] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO