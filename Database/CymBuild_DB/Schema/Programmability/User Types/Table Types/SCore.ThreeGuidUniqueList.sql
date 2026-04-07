PRINT (N'Create type [SCore].[ThreeGuidUniqueList]')
GO
CREATE TYPE [SCore].[ThreeGuidUniqueList] AS TABLE (
  [GuidValue] [uniqueidentifier] NOT NULL,
  [GuidValueTwo] [uniqueidentifier] NOT NULL,
  [GuidValueThree] [uniqueidentifier] NOT NULL,
  PRIMARY KEY CLUSTERED ([GuidValue], [GuidValueTwo], [GuidValueThree]) WITH (FILLFACTOR = 90)
)
GO