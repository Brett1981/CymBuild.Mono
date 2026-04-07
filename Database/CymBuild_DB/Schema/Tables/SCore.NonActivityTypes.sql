CREATE TABLE [SCore].[NonActivityTypes] (
  [ID] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL DEFAULT (newid()),
  [Name] [nvarchar](100) NOT NULL CONSTRAINT [DF_NonActivityTypes_Name] DEFAULT (''),
  [RowStatus] [tinyint] NOT NULL DEFAULT (1),
  [RowVersion] [timestamp],
  PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO