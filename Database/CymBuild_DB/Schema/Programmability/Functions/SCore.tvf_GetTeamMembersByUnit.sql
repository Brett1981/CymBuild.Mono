SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_GetTeamMembersByUnit]
(
    @OrganisationalUnitId INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        Id AS IdentityId,
        Guid,
        FullName,
        OriganisationalUnitId,
        EmailAddress
    FROM [SCore].[Identities]
    WHERE IsActive = 1
      AND RowStatus = 1
      AND OriganisationalUnitId = @OrganisationalUnitId
)
GO