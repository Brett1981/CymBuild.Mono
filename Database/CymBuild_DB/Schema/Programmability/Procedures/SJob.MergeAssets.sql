SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SJob].[MergeAssets]
(
	@FromAssetGuid UNIQUEIDENTIFIER,
	@ToAssetGuid UNIQUEIDENTIFIER
)
AS
BEGIN 
	DECLARE	@FromAssetID INT,
			@ToAssetID INT

	SELECT	@FromAssetID = ID
	FROM	SJob.Assets
	WHERE	(guid = @FromAssetGuid)

	SELECT	@ToAssetID = ID 
	FROM	SJob.Assets
	WHERE	(Guid = @ToAssetGuid)

	UPDATE	SJob.Assets
	SET		ParentAssetID = @ToAssetID
	WHERE	ParentAssetID = @FromAssetID

	UPDATE	SJob.Jobs
	SET		UprnID = @ToAssetID
	WHERE	(UprnID = @FromAssetID)

	UPDATE	SSop.Enquiries 
	SET		PropertyId = @ToAssetID
	WHERE	(PropertyId = @FromAssetID)

	UPDATE	SSop.Quotes 
	SET		UprnId = @ToAssetID
	WHERE	(UprnId = @FromAssetID)

	UPDATE	SJob.Assets
	SET		RowStatus = 254
	WHERE	(Guid = @FromAssetGuid)
		
END
GO