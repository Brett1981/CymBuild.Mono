SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[WorkflowStatusUpsert]
(
    @Guid						UNIQUEIDENTIFIER,
	@Enabled					BIT,
	@Name						NVARCHAR(200),
	@Description				NVARCHAR(400),
	@OrganisationUnitGuid		UNIQUEIDENTIFIER,
	@SortOrder					INT,
	@RequiresUserAction			BIT,
	@IsPredefined				BIT,
	@ShowInEnquiries			BIT,
	@ShowInQuotes				BIT,
	@ShowInJobs					BIT,
	@IsActiveStatus				BIT,
	@IsCustomerWaitingStatus	BIT,
	@IsCompleteStatus			BIT,
	@Colour						NVARCHAR(14),
	@Icon						NVARCHAR(100),
	@SendNotification			BIT,
	@AuthorisationNeeded		BIT,
	@IsAuthStatus				BIT
)
AS 
BEGIN 
	
	DECLARE @IsInsert BIT;
	DECLARE @OrganisationUnitID INT;

	--Get the org unit ID.
	SELECT @OrganisationUnitID = ID
	FROM SCore.OrganisationalUnits
	WHERE Guid = @OrganisationUnitGuid;


	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
								@SchemeName = N'SCore',				-- nvarchar(255)
								@ObjectName = N'WorkflowStatus',				-- nvarchar(255)
								@IsInsert = @IsInsert OUTPUT,	-- bit
								@IncludeDefaultSecurity = 1

	IF(@IsInsert = 1)
		BEGIN

			INSERT INTO [SCore].[WorkflowStatus]
			(
				Guid,
				RowStatus,
				Enabled,
				Name,
				Description,
				OrganisationalUnitId,
				SortOrder,
				RequiresUsersAction,
				IsPredefined,
				ShowInEnquiries,
				ShowInQuotes,
				ShowInJobs,
				IsActiveStatus,
				IsCustomerWaitingStatus,
				IsCompleteStatus,
				Colour,
				Icon,
				SendNotification,
				AuthorisationNeeded,
				IsAuthStatus
			)
			VALUES 
			(
				@Guid,
				1,
				@Enabled,
				@Name,
				@Description,
				@OrganisationUnitID,
				@SortOrder,
				@RequiresUserAction,
				@IsPredefined,
				@ShowInEnquiries,
				@ShowInQuotes,
				@ShowInJobs,
				@IsActiveStatus,
				@IsCustomerWaitingStatus,
				@IsCompleteStatus,
				@Colour,
				@Icon,
				@SendNotification,
				@AuthorisationNeeded,
				@IsAuthStatus
			)
		END;
	ELSE
		BEGIN
			UPDATE [SCore].[WorkflowStatus]
			SET
				Enabled					= @Enabled,
				Name					= @Name,
				Description				= @Description,
				OrganisationalUnitId	= @OrganisationUnitID,
				SortOrder				= @SortOrder,
				RequiresUsersAction		= @RequiresUserAction,
				IsPredefined			= @IsPredefined,
				ShowInEnquiries			= @ShowInEnquiries,
				ShowInQuotes			= @ShowInQuotes,
				ShowInJobs				= @ShowInJobs,
				IsActiveStatus			= @IsActiveStatus,
				IsCustomerWaitingStatus = @IsCustomerWaitingStatus,
				IsCompleteStatus		= @IsCompleteStatus,
				Colour					= @Colour,
				Icon					= @Icon,
				SendNotification		= @SendNotification,
				AuthorisationNeeded		= @AuthorisationNeeded,
				IsAuthStatus			= @IsAuthStatus

			WHERE Guid = @Guid;
		END;
END;
GO