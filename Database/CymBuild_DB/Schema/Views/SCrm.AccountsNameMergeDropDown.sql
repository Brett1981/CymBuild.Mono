SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SCrm].[AccountsNameMergeDropDown]
AS
    SELECT root_hobt.Id,
		   root_hobt.Guid,
           CASE WHEN root_hobt.Code <> '' THEN root_hobt.Name + ' - ' + root_hobt.Code
                ELSE root_hobt.Name
           END AS Name
    FROM SCrm.Accounts root_hobt
GO