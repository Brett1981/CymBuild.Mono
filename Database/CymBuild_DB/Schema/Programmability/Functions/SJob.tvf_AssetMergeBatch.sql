SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO



CREATE FUNCTION [SJob].[tvf_AssetMergeBatch]
	(
		@UserId INT
	)
RETURNS TABLE
       --WITH SCHEMABINDING
AS
RETURN SELECT		amb.ID,
					amb.RowStatus,
					amb.Guid,
					sa.AssetNumber AS SourceAssetNumber,
					ta.AssetNumber AS TargetAssetNumber,
					ci.FullName AS CreatedBy,
					chi.FullName AS CheckedBy,
					amb.IsComplete
	   FROM			SJob.AssetMergeBatch AS amb
	   JOIN			SJob.Assets AS sa ON (sa.ID = amb.SourceAssetId)
	   JOIN			SJob.Assets AS ta ON (ta.ID = amb.TargetAssetId)
	   JOIN			SCore.Identities AS ci ON (ci.ID = amb.CreatedByUserId)
	   JOIN			SCore.Identities AS chi ON (chi.ID = amb.CheckedByUserId)
	   WHERE		(amb.ID > 0)
				AND (amb.RowStatus NOT IN (0, 254))
				AND	(EXISTS
			(
					SELECT
							1
					FROM
							SCore.ObjectSecurityForUser_CanRead(amb.Guid, @UserId) oscr
			)
		)
GO