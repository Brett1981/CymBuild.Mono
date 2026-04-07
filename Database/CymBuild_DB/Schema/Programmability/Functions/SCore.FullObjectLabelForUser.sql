SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE FUNCTION [SCore].[FullObjectLabelForUser]
(
    @LanguageLabelID int,
    @UserId int
)
RETURNS TABLE
                --WITH SCHEMABINDING
AS 
RETURN 
SELECT      llt.Text AS Label,
            llt.TextPlural AS LabelPlural,
			llt.HelpText AS HelpText
FROM        [SCore].[LanguageLabels] ll
JOIN        [SCore].[LanguageLabelTranslations] llt on (llt.LanguageLabelID = ll.ID)
JOIN        [SCore].[UserPreferences] up ON (up.SystemLanguageId = llt.LanguageID)
WHERE       (ll.Id = @LanguageLabelID)
        AND (up.ID = @UserId)
		AND	(ll.[RowStatus] NOT IN (0, 254))
		AND	(llt.[RowStatus] NOT IN (0, 254))

GO