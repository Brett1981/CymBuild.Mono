SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create view [SFin].[CreditTermsView]')
GO
CREATE VIEW [SFin].[CreditTermsView]
    -- --WITH SCHEMABINDING
    AS
    SELECT [ID]
      ,[RowStatus]
      ,[RowVersion]
      ,[Guid]
      ,[Name]
      ,[DueDays]
  FROM [SFin].[CreditTerms]
GO