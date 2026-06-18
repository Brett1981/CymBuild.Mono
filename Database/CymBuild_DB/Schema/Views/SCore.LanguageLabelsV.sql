SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create view [SCore].[LanguageLabelsV]')
GO
CREATE VIEW	[SCore].[LanguageLabelsV]
                  --WITH SCHEMABINDING
AS
SELECT	ll.ID,
		ll.RowStatus,
		ll.RowVersion,
		ll.Guid,
		ll.Name
FROM	Score.[LanguageLabels] ll
WHERE	(ll.[RowStatus] NOT IN (0, 254))

GO