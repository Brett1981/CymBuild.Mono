SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[OrganisationalUnitsUpsert] @ParentOrganisationalUnitGuid UNIQUEIDENTIFIER,
												@Name NVARCHAR(250),
												@AddressGuid UNIQUEIDENTIFIER,
												@ContactGuid UNIQUEIDENTIFIER,
												@OfficialAddressGuid UNIQUEIDENTIFIER,
												@OfficialContactGuid UNIQUEIDENTIFIER,
												@DepartmentPrefix NVARCHAR(10),
												@CostCentreCode NVARCHAR(50),
												@DefaultSecurityGroupGuid UNIQUEIDENTIFIER,
												@Guid UNIQUEIDENTIFIER OUT,
												@QuoteThreshold DECIMAL(19,2)
AS
BEGIN
	DECLARE @ParentOrganisationUnitID INT = -1,
			@pOrgNode				  HIERARCHYID,
			@AddressId				  INT,
			@ContactId				  INT,
			@OfficialAddressId		  INT,
			@OfficialContactId		  INT,
			@IsDivision				  BIT = 0,
			@IsBusinessUnit			  BIT = 0,
			@IsDepartment			  BIT = 0,
			@IsTeam					  BIT = 0,
			@DefaultSecurityGroupId		INT = -1,
			@CurrentParentOrgID			int = -1,
			@lc						  HIERARCHYID,
			@ID						int,
			@CurrentOrgNode			HIERARCHYID,
			@NewOrgNode				HIERARCHYID;

	SELECT	@CurrentParentOrgID = ParentID,
			@ID = id,
			@CurrentOrgNode = OrgNode
	FROM	OrganisationalUnits
	WHERE	(Guid = @Guid)

	SELECT	@AddressId = ID
	FROM	SCrm.Addresses
	WHERE	(Guid = @AddressGuid);

	SELECT	@ContactId = ID
	FROM	SCrm.Contacts
	WHERE	(Guid = @ContactGuid);

	SELECT	@DefaultSecurityGroupId = ID 
	FROM	SCore.Groups 
	WHERE	(Guid = @DefaultSecurityGroupGuid)

	SELECT	@OfficialAddressId = ID
	FROM	SCrm.Addresses
	WHERE	(Guid = @OfficialAddressGuid);

	SELECT	@OfficialContactId = ID
	FROM	SCrm.Contacts
	WHERE	(Guid = @OfficialContactGuid);

	SELECT	@ParentOrganisationUnitID = ID,
			@pOrgNode				  = OrgNode
	FROM	SCore.OrganisationalUnits
	WHERE	(Guid = @ParentOrganisationalUnitGuid);

	SELECT	@lc = MAX (OrgNode)
	FROM	SCore.OrganisationalUnits
	WHERE	OrgNode.GetAncestor (1) = @pOrgNode;

	SET @NewOrgNode = @pOrgNode.GetDescendant (	 @lc,
											 NULL
										 )

	SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
	BEGIN TRANSACTION;

	DECLARE @IsInsert BIT = 0;
	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
								@SchemeName = N'SCore',				-- nvarchar(255)
								@ObjectName = N'OrganisationalUnits',				-- nvarchar(255)
								@IncludeDefaultSecurity = 0,    -- bit
								@IsInsert = @IsInsert OUTPUT	-- bit
	
	IF (@IsInsert = 1)
	BEGIN
		/* Create the basic job record */
		INSERT	SCore.OrganisationalUnits
			 (RowStatus,
			  Guid,
			  Name,
			  AddressId,
			  ContactId,
			  OfficialAddressId,
			  OfficialContactId,
			  DepartmentPrefix,
			  CostCentreCode,
			  DefaultSecurityGroupId,
			  ParentID,
			  OrgNode,
			  QuoteThreshold)
		VALUES
			 (
				 1,		-- RowStatus - tinyint
				 @Guid, -- Guid - uniqueidentifier
				 @Name,
				 @AddressId,
				 @ContactId,
				 @OfficialAddressId,
				 @OfficialContactId,
				 @DepartmentPrefix,
				 @CostCentreCode,
				 @DefaultSecurityGroupId,
				 @ParentOrganisationUnitID,
				 @NewOrgNode,
				 @QuoteThreshold
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SCore.OrganisationalUnits
		SET		Name = @Name,
				AddressId = @AddressId,
				ContactId = @ContactId,
				OfficialAddressId = @OfficialAddressId,
				OfficialContactId = @OfficialContactId,
				DepartmentPrefix = @DepartmentPrefix,
				CostCentreCode = @CostCentreCode,
				DefaultSecurityGroupId = @DefaultSecurityGroupId,
				ParentID = @ParentOrganisationUnitID,
				OrgNode = CASE WHEN @ParentOrganisationUnitID <> ParentID THEN  @NewOrgNode ELSE OrgNode END,
				QuoteThreshold = @QuoteThreshold
		WHERE	(Guid = @Guid);

		IF (@ParentOrganisationUnitID <> @CurrentParentOrgID)
		BEGIN 
			EXEC  SCore.OrganisationalUnit_RetreeDescendants 
				@ParentID = @ID, 
				@NewParentOrgNode = @NewOrgNode, 
				@OldParentOrgNode = @CurrentOrgNode
		END
	END;
	COMMIT;
END;

GO