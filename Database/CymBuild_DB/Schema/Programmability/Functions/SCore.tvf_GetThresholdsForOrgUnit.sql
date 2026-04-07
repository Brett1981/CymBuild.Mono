SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE FUNCTION [SCore].[tvf_GetThresholdsForOrgUnit] 
(
	@UserID INT
)
RETURNS TABLE 
AS
RETURN 
(
	 SELECT  og.QuoteThreshold AS QuoteThreshold
FROM [SCore].[Identities] as I
JOIN SCore.OrganisationalUnits AS og ON (og.ID = I.OriganisationalUnitId)
WHERE IsActive = 1
      AND I.RowStatus NOT IN (0,254)
      AND I.ID = @UserID
)
GO