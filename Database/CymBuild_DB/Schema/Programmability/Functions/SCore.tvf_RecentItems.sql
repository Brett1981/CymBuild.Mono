SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_RecentItems] 
(
    @UserId INT
)
RETURNS TABLE
            --WITH SCHEMABINDING
AS
RETURN  
SELECT      ri.ID,
            ri.Guid,
			ri.RowStatus,
			ri.RowVersion,
			ri.Datetime,
			ri.Label,
			ri.RecordGuid,
			i.Guid UserID,
			et.Guid EntityTypeGuid,
			et.DetailPageUrl,
			ol.Label AS EntityTypeLabel
FROM        SCore.RecentItems ri
JOIN		SCore.Identities i ON (i.ID = ri.UserID)
JOIN		SCore.EntityTypes et ON (et.ID = ri.EntityTypeID)
OUTER APPLY SCore.ObjectLabelForUser(et.LanguageLabelID, @UserId) ol
WHERE       (ri.RowStatus NOT IN (0, 254))
		AND	(ri.UserID = @UserId)
		AND	(et.DetailPageUrl <> N'')
GO