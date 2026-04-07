SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_PropertiesForEntityType]
	(
		@Guid UNIQUEIDENTIFIER,
		@UserId INT
	)
RETURNS TABLE
	     --WITH SCHEMABINDING 
AS
RETURN SELECT		p.RowStatus,
					p.RowVersion,
					p.Guid,
					p.Name,
					e.Guid	  AS EntityTypeGuid,
					ll.Guid	  AS LanguageLabelGuid,
					edt.Guid  AS EntityDataTypeGuid,
					p.IsReadOnly,
					p.IsImmutable,
					p.IsHidden,
					p.IsCompulsory,
					p.MaxLength,
					p.Precision,
					p.Scale,
					p.DoNotTrackChanges,
					epg.Guid  AS EntityPropertyGroupGuid,
					p.SortOrder,
					p.GroupSortOrder,
					ISNULL (   os.CanRead,
							   0
						   )  AS CanRead,
					ISNULL (   os.CanWrite,
							   0
						   )  AS CanWrite,
					edt.Name  AS EntityDataTypeName,
					ISNULL (   lt.Label,
							   p.Name
						   )  AS Label,
					ddld.Guid AS DropDownListDefinitionGuid,
					ddld.DetailPageUrl,
					ddld.InformationPageUrl,
					ddld.IsDetailWindowed,
					ddlde.Guid AS ForeignEntityTypeGuid,
					p.IsObjectLabel,
					p.IsParentRelationship,
					hobt.Guid AS EntityHoBTGuid,
					p.IsLongitude,
					p.IsLatitude,
					p.IsUppercase,
					p.IsIncludedInformation,
					p.FixedDefaultValue,
					p.SqlDefaultValueStatement,
					p.AllowBulkChange,
					p.IsVirtual,
					p.ShowOnMobile,
					p.IsAlwaysVisibleInGroup,
					p.IsAlwaysVisibleInGroup_Mobile,
					ddld.ExternalSearchPageUrl
	   FROM			SCore.EntityProperties					AS p
	   JOIN			SCore.EntityDataTypes					AS edt ON (p.EntityDataTypeID = edt.ID)
	   JOIN			SCore.EntityHobts						AS hobt ON (p.EntityHoBTID = hobt.ID)
	   JOIN			SCore.EntityTypes						AS e ON (hobt.EntityTypeID = e.ID)
	   JOIN			SCore.EntityPropertyGroups				AS epg ON (p.EntityPropertyGroupID = epg.ID)
	   JOIN			SUserInterface.DropDownListDefinitions AS ddld ON (ddld.ID = p.DropDownListDefinitionID)
	   JOIN			SCore.EntityTypes						AS ddlde ON (ddlde.ID = ddld.EntityTypeId)
	   JOIN			SCore.LanguageLabels					AS ll ON (ll.ID = p.LanguageLabelID)
	   OUTER APPLY	SCore.ObjectSecurityForUser (	p.Guid,
													@UserId
												)			AS os
	   OUTER APPLY	SCore.ObjectLabelForUser (	 p.LanguageLabelID,
												 @UserId
											 ) AS lt
	   WHERE		(e.Guid = @Guid)
				AND	(p.RowStatus NOT IN (0, 254))

GO