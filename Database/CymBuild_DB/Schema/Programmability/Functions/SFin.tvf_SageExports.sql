SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO



CREATE FUNCTION [SFin].[tvf_SageExports] 
(
    @UserId INT
)
RETURNS TABLE
     --WITH SCHEMABINDING
AS
RETURN 
SELECT  se.ID,
        se.RowStatus,
        se.RowVersion,
        se.Guid,
		se.InclusiveToDate,
        ou.Name AS OrganisationalUnit,
		COUNT(setr.ID) AS IncludedTransactions
FROM    SFin.SageExports se
LEFT JOIN	SFin.SageExportTransactions AS setr ON (setr.SageExportID = se.ID)
JOIN	SCore.OrganisationalUnits AS ou ON (ou.ID = se.OrganisationalUnitId)
WHERE   (se.RowStatus  NOT IN (0, 254))
	AND	(se.Id > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(se.Guid, @UserId) oscr
			)
		)
		AND	((EXISTS
			(				
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(ou.Guid, @UserId) oscr
			)
		) OR ou.ID < 0)
	GROUP BY se.ID, se.RowStatus, SE.RowVersion, se.Guid, se.InclusiveToDate, ou.Name
GO