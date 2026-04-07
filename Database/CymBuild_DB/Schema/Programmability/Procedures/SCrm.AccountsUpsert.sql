SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCrm].[AccountsUpsert]
	(	@Name NVARCHAR(250),
		@Code NVARCHAR(10),
		@AccountStatusGuid UNIQUEIDENTIFIER,
		@ParentAccountGuid UNIQUEIDENTIFIER,
		@IsPurchaseLedger BIT,
		@IsSalesLedger BIT,
		@IsLocalAuthority BIT,
		@IsFireAuthority BIT,
		@IsWaterAuthority BIT,
		@RelationshipManagerUserGuid UNIQUEIDENTIFIER,
		@CompanyRegistrationNumber NVARCHAR(50),
		@MainAccountContactGuid UNIQUEIDENTIFIER,
		@MainAccountAddressGuid UNIQUEIDENTIFIER,
		@Guid UNIQUEIDENTIFIER,
		@BillingInstruction NVARCHAR(MAX) -- NEW [CBLD-521]
	)
AS
BEGIN
	DECLARE @AccountStatusID		   INT,
			@ParentAccountID		   INT,
			@MainAccountAddressID	   INT,
			@MainAccountContactID	   INT,
			@RelationshipManagerUserID INT,
			@IsInsert BIT

	SELECT	@AccountStatusID = ID
	FROM	SCrm.AccountStatus
	WHERE	(Guid = @AccountStatusGuid);

	SELECT	@ParentAccountID = ID
	FROM	SCrm.Accounts
	WHERE	(Guid = @ParentAccountGuid);

	SELECT	@RelationshipManagerUserID = ID
	FROM	SCore.Identities
	WHERE	(Guid = @RelationshipManagerUserGuid);

	SELECT	@MainAccountAddressID = ID
	FROM	SCrm.AccountAddresses
	WHERE	(Guid = @MainAccountAddressGuid);

	IF (@MainAccountAddressID < 0)
	BEGIN
		SELECT		TOP (1) @MainAccountAddressID = aa.ID
		FROM		SCrm.AccountAddresses AS aa
		JOIN		SCrm.Accounts		  AS a ON (a.ID = aa.AccountID)
		WHERE		(a.Guid = @Guid)
		ORDER BY	aa.ID;
	END;

	SELECT	@MainAccountContactID = ID
	FROM	SCrm.AccountContacts
	WHERE	(Guid = @MainAccountContactGuid);

	IF (@MainAccountContactID < 0)
	BEGIN
		SELECT		TOP (1) @MainAccountContactID = ac.ID
		FROM		SCrm.AccountContacts AS ac
		JOIN		SCrm.Accounts		 AS a ON (a.ID = ac.AccountID)
		WHERE		(a.Guid = @Guid)
		ORDER BY	ac.ID;
	END;

	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SCrm',				-- nvarchar(255)
							@ObjectName = N'Accounts',				-- nvarchar(255)
							@IncludeDefaultSecurity = 0,
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
	BEGIN
		INSERT	SCrm.Accounts
			 (RowStatus,
			  Guid,
			  Name,
			  Code,
			  AccountStatusID,
			  ParentAccountID,
			  IsPurchaseLedger,
			  IsSalesLedger,
			  IsLocalAuthority,
			  IsFireAuthority,
			  IsWaterAuthority,
			  RelationshipManagerUserId,
			  CompanyRegistrationNumber,
			  MainAccountAddressId,
			  MainAccountContactId,
			  BillingInstruction) -- NEW [CBLD-521]
		VALUES
			 (
				 1,								-- RowStatus - tinyint
				 @Guid,							-- Guid - uniqueidentifier
				 @Name,							-- Name - nvarchar(250)
				 @Code,							-- Code - nchar(10)
				 @AccountStatusID,				-- AccountStatusID - int
				 @ParentAccountID,				-- ParentAccountID - int
				 @IsPurchaseLedger,				-- IsPurchaseLedger - bit
				 @IsSalesLedger,				-- IsSalesLedger - bit
				 @IsLocalAuthority,				-- IsLocalAuthority - bit
				 @IsFireAuthority,				-- IsFireAuthority - bit
				 @IsWaterAuthority,				-- IsWaterAuthority - bit
				 @RelationshipManagerUserID,	-- RelationshipManagerUserId - int
				 @CompanyRegistrationNumber,	-- CompanyRegistrationNumber - nvarchar(50)
				 @MainAccountAddressID,
				 @MainAccountContactID,
				 @BillingInstruction
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SCrm.Accounts
		SET		Name = @Name,
				Code = @Code,
				AccountStatusID = @AccountStatusID,
				ParentAccountID = ParentAccountID,
				IsPurchaseLedger = @IsPurchaseLedger,
				IsSalesLedger = @IsSalesLedger,
				IsLocalAuthority = @IsLocalAuthority,
				IsFireAuthority = @IsFireAuthority,
				IsWaterAuthority = @IsWaterAuthority,
				RelationshipManagerUserId = @RelationshipManagerUserID,
				CompanyRegistrationNumber = @CompanyRegistrationNumber,
				MainAccountAddressId = @MainAccountAddressID,
				MainAccountContactId = @MainAccountContactID,
				BillingInstruction = @BillingInstruction -- NEW [CBLD-521]
		WHERE	(Guid = @Guid);
	END;


	/* Tempoary addition until have have the System Bus */

	DECLARE @FilingObjectName NVARCHAR(250) = @Name + N' ' + @Code,
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

	EXEC SOffice.TargetObjectUpsert @EntityTypeGuid = N'40476ecc-d19a-4de9-90df-e1f45cd72fb2',	-- uniqueidentifier
									@RecordGuid = @Guid,										-- uniqueidentifier
									@Number = 0,												-- bigint
									@Name = @FilingObjectName,									-- nvarchar(250)	
									@FilingLocation = @FilingLocation;

END;
GO