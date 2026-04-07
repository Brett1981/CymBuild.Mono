SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[WorkflowUpsert]
	(	
		@Guid					UNIQUEIDENTIFIER,
		@RowStatus				TINYINT,
		@EntityTypeGuid			UNIQUEIDENTIFIER,
		@Name					NVARCHAR(100),
		@Description			NVARCHAR(400),
		@Enabled				BIT,
		@OrganisationalUnitGuid UNIQUEIDENTIFIER
	)
AS
BEGIN
	SET NOCOUNT ON 

	DECLARE @UserID INT;--
	DECLARE @OrganisationalUnitId INT;
	DECLARE @EntityTypeID INT;
	DECLARE @EntityHoBTID INT;
	


	--Get the current user ID.
	SELECT @UserID = ISNULL(CONVERT(int, SESSION_CONTEXT(N'user_id')), -1);

	
	--Get the user's organisation unit.
	--SELECT @OrganisationalUnitId = OriganisationalUnitId
	--FROM SCore.Identities
	--WHERE ID = @UserID;

	SELECT @OrganisationalUnitId = ID
	FROM SCore.OrganisationalUnits
	WHERE Guid = @OrganisationalUnitGuid;


	--Check if the current workflow is a default one (will have the OrganisationalUnitId set to -1
	--If exists, reset to -1. Default workflows should not have their org unit updated!
	IF(EXISTS(SELECT 1 FROM SCore.Workflow WHERE Guid = @Guid AND OrganisationalUnitId = -1))
	
		SET @OrganisationalUnitId = -1;

	--Get the Entity Type ID.
	SELECT @EntityTypeID = ID 
	FROM SCore.EntityTypes
	WHERE Guid = @EntityTypeGuid;

	--Next, get the Entity Hobt ID
	SELECT @EntityHoBTID = etb.ID 
	FROM SCore.EntityHobts AS etb
	LEFT JOIN SCore.EntityTypes AS et ON (et.Name = etb.ObjectName)
	WHERE et.ID = @EntityTypeID;

	
	IF(@OrganisationalUnitId <> -1)
	BEGIN
	-- Throw an error if the user is trying to create a workflow for an entity type
	-- that already has an enabled workflow against it.
		IF(EXISTS
			(
				SELECT 1 
				FROM SCore.Workflow
				JOIN SCore.Identities AS I ON (I.ID = @UserID)
				WHERE 
					(OrganisationalUnitId = @OrganisationalUnitId) AND
					(EntityTypeID = @EntityTypeID) AND
					(Enabled = 1) 
			) AND @Enabled = 1
		)
		BEGIN 
			;THROW 60000, N'There is already an enabled workflow this entity type. Please, disable the active one before creating a new one. ', 1
		END
	END;


	DECLARE @IsInsert BIT = 0;
	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
								@SchemeName = N'SCore',			-- nvarchar(255)
								@ObjectName = N'Workflow',		-- nvarchar(255)
								@IncludeDefaultSecurity = 1,
								@IsInsert = @IsInsert OUTPUT;	-- bit

	IF (@IsInsert = 1)
	BEGIN


		 --Create a temporary table to hold the results - will be used
		 --to add default transitions to c
		CREATE TABLE #WorkflowTransitions
		(
			ID INT,
			FromStatus UNIQUEIDENTIFIER,
			ToStatus UNIQUEIDENTIFIER,
			IsFinal BIT,
			IsEnabled BIT,
			SortOrder INT,
			Description NVARCHAR(255)
		);


		--Start by creating the workflow
		INSERT	SCore.Workflow
			 (
				
				RowStatus,
				Guid,
				OrganisationalUnitId,
				EntityTypeID,
				EntityHoBTID,
				Name,
				Description,
				Enabled
			 )
		VALUES
			 (
				 1,
				 @Guid,
				 @OrganisationalUnitId,
				 @EntityTypeID,
				 @EntityHoBTID,
				 @Name,
				 @Description,
				 @Enabled
			 );

		

		
		-- Now, we add the default transitions that should be automatically added.
		INSERT INTO #WorkflowTransitions
		SELECT 
			wft.ID AS ID,
			wfsFrom.Guid AS FromStatus,
			wfsTo.Guid AS ToStatus,
			wft.IsFinal AS IsFinal,
			wft.Enabled AS IsEnabled,
			wft.SortOrder,
			wft.Description
		FROM SCore.Workflow AS wf
		JOIN SCore.EntityTypes AS et ON wf.EntityTypeID = et.ID
		JOIN SCore.WorkflowTransition AS wft ON wft.WorkflowID = wf.ID
		JOIN SCore.WorkflowStatus AS wfsFrom ON wft.FromStatusID = wfsFrom.ID
		JOIN SCore.WorkflowStatus AS wfsTo ON wft.ToStatusID = wfsTo.ID
		WHERE 
			et.Guid = @EntityTypeGuid
			AND wft.RowStatus NOT IN (0,254)
			AND wf.RowStatus NOT IN (0,254)
			AND wf.OrganisationalUnitId = -1;



		DECLARE 
		@ID INT,
        @FromStatus UNIQUEIDENTIFIER,
        @ToStatus UNIQUEIDENTIFIER,
        @IsFinal BIT,
        @IsEnabled BIT,
        @SortOrder INT,
        @WorkflowTransitionDescription NVARCHAR(400)

	    -- Loop until table is empty
		WHILE EXISTS (SELECT 1 FROM #WorkflowTransitions)
		BEGIN
			-- Grab the "top" row (any one row)
			SELECT TOP 1
				@ID = ID,
				@FromStatus = FromStatus,
				@ToStatus = ToStatus,
				@IsFinal = IsFinal,
				@IsEnabled = IsEnabled,
				@SortOrder = SortOrder,
				@WorkflowTransitionDescription = Description
			FROM #WorkflowTransitions
			ORDER BY ID;

			DECLARE @WorkflowTransitionGuid UNIQUEIDENTIFIER = NEWID();

			--Add the default workflow transitions
			EXEC [SCore].[WorkflowTransitionUpsert]
			@Guid = @WorkflowTransitionGuid,
			@WorkflowGuid = @Guid,
			@FromStatusGuid = @FromStatus,
			@ToStatusGuid = @ToStatus,
			@IsFinal = @IsFinal,
			@SortOrder = @SortOrder,
			@Enabled = @IsEnabled,
			@Description = @WorkflowTransitionDescription;



			-- Delete the row we just processed
			DELETE TOP (1)
			FROM #WorkflowTransitions
			WHERE ID = @ID
			
		END;
		


	END;
	ELSE
	BEGIN
		UPDATE	SCore.Workflow
		SET		
			RowStatus				= 1,
			Guid					= @Guid,
			OrganisationalUnitId	= @OrganisationalUnitId,
			EntityTypeID			= @EntityTypeID,
			EntityHoBTID			= @EntityHoBTID,
			Name					= @Name,
			Description				= @Description,
			Enabled					= @Enabled
		WHERE	(Guid = @Guid);
	END;


END;
GO