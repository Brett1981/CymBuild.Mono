SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_LanguageLabelTranslations] 
(
    @UserId INT,
    @ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
               --WITH SCHEMABINDING
AS
RETURN 
SELECT  llt.ID,
        llt.RowStatus, 
        llt.RowVersion,
        llt.Guid,
		llt.Text,
        ll.Name AS LanguageLabel,
		l.Name AS Language
FROM    SCore.LanguageLabelTranslations llt
JOIN	SCore.LanguageLabels ll ON (ll.ID = llt.LanguageLabelID)
JOIN	SCore.Languages l ON (l.ID = llt.LanguageID)
OUTER APPLY SCore.ObjectSecurityForUser(llt.Guid, @UserId) os
WHERE   (llt.RowStatus  NOT IN (0, 254))
    AND (ll.Guid = @ParentGuid)
    AND (os.CanRead = 1)
GO