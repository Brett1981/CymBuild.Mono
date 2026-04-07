SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_GetOrgUnitByUser] 
(
	@UserID INT
)
RETURNS TABLE 
AS
RETURN 
(
	 SELECT 
       
        OriganisationalUnitId
    FROM [SCore].[Identities]
    WHERE IsActive = 1
      AND RowStatus = 1
      AND ID = @UserID
)
GO