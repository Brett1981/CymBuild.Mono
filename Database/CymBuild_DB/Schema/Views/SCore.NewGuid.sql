SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create view [SCore].[NewGuid]')
GO
PRINT (N'Create view [SCore].[NewGuid]')
GO
CREATE VIEW [SCore].[NewGuid]
AS
SELECT NEWID() Guid
GO