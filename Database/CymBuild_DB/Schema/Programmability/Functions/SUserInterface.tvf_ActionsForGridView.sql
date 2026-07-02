SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SUserInterface].[tvf_ActionsForGridView]')
GO
PRINT (N'Create function [SUserInterface].[tvf_ActionsForGridView]')
GO

CREATE FUNCTION [SUserInterface].[tvf_ActionsForGridView]
(
    @Guid UNIQUEIDENTIFIER,
    @UserId INT
)
RETURNS TABLE
AS
RETURN
SELECT
    gva.RowStatus,
    gva.RowVersion,
    gva.Guid,
    eq.Statement,
    olfu.Label AS Title
FROM SUserInterface.GridViewActions AS gva
JOIN SCore.EntityQueries AS eq
  ON eq.ID = gva.EntityQueryId
JOIN SUserInterface.GridViewDefinitions AS gvd
  ON gvd.ID = gva.GridViewDefinitionId
JOIN SUserInterface.GridDefinitions AS gd
  ON gd.ID = gvd.GridDefinitionId
OUTER APPLY SCore.ObjectLabelForUser(gva.LanguageLabelId, @UserId) AS olfu
WHERE gva.RowStatus NOT IN (0, 254)
  AND eq.RowStatus NOT IN (0, 254)
  AND gvd.RowStatus NOT IN (0, 254)
  AND gd.RowStatus NOT IN (0, 254)
  AND gvd.Guid = @Guid
  AND NOT
  (
      gd.Code = N'BATCHEDTRANSACTIONS'
      AND gvd.Code = N'BATCHEDTRANSACTIONS'
      AND NOT EXISTS
      (
          SELECT
              1
          FROM SCore.UserGroups AS ug_fin
          JOIN SCore.Groups AS g_fin
            ON g_fin.ID = ug_fin.GroupID
          WHERE ug_fin.IdentityID = @UserId
            AND ug_fin.RowStatus NOT IN (0, 254)
            AND g_fin.RowStatus NOT IN (0, 254)
            AND
            (
                g_fin.Code = N'FINANCE'
                OR g_fin.Name IN (N'Finance', N'Finance Group')
            )
      )
  );
GO