PRINT (N'Create sequence [SSop].[QuoteNumber]')
GO
CREATE SEQUENCE [SSop].[QuoteNumber]
  AS int
  INCREMENT BY 1
  MINVALUE 0
  NO CYCLE
  CACHE 
GO