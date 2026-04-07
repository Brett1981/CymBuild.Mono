SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW	[SCore].[ObjectSharePointPaths]
--             --WITH SCHEMABINDING
AS 
SELECT	ospf.ObjectGuid,
		ss.SiteIdentifier SharePointSiteIdentifier, 
		ospf.FolderPath,
		ss.SiteUrl + N'/' + ospf.FolderPath as FullSharePointUrl
FROM	SCore.ObjectSharePointFolder ospf 
JOIN	SCore.SharepointSites ss ON (ss.ID = ospf.SharepointSiteId)
GO