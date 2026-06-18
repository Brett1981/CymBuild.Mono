PRINT (N'Create table [SCore].[System]')
GO
CREATE TABLE [SCore].[System] (
  [ID] [int] NOT NULL,
  [Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL,
  [RowVersion] [timestamp],
  [StandardPriceListID] [int] NOT NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_System] on table [SCore].[System]')
GO
ALTER TABLE [SCore].[System] WITH NOCHECK
  ADD CONSTRAINT [PK_System] PRIMARY KEY CLUSTERED ([ID])
GO