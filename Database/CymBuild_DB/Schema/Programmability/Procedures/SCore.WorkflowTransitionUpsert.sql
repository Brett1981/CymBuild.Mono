SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[WorkflowTransitionUpsert]
(
	@Guid				UNIQUEIDENTIFIER,
	@WorkflowGuid		UNIQUEIDENTIFIER,
	@FromStatusGuid		UNIQUEIDENTIFIER,
	@ToStatusGuid		UNIQUEIDENTIFIER,
	@IsFinal			BIT,
	@Enabled			BIT,
	@SortOrder			INT,
	@Description		NVARCHAR(400)
)
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @FromStatusID INT;
	DECLARE @ToStatusID INT;
	DECLARE @WorkflowID INT;

	--Get "From Status"
	SELECT @FromStatusID = ID
	FROM SCore.WorkflowStatus
	WHERE Guid = @FromStatusGuid;

	--Get "To Status"
	SELECT @ToStatusID = ID
	FROM SCore.WorkflowStatus
	WHERE Guid = @ToStatusGuid;

	--Get "WorkflowID"
	SELECT @WorkflowID = ID
	FROM SCore.Workflow
	WHERE Guid = @WorkflowGuid


	DECLARE @IsInsert BIT = 0;
	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
								@SchemeName = N'SCore',			-- nvarchar(255)
								@ObjectName = N'WorkflowTransition', -- nvarchar(255)
								@IsInsert = @IsInsert OUTPUT,	-- bit
								@IncludeDefaultSecurity = 1;

	IF(@IsInsert = 1)
		BEGIN
			INSERT [SCore].[WorkflowTransition]
			(
				RowStatus,
				Guid,
				WorkflowID,
				FromStatusID,
				ToStatusID,
				IsFinal,
				Enabled,
				SortOrder,
				Description
			)
			VALUES
			(
				1,
				@Guid,
				@WorkflowID,
				@FromStatusID,
				@ToStatusID,
				@IsFinal,
				@Enabled,
				@SortOrder,
				@Description
			)

		END;
	ELSE
		BEGIN
			UPDATE [SCore].[WorkflowTransition]
			SET 
				WorkflowID		= @WorkflowID,
				FromStatusID	= @FromStatusID,
				ToStatusID		= @ToStatusID,
				IsFinal			= @IsFinal,
				Enabled			= @Enabled,
				SortOrder		= @SortOrder,
				Description		= @Description
			WHERE 
				(Guid = @Guid)

		END;
	END;
GO