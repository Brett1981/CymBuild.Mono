SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingRunStageSelection_List]')
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingRunStageSelection_List]')
GO

CREATE PROCEDURE [SMigration].[OnboardingRunStageSelection_List]
(
    @RunGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @RunGuid IS NULL
        THROW 62400, 'RunGuid is required to load OnBoarding row selections.', 1;

    SELECT
        EntityName = s.EntityName,
        RowGuid = CONVERT(NVARCHAR(36), s.RowGuid),
        SelectedByUserId = s.SelectedByUserId,
        SelectedOnUtc = CONVERT(NVARCHAR(40), s.SelectedOnUtc, 126)
    FROM SMigration.Onboarding_RunStageSelections AS s
    WHERE s.RunGuid = @RunGuid
      AND s.RowStatus NOT IN (0,254)
    ORDER BY
        s.EntityName,
        s.RowGuid;
END;
GO