SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT (N'Create function [SFin].[tvf_InvoiceSchedulePercentageConfiguration]')
GO

PRINT (N'Create function [SFin].[tvf_InvoiceSchedulePercentageConfiguration]')
GO

CREATE FUNCTION [SFin].[tvf_InvoiceSchedulePercentageConfiguration] 
(
    @UserId INT,
    @ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS
RETURN 
SELECT 
    root_hobt.ID,
    root_hobt.RowStatus,
    root_hobt.Guid,
    root_hobt.PeriodNumber,
    root_hobt.Percentage,
    root_hobt.OnDayOfMonth,
    root_hobt.Description,

    rs.Guid AS RibaStageID,
    rs.Description AS RibaStage
FROM [SFin].[InvoiceSchedulePercentageConfiguration] AS root_hobt
JOIN [SFin].[InvoiceSchedules] AS invsch 
    ON invsch.ID = root_hobt.InvoiceScheduleId
   AND invsch.RowStatus NOT IN (0,254)
LEFT JOIN [SJob].[RibaStages] AS rs
    ON rs.ID = root_hobt.RibaStageID
   AND rs.RowStatus NOT IN (0,254)
WHERE root_hobt.RowStatus NOT IN (0,254)
  AND invsch.Guid = @ParentGuid
  AND EXISTS
  (
      SELECT 1
      FROM SCore.ObjectSecurityForUser_CanRead(root_hobt.Guid, @UserId) AS oscr
  );
GO