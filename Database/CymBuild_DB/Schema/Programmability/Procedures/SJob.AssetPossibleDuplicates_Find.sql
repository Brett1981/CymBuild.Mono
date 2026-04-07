SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SJob].[AssetPossibleDuplicates_Find]
AS
BEGIN
	DECLARE	@PossibleDuplicates TABLE 
	(
		Guid UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
		SourceAssetID INT NOT NULL, 
		TargetAssetID INT NOT NULL
	)

	INSERT INTO @PossibleDuplicates
		 (Guid, SourceAssetID, TargetAssetID)
	SELECT	NEWID (),			-- Guid - uniqueidentifier
			a.ID,				-- SourceAssetID - int
			PossibleMatches.ID -- TargetAssetID - int
	FROM	SJob.Assets AS a
	CROSS APPLY
			(
				SELECT	a2.ID
				FROM	SJob.Assets AS a2
				WHERE	(a.ID <> a2.ID)
					AND (EXISTS
					(
						SELECT	1
						FROM	SJob.Assets AS a3
						WHERE	(a2.ID			   = a3.ID)
							AND (a3.AssetNumber	   > a.AssetNumber)
							AND (a3.RowStatus NOT IN (0, 254))
							AND
							  (
								  (
									  (a.Postcode  = a3.Postcode)
								  AND (a.Postcode  <> N'')
								  AND (a3.Postcode <> N'')
								  AND (a.Number	   = a3.Number)
								  AND (a.Number	   <> N'')
								  AND (a3.Number   <> N'')
								  )
							   OR
								(
									(a.Latitude	   = a3.Latitude)
								AND (a.Longitude   = a3.Longitude)
								AND (a3.Latitude   <> 0)
								AND (a.Latitude	   <> 0)
								)
							  )
					)
						)
			)			AS PossibleMatches
	WHERE	(PossibleMatches.ID IS NOT NULL)
		AND	(NOT EXISTS
		(
			SELECT	1
			FROM	SJob.AssetPossibleDuplicates AS apd
			WHERE	(apd.SourceAssetID = a.ID)
				AND	(apd.TargetAssetID = PossibleMatches.ID)
		)
			)

	DECLARE	@GuidList SCore.GuidUniqueList

	INSERT	@GuidList
		 (GuidValue)
	SELECT	Guid
	FROM	@PossibleDuplicates AS pd


	DECLARE @IsInsert BIT;
	EXEC SCore.DataObjectBulkUpsert @GuidList = @GuidList,				-- GuidUniqueList
									@SchemeName = N'SJob',				-- nvarchar(255)
									@ObjectName = N'AssetPossibleDuplicates',				-- nvarchar(255)
									@IncludeDefaultSecurity = 0,	-- bit
									@IsInsert = @IsInsert OUTPUT	-- bit
	

	INSERT INTO SJob.AssetPossibleDuplicates
		 (RowStatus, Guid, SourceAssetID, TargetAssetID, IsDifferent, IsDuplicate)
	SELECT	1,					-- RowStatus - tinyint
			pd.Guid,			-- Guid - uniqueidentifier
			pd.TargetAssetID,				-- SourceAssetID - int
			pd.SourceAssetID, -- TargetAssetID - int
			0,					-- IsDifferent - bit
			0					-- IsComplete - bit
	FROM	@PossibleDuplicates AS pd

END;
GO