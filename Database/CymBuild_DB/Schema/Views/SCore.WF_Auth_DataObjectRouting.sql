SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
/* =============================================================================
   SCore.WF_Auth_DataObjectRouting
   Purpose:
   - Resolve OrganisationalUnitId for a DataObjectGuid by looking up the entity table
   - Provide a single place for workflow resolution logic to join to

   Notes:
   - DataObjects only has EntityTypeId, not OU.
   - OU is derived from the entity row (Jobs/Enquiries/Quotes).
============================================================================= */
CREATE VIEW [SCore].[WF_Auth_DataObjectRouting]
    --WITH SCHEMABINDING
AS
SELECT
    d.Guid            AS DataObjectGuid,
    d.EntityTypeId    AS EntityTypeId,

    /* Derive OU from entity tables. */
    COALESCE(j.OrganisationalUnitId, e.OrganisationalUnitId, q.OrganisationalUnitId) AS OrganisationalUnitId,

    /* Optional: trace which table resolved OU (helps diagnostics). */
    CASE
        WHEN j.Guid IS NOT NULL THEN 'SJob.Jobs'
        WHEN e.Guid IS NOT NULL THEN 'SSop.Enquiries'
        WHEN q.Guid IS NOT NULL THEN 'SSop.Quotes'
        ELSE NULL
    END AS ResolvedFrom
FROM SCore.DataObjects d
LEFT JOIN SJob.Jobs      j ON j.Guid = d.Guid AND j.RowStatus NOT IN (0,254)
LEFT JOIN SSop.Enquiries e ON e.Guid = d.Guid AND e.RowStatus NOT IN (0,254)
LEFT JOIN SSop.Quotes    q ON q.Guid = d.Guid AND q.RowStatus NOT IN (0,254);
GO