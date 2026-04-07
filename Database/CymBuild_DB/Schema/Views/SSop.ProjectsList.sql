SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SSop].[ProjectsList]
	   --WITH SCHEMABINDING
AS
SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.Guid,
		CASE 
			WHEN (root_hobt.ExternalReference = N'' AND root_hobt.ProjectDescription = N'') THEN CONVERT(NVARCHAR(MAX), root_hobt.Number)
			WHEN (root_Hobt.ExternalReference = N'') THEN CONVERT(NVARCHAR(MAX), root_hobt.Number) + N' - ' + root_hobt.ProjectDescription
			ELSE root_hobt.ExternalReference + N' - ' + root_hobt.ProjectDescription
		END ListLabel
FROM	SSop.Projects root_hobt
GO