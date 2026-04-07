SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_JobMilestonesValidate]
  (
    @MilestoneTypeGuid UNIQUEIDENTIFIER,
    @Guid              UNIQUEIDENTIFIER
  )
RETURNS @ValidationResult TABLE
  (
    ID                  INT              IDENTITY (1, 1) NOT NULL,
    TargetGuid          UNIQUEIDENTIFIER NOT NULL DEFAULT ('00000000-0000-0000-0000-000000000000'),
    TargetType          CHAR(1)          NOT NULL DEFAULT (''),
    IsReadOnly          BIT              NOT NULL DEFAULT ((0)),
    IsHidden            BIT              NOT NULL DEFAULT ((0)),
    IsInvalid           BIT              NOT NULL DEFAULT ((0)),
    [IsInformationOnly] [BIT]            NOT NULL DEFAULT ((0)),
    Message             NVARCHAR(2000)   NOT NULL DEFAULT ('')
  )
AS
  BEGIN
    DECLARE @HasQuotedHours     BIT,
            @HasDescription     BIT,
            @HasReference       BIT,
            @IsCompulsory       BIT,
            @IncludeStart       BIT,
            @IncludeDueDate     BIT,
            @IsReviewRequired   BIT,
			@HasExternalSubmission	BIT,
            @IncludeSchedule    BIT;

    -- Get the details of the Milestone Type
    SELECT
            @HasQuotedHours   = mt.HasQuotedHours,
            @HasDescription   = mt.HasDescription,
            @IsCompulsory     = mt.IsCompulsory,
            @IncludeStart     = mt.IncludeStart,
            @IncludeSchedule  = mt.IncludeSchedule,
            @IncludeDueDate   = mt.IncludeDueDate,
            @IsReviewRequired = mt.IsReviewRequired,
			@HasExternalSubmission = mt.HasExternalSubmission
    FROM
            SJob.MilestoneTypes mt
    WHERE
            (Guid = @MilestoneTypeGuid)


	IF(EXISTS(SELECT 1 FROM SJob.Milestones WHERE Guid = @Guid AND CompletedDateTimeUTC IS NOT NULL))
	BEGIN
	INSERT @ValidationResult
              (
                TargetGuid,
                TargetType,
                IsReadOnly,
                IsHidden,
                IsInvalid,
                [Message]
              )
        SELECT
                
                  epfvv.Guid,
                  N'P',
                  1,
                  0,
                  0,
                  N''
             FROM	
				Score.EntityPropertiesForValidationV AS epfvv
		WHERE	(epfvv.[Schema] = N'SJob')
			AND	(epfvv.Hobt = N'Milestones')
			
	END;

    IF (@HasQuotedHours = 0)
      BEGIN
        INSERT @ValidationResult
              (
                TargetGuid,
                TargetType,
                IsReadOnly,
                IsHidden,
                IsInvalid,
                [Message]
              )
        SELECT
                
                  epfvv.Guid,
                  N'P',
                  0,
                  1,
                  0,
                  N''
             FROM	
				Score.EntityPropertiesForValidationV AS epfvv
		WHERE	(epfvv.[Schema] = N'SJob')
			AND	(epfvv.Hobt = N'Milestones')
			AND	(epfvv.Name IN (N'EstimatedRemainingHours', N'QuotedHours'))
      END

	  IF (@HasExternalSubmission = 0)
      BEGIN
        INSERT @ValidationResult
              (
                TargetGuid,
                TargetType,
                IsReadOnly,
                IsHidden,
                IsInvalid,
                [Message]
              )
        SELECT
                  epfvv.Guid,
                  N'P',
                  0,
                  1,
                  0,
                  N''
        FROM	
				Score.EntityPropertiesForValidationV AS epfvv
		WHERE	(epfvv.[Schema] = N'SJob')
			AND	(epfvv.Hobt = N'Milestones')
			AND	(epfvv.Name IN (N'SubmissionExpiryDate', N'SubmittedDateTimeUTC', N'SubmittedBy', N'ExternalSubmission'))
      END

    IF (@HasDescription = 0)
      BEGIN
        INSERT @ValidationResult
              (
                TargetGuid,
                TargetType,
                IsReadOnly,
                IsHidden,
                IsInvalid,
                [Message]
              )
        SELECT
                  epfvv.Guid,
                  N'P',
                  0,
                  1,
                  0,
                  N''
         FROM	
				Score.EntityPropertiesForValidationV AS epfvv
		WHERE	(epfvv.[Schema] = N'SJob')
			AND	(epfvv.Hobt = N'Milestones')
			AND	(epfvv.Name = N'Description')
      END

    IF (@HasReference = 0)
      BEGIN
        INSERT @ValidationResult
              (
                TargetGuid,
                TargetType,
                IsReadOnly,
                IsHidden,
                IsInvalid,
                [Message]
              )
        SELECT
                  epfvv.Guid,
                  N'P',
                  0,
                  1,
                  0,
                  N''
        FROM	
				Score.EntityPropertiesForValidationV AS epfvv
		WHERE	(epfvv.[Schema] = N'SJob')
			AND	(epfvv.Hobt = N'Milestones')
			AND	(epfvv.Name = N'Reference')
      END

    IF (@IsCompulsory = 1)
      BEGIN
        INSERT @ValidationResult
              (
                TargetGuid,
                TargetType,
                IsReadOnly,
                IsHidden,
                IsInvalid,
                [Message]
              )
        SELECT
                  epfvv.Guid,
                  N'P',
                  0,
                  1,
                  0,
                  N''
        FROM	
				Score.EntityPropertiesForValidationV AS epfvv
		WHERE	(epfvv.[Schema] = N'SJob')
			AND	(epfvv.Hobt = N'Milestones')
			AND	(epfvv.Name = N'IsNotApplicable')
      END

    IF (@IncludeStart = 0)
      BEGIN
        INSERT @ValidationResult
              (
                TargetGuid,
                TargetType,
                IsReadOnly,
                IsHidden,
                IsInvalid,
                [Message]
              )
        SELECT
                  epfvv.Guid,
                  N'P',
                  0,
                  1,
                  0,
                  N''
        FROM	
				Score.EntityPropertiesForValidationV AS epfvv
		WHERE	(epfvv.[Schema] = N'SJob')
			AND	(epfvv.Hobt = N'Milestones')
			AND	(epfvv.Name IN (N'StartDateTimeUTC', N'StartedByUserId'))
      END

    IF (@IncludeSchedule = 0)
      BEGIN
		INSERT @ValidationResult
              (
                TargetGuid,
                TargetType,
                IsReadOnly,
                IsHidden,
                IsInvalid,
                [Message]
              )
        SELECT
                  epfvv.Guid,
                  N'P',
                  0,
                  1,
                  0,
                  N''
        FROM	
				Score.EntityPropertiesForValidationV AS epfvv
		WHERE	(epfvv.[Schema] = N'SJob')
			AND	(epfvv.Hobt = N'Milestones')
			AND	(epfvv.Name = N'ScheduledDateTimeUTC')
      END

    IF (@IncludeDueDate = 0)
      BEGIN
		INSERT @ValidationResult
              (
                TargetGuid,
                TargetType,
                IsReadOnly,
                IsHidden,
                IsInvalid,
                [Message]
              )
        SELECT
                  epfvv.Guid,
                  N'P',
                  0,
                  1,
                  0,
                  N''
        FROM	
				Score.EntityPropertiesForValidationV AS epfvv
		WHERE	(epfvv.[Schema] = N'SJob')
			AND	(epfvv.Hobt = N'Milestones')
			AND	(epfvv.Name = N'DueDateTimeUTC')
      END

    IF (@IsReviewRequired = 0)
      BEGIN
		INSERT @ValidationResult
              (
                TargetGuid,
                TargetType,
                IsReadOnly,
                IsHidden,
                IsInvalid,
                [Message]
              )
        SELECT
                  epfvv.Guid,
                  N'P',
                  0,
                  1,
                  0,
                  N''
        FROM	
				Score.EntityPropertiesForValidationV AS epfvv
		WHERE	(epfvv.[Schema] = N'SJob')
			AND	(epfvv.Hobt = N'Milestones')
			AND	(epfvv.Name IN (N'ReviewedDateTimeUTC', N'ReviewerUserId'))
      END

    RETURN;
  END;

GO