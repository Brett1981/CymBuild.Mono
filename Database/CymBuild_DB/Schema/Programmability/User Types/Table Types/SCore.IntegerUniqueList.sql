PRINT (N'Create type [SCore].[IntegerUniqueList]')
GO
CREATE TYPE [SCore].[IntegerUniqueList] AS TABLE (
  [IntValue] [int] NOT NULL,
  PRIMARY KEY CLUSTERED ([IntValue])
)
GO