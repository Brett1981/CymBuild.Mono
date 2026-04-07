SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SCore].[UsersGet]
              --WITH SCHEMABINDING
AS 
SELECT  i.ID,
		i.RowStatus,
		i.RowVersion,
		i.Guid,
		i.FullName,
		i.EmailAddress,
		i.JobTitle,
		i.BillableRate,
		i.Signature,
		i.UserGuid
FROM    SCore.Identities i
WHERE   (i.RowStatus = 1)
GO