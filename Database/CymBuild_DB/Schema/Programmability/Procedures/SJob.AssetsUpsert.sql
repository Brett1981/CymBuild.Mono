SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SJob].[AssetsUpsert]
	(	@ParentAssetGuid UNIQUEIDENTIFIER,
		@Name NVARCHAR(100),
		@Number NVARCHAR(50),
		@AddressLine1 NVARCHAR(50),
		@AddressLine2 NVARCHAR(50),
		@AddressLine3 NVARCHAR(50),
		@Town NVARCHAR(50),
		@CountyGuid UNIQUEIDENTIFIER,
		@Postcode NVARCHAR(50),
		@CountryGuid UNIQUEIDENTIFIER,
		@LocalAuthorityAccountGuid UNIQUEIDENTIFIER,
		@FireAuthorityAccountGuid UNIQUEIDENTIFIER,
		@WaterAuthorityAccountGuid UNIQUEIDENTIFIER,
		@Latitude DECIMAL(9, 6),
		@Longitude DECIMAL(9, 6),
		@IsHighRiskBuilding BIT,
		@IsComplexBuilding BIT,
		@BuildingHeightInMetres DECIMAL(9,2),
		@OwnerAccountGuid UNIQUEIDENTIFIER,
		@Guid UNIQUEIDENTIFIER,
		@GovernmentUPRN NVARCHAR(20)
		
	)
