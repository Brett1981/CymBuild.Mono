PRINT (N'Create sequence [SJob].[JobNumber]')
GO
CREATE SEQUENCE [SJob].[JobNumber]
  AS int
  INCREMENT BY 1
  MINVALUE 0
  NO CYCLE
  CACHE 
GO