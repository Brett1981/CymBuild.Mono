SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[Activities_DataPills]
  (
	@SurveyorGuid				UNIQUEIDENTIFIER,
	@BillableHours				DECIMAL(19,2),
	@JobGuid					UNIQUEIDENTIFIER,
	@RibaStageGuid				UNIQUEIDENTIFIER,
	@IsAdditionalWork			BIT,
	@Guid						UNIQUEIDENTIFIER,
	@ActivityTypeGuid			UNIQUEIDENTIFIER
	
  )
RETURNS @DataPills TABLE
  (
    [ID]        [INT]        IDENTITY (1, 1) NOT NULL,
    [Label]     NVARCHAR(50) NOT NULL,
    [Class]     NVARCHAR(50) NOT NULL,
    [SortOrder] INT          NOT NULL
  )
AS
  BEGIN
    DECLARE @JobID INT,
			@JobUsesTimeSheets BIT,
			@StageInvoiced DECIMAL(19,2) = 0,
			@StageQuoted DECIMAL (19,2) = 0,
			@BillableValue DECIMAL(19,2) = 0,
			@BillableRate DECIMAL(19,2) = 0

	SELECT
			@JobUsesTimeSheets = jt.UseTimeSheets
	FROM
			SJob.JobTypes jt
	WHERE
			(EXISTS
				(
					SELECT
							1
					FROM
							SJob.Jobs j
					WHERE
							(j.JobTypeID = jt.ID)
							AND (j.Guid = @JobGuid)
				)
			)

	
	-- Data pill for billable/non-billable activities.
	IF (EXISTS
			(
				SELECT 1
				FROM SJob.ActivityTypes ActT
				WHERE ActT.IsBillable = 1 AND ActT.Guid = @ActivityTypeGuid
			)	
		)
	BEGIN
		INSERT @DataPills
			  (
				Label,
				Class,
				SortOrder
			  )
		VALUES
			  (
				N'Billable Activity',	-- Label - nvarchar(50)
				N'bg-info',	-- Class - nvarchar(50)
				1		-- SortOrder - int
			  )
	END
	ELSE
	BEGIN
		INSERT @DataPills
			  (
				Label,
				Class,
				SortOrder
			  )
		VALUES
			  (
				N'Non-Billable Activity',	-- Label - nvarchar(50)
				N'bg-info',	-- Class - nvarchar(50)
				2		-- SortOrder - int
			  )
	END

	




	IF (@JobUsesTimeSheets = 1)
	BEGIN
		IF (@IsAdditionalWork = 0)
		BEGIN
			SELECT
					@StageInvoiced = jfd.Invoiced,
					@StageQuoted   = jfd.Agreed
			FROM
					SJob.Job_FeeDrawdown jfd
			JOIN
					SJob.Jobs j ON (j.ID = jfd.JobID)
			JOIN
					SJob.RibaStages rs ON (rs.ID = jfd.StageId)
			WHERE
					(j.Guid = @JobGuid)
					AND (rs.Guid = @RibaStageGuid)
		END
		ELSE
		BEGIN
			SELECT
					@StageInvoiced = ISNULL(jfd.Invoiced, 0),
					@StageQuoted   = ISNULL(jfd.Agreed, 0)
			FROM
					SJob.Jobs j
			LEFT JOIN
					SJob.Job_FeeDrawdown jfd ON (j.ID = jfd.JobID)
			WHERE
					(j.Guid = @JobGuid)
					AND (ISNULL(jfd.StageId, -1) = -1)
		END

		SELECT
				@BillableValue = BillableRate * @BillableHours,
				@BillableRate  = BillableRate
		FROM
				SCore.Identities
		WHERE
				(Guid = @SurveyorGuid)

		IF (@BillableRate = 0
			AND
			@BillableHours <> 0)
		BEGIN
			INSERT @DataPills
					(
						Label,
						Class,
						SortOrder
					)
			VALUES
					(
						N'The assignee has no billable rate; work is FoC',	-- Label - nvarchar(50)
						N'bg-info',	-- Class - nvarchar(50)
						1		-- SortOrder - int
					)
		END

		IF ((@StageInvoiced + @BillableValue) > @StageQuoted)
		BEGIN
			INSERT @DataPills
					(
						Label,
						Class,
						SortOrder
					)
			VALUES
					(
						N'The quoted value for this stage has been exceeded',	-- Label - nvarchar(50)
						N'bg-danger',	-- Class - nvarchar(50)
						1		-- SortOrder - int
					)
		END

		IF (CASE
					WHEN @StageQuoted > 0 THEN
						(@StageInvoiced / @StageQuoted)
					ELSE
					0
			END > 0.9)
		BEGIN
			INSERT @DataPills
					(
						Label,
						Class,
						SortOrder
					)
			VALUES
					(
						N'Over 90% of the quoted value used in this stage',	-- Label - nvarchar(50)
						N'bg-warning',	-- Class - nvarchar(50)
						1		-- SortOrder - int
					)
		END
	END;

	RETURN
END
GO