AS
BEGIN
	DECLARE @ParentAssetID		 INT		  = -1,
			@LocalAuthorityAccountID INT,
			@FireAuthorityAccountID	 INT,
			@WaterAuthorityAccountID INT,
			@OwnerAccountID INT,	
			@FormattedAddressComma	 NVARCHAR(600),
			@FormattedAddressCR		 NVARCHAR(600),
			@IsInsert				 BIT		  = 0,
			@UPRN					 INT,
			@CountyID				 INT,
			@CountyName				 NVARCHAR(50),
			@CountryID				 INT;

	SELECT	@ParentAssetID = ID
	FROM	SJob.Assets
	WHERE	(Guid = @ParentAssetGuid);

	SELECT	@LocalAuthorityAccountID = ID
	FROM	SCrm.Accounts
	WHERE	(Guid = @LocalAuthorityAccountGuid);

	SELECT	@FireAuthorityAccountID = ID
	FROM	SCrm.Accounts
	WHERE	(Guid = @FireAuthorityAccountGuid);

	SELECT	@WaterAuthorityAccountID = ID
	FROM	SCrm.Accounts
	WHERE	(Guid = @WaterAuthorityAccountGuid);

	SELECT	@OwnerAccountID = ID
	FROM	SCrm.Accounts
	WHERE	(Guid = @OwnerAccountGuid);

	SELECT	@CountyID	= ID,
			@CountyName = Name
	FROM	SCrm.Counties
	WHERE	(Guid = @CountyGuid);

	SELECT	@CountryID = ID
	FROM	SCrm.Countries
	WHERE	(Guid = @CountryGuid);

	SELECT	@FormattedAddressComma = SCore.FormatAddress (	 N'',
															 @Number,
															 @AddressLine1,
															 @AddressLine2,
															 @AddressLine3,
															 @Town,
															 @CountyName,
															 @Postcode,
															 N', '
														 ),
			@FormattedAddressCR	   = SCore.FormatAddress (	 N'',
															 @Number,
															 @AddressLine1,
															 @AddressLine2,
															 @AddressLine3,
															 @Town,
															 @CountyName,
															 @Postcode,
															 CHAR (13)
														 );

    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SJob',				-- nvarchar(255)
							@ObjectName = N'Assets',				-- nvarchar(255)
							@IncludeDefaultSecurity = 0,
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN

		INSERT	SJob.Assets
			 (RowStatus,
			  Guid,
			  ParentAssetID,
			  Name,
			  Number,
			  AddressLine1,
			  AddressLine2,
			  AddressLine3,
			  Town,
			  CountyId,
			  Postcode,
			  CountryId,
			  LocalAuthorityAccountID,
			  WaterAuthorityAccountID,
			  FireAuthorityAccountID,
			  FormattedAddressComma,
			  FormattedAddressCR,
			  Latitude,
			  Longitude,
			  IsHighRiskBuilding,
			  IsComplexBuilding,
			  BuildingHeightInMetres,
			  OwnerAccountId,
			  GovernmentUPRN)
		VALUES
			 (
				 0,
				 @Guid,
				 @ParentAssetID,
				 @Name,
				 @Number,
				 @AddressLine1,
				 @AddressLine2,
				 @AddressLine3,
				 @Town,
				 @CountyID,
				 @Postcode,
				 @CountryID,
				 @LocalAuthorityAccountID,
				 @WaterAuthorityAccountID,
				 @FireAuthorityAccountID,
				 @FormattedAddressComma,
				 @FormattedAddressCR,
				 @Latitude,
				 @Longitude,
				 @IsHighRiskBuilding,
				 @IsComplexBuilding,
				 @BuildingHeightInMetres,
				 @OwnerAccountID,
				 @GovernmentUPRN
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SJob.Assets
		SET		ParentAssetID = @ParentAssetID,
				Name = @Name,
				Number = @Number,
				AddressLine1 = @AddressLine1,
				AddressLine2 = @AddressLine2,
				AddressLine3 = @AddressLine3,
				Town = @Town,
				CountyId = @CountyID,
				Postcode = @Postcode,
				@CountryID = @CountryID,
				LocalAuthorityAccountID = @LocalAuthorityAccountID,
				WaterAuthorityAccountID = @WaterAuthorityAccountID,
				FireAuthorityAccountID = @FireAuthorityAccountID,
				FormattedAddressComma = @FormattedAddressComma,
				FormattedAddressCR = @FormattedAddressCR,
				Latitude = @Latitude,
				Longitude = @Longitude,
				IsHighRiskBuilding = @IsHighRiskBuilding,
				IsComplexBuilding = @IsComplexBuilding,
				BuildingHeightInMetres = @BuildingHeightInMetres,
				OwnerAccountId = @OwnerAccountID,
				GovernmentUPRN = @GovernmentUPRN
		WHERE	(Guid = @Guid);
	END;

	IF (@IsInsert = 1)
	BEGIN
		SELECT	@UPRN = NEXT VALUE FOR SJob.UPRN;

		UPDATE	SJob.Assets
		SET		AssetNumber = @UPRN,
				RowStatus = 1
		WHERE	(Guid = @Guid);
	END;

	/* Tempoary addition until have have the System Bus */

	DECLARE @FilingObjectName NVARCHAR(250),
			@FilingLocation	  NVARCHAR(MAX);

	SELECT	@FilingLocation =
			(
				SELECT ss.SiteIdentifier,
					spf.FolderPath
				FROM	SCore.ObjectSharePointFolder AS spf
				JOIN	SCore.SharepointSites ss ON (ss.ID = spf.SharepointSiteId)
				WHERE	(spf.ObjectGuid = @Guid)
				FOR JSON PATH
			);

	SELECT	@FilingObjectName = p.Name + N' ' + p.FormattedAddressComma,
			@UPRN			  = p.AssetNumber
	FROM	SJob.Assets AS p
	WHERE	(p.Guid = @Guid);

	EXEC SOffice.TargetObjectUpsert @EntityTypeGuid = N'2cfbff39-93cd-436b-b8ca-b2fcf7609707',	-- uniqueidentifier
									@RecordGuid = @Guid,										-- uniqueidentifier
									@Number = @UPRN,										-- bigint
									@Name = @FilingObjectName,									-- nvarchar(250)
									@FilingLocation = @FilingLocation

END;
GO