SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_Identities]
	(
		@UserId INT
	)
RETURNS TABLE
            --WITH SCHEMABINDING
AS
RETURN SELECT		i.ID,
				i.RowStatus,
				i.RowVersion,
				i.Guid,
				i.FullName,
				i.EmailAddress,
				ou.Name AS OrganisationalUnit,
				os.CanWrite
	   FROM			SCore.Identities			  AS i
	   JOIN		Score.OrganisationalUnits ou ON (ou.ID = i.OriganisationalUnitId)
	   OUTER APPLY	SCore.ObjectSecurityForUser (	i.Guid,
													@UserId
												) AS os
	   WHERE		(i.RowStatus NOT IN (0, 254))
			AND	(os.CanRead = 1)
			AND	(i.ID > -1);
GO