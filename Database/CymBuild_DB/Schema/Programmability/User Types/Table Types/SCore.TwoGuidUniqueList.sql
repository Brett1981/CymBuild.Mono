PRINT (N'Create type [SCore].[TwoGuidUniqueList]')
GO
CREATE TYPE [SCore].[TwoGuidUniqueList] AS TABLE (
  [GuidValue] [uniqueidentifier] NOT NULL,
  [GuidValueTwo] [uniqueidentifier] NOT NULL,
  PRIMARY KEY CLUSTERED ([GuidValue], [GuidValueTwo]) WITH (FILLFACTOR = 90)
)
GO