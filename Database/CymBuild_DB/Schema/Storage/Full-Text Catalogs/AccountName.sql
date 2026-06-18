PRINT (N'Create full-text catalog [AccountName]')
GO
CREATE FULLTEXT CATALOG [AccountName]
  WITH ACCENT_SENSITIVITY = OFF
  AUTHORIZATION [dbo]
GO