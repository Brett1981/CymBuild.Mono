SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_MergeDocumentsForEntityType]
	(
		@Guid UNIQUEIDENTIFIER,
		@UserId INT
	)
RETURNS TABLE
AS
RETURN SELECT		md.RowStatus,
					md.RowVersion,
					md.Guid,
					md.Name,
					md.FilenameTemplate,
					ss.SiteIdentifier AS DriveId,
					md.DocumentId,
					e.Guid AS EntityTypeGuid,
					le.Guid AS LinkedEntityTypeGuid,
					md.AllowPDFOutputOnly,
					md.AllowExcelOutputOnly,
					md.ProduceOneOutputPerRow
	   FROM			SCore.MergeDocuments					AS md
	   JOIN			SCore.EntityTypesV						AS e ON (md.EntityTypeID = e.ID)
	   JOIN			SCore.EntityTypesV						AS le ON (md.LinkedEntityTypeID = le.ID)
	   JOIN			SCore.SharepointSites					AS ss ON (ss.ID = md.SharepointSiteId)
	   OUTER APPLY	SCore.ObjectSecurityForUser (	md.Guid,
													@UserId
												)			AS os
	   WHERE		(e.Guid = @Guid)
				AND	(md.RowStatus NOT IN (0, 254))
				AND	(os.CanRead = 1);
GO