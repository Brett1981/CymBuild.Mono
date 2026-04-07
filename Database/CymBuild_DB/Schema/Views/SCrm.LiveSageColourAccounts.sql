SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SCrm].[LiveSageColourAccounts]
--WITH SCHEMABINDING
AS 
SELECT
    root_hobt.Guid,
    root_hobt.RowStatus,
    root_hobt.Name,
    root_hobt.ConcatenatedNameCode,
    -- New computed column for colour logic
    CASE 
        WHEN root_hobt.Name = root_hobt.ConcatenatedNameCode 
            THEN '#000000' -- Black
            ELSE '#FF0000' -- Red
    END AS ColourHex
FROM
    SCrm.Accounts root_hobt
JOIN
    SCrm.AccountStatus stat ON (stat.ID = root_hobt.AccountStatusID)
WHERE
    (stat.IsLive = 1);
GO