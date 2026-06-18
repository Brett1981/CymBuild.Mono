PRINT (N'Create sequence [SFin].[TransactionNumber]')
GO
CREATE SEQUENCE [SFin].[TransactionNumber]
  AS int
  INCREMENT BY 1
  MINVALUE 0
  NO CYCLE
  CACHE 
GO