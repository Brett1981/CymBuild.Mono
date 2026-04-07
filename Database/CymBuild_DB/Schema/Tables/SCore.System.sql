CREATE TABLE [SCore].[System] (
  [ID] [int] NOT NULL,
  [Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL,
  [RowVersion] [timestamp],
  [StandardPriceListID] [int] NOT NULL,
  CONSTRAINT [PK_System] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO