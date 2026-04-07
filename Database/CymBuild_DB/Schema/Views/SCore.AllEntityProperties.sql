SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SCore].[AllEntityProperties]
               --WITH SCHEMABINDING 
AS
SELECT
        ep.ID,
		ep.RowStatus,
        ep.Guid,
        ep.Name,
        ep.SortOrder,
        ep.GroupSortOrder,
		ep.IsHidden,
        ROW_NUMBER() OVER (ORDER BY ep.IsHidden, epg.SortOrder, ep.GroupSortOrder) AS DisplayOrder,
        edt.Name AS EntityDataTypeName,
        epg.Name AS EntityPropertyGroupName,
		et.Guid AS EntityTypeGuid
FROM
        SCore.EntityProperties ep
    JOIN
        [SCore].[EntityHobts]      h
            ON (ep.EntityHoBTID = h.id)
    JOIN
        SCore.EntityTypes      et
            ON (et.ID = h.EntityTypeId)
    JOIN
        SCore.EntityDataTypes edt 
            ON (edt.ID = ep.EntityDataTypeID)
    JOIN
        SCore.EntityPropertyGroups epg 
            ON (epg.ID = ep.EntityPropertyGroupID)
GO