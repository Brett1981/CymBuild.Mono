SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW	[SCore].[EntityPropertiesV]
             --WITH SCHEMABINDING
AS
SELECT	ep.ID,
		ep.RowStatus,
		ep.RowVersion,
		ep.Guid,
		ep.Name,
		ep.LanguageLabelID,
		ep.EntityHoBTID,
		ep.EntityDataTypeID,
		ep.IsReadOnly,
		ep.IsImmutable,
		ep.IsUppercase,
		ep.IsHidden,
		ep.IsCompulsory,
		ep.MaxLength,
		ep.Precision,
		ep.Scale,
		ep.DoNotTrackChanges,
		ep.EntityPropertyGroupID,
		ep.SortOrder,
		ep.GroupSortOrder,
		ep.IsObjectLabel,
		ep.DropDownListDefinitionID,
		ep.IsParentRelationship,
		ep.IsLongitude,
		ep.IsLatitude,
		ep.IsIncludedInformation,
		ep.FixedDefaultValue,
		ep.SqlDefaultValueStatement,
		ep.AllowBulkChange,
		ep.IsVirtual
FROM	Score.[EntityProperties] ep
WHERE	(ep.[RowStatus] NOT IN (0, 254))
GO