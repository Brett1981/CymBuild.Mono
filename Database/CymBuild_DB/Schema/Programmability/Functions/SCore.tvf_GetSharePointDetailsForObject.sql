SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

create FUNCTION [SCore].[tvf_GetSharePointDetailsForObject]
(	
	@EntityTypeGuid UNIQUEIDENTIFIER,
	@ObjectID BIGINT,
	@ParentObjectID BIGINT
)
RETURNS TABLE 

AS
return
	SELECT	ss.SiteIdentifier AS SiteIdentifier,
			ses1.Name AS Name ,
			ses1.UseLibraryPerSplit,
			ses1.PrimaryKeySplitInterval,
			ses1.ParentStructureID,
			ISNULL(ses2.Name, N'') AS ParentName,
			ISNULL(ses2.UseLibraryPerSplit, 0) AS ParentUseLibraryPerSplit,
			ISNULL(ses2.PrimaryKeySplitInterval, -1) AS ParentPrimaryKeySplitInterval,
			ISNULL(@ParentObjectID, -1) AS ParentObjectID
	FROM	SCore.SharepointEntityStructure ses1
	LEFT JOIN	SCore.SharepointEntityStructure ses2 ON (ses2.Id = ses1.ParentStructureID)
	JOIN	SCore.EntityTypesV et1 ON (et1.ID = ses1.EntityTypeID)
	JOIN	SCore.SharepointSites ss ON (ses1.SharePointSiteID = ss.ID)	
	WHERE	(et1.Guid = @EntityTypeGuid)
		AND	(@ObjectID BETWEEN ses1.StartPrimaryKey AND ses1.EndPrimaryKey)
		AND	(ses1.RowStatus = 1)
		AND	(
				(@ParentObjectID BETWEEN ses2.StartPrimaryKey AND ses2.EndPrimaryKey)
				OR (@ParentObjectID = -1)
			)	
GO