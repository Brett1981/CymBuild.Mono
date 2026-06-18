PRINT (N'Create sequence [SSop].[ProjectNumber]')
GO
CREATE SEQUENCE [SSop].[ProjectNumber]
  AS int
  INCREMENT BY 1
  MINVALUE 0
  NO CYCLE
  CACHE 
GO