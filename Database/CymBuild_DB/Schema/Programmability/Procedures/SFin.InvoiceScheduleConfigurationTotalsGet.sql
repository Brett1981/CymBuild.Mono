SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[InvoiceScheduleConfigurationTotalsGet]')
GO

CREATE PROCEDURE [SFin].[InvoiceScheduleConfigurationTotalsGet]
(
      @UserId     INT
    , @ParentGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
          @InvoiceScheduleId INT = NULL
        , @ScheduleAmount DECIMAL(18, 2) = 0.00;

    SELECT TOP (1)
          @InvoiceScheduleId = invsch.ID
        , @ScheduleAmount = ISNULL(invsch.Amount, 0.00)
    FROM SFin.InvoiceSchedules AS invsch
    WHERE invsch.RowStatus NOT IN (0, 254)
      AND invsch.Guid = @ParentGuid
    ORDER BY invsch.ID;

    IF @InvoiceScheduleId IS NULL
    BEGIN
        SELECT
              CAST(0.00 AS DECIMAL(18, 2)) AS MonthlyTotalAmount
            , CAST(0.00 AS DECIMAL(18, 2)) AS PercentageTotalPercentage
            , CAST(0.00 AS DECIMAL(18, 2)) AS PercentageTotalAmount
            , CAST(0.00 AS DECIMAL(18, 2)) AS ScheduleAmount;
        RETURN;
    END;

    ;WITH MonthlyTotals AS
    (
        SELECT
            CAST(ISNULL(SUM(root_hobt.Amount), 0.00) AS DECIMAL(18, 2)) AS TotalAmount
        FROM SFin.InvoiceScheduleMonthConfiguration AS root_hobt
        WHERE root_hobt.RowStatus NOT IN (0, 254)
          AND root_hobt.InvoiceScheduleId = @InvoiceScheduleId
          AND EXISTS
          (
              SELECT 1
              FROM SCore.ObjectSecurityForUser_CanRead(root_hobt.Guid, @UserId) AS oscr
          )
    ),
    PercentageTotals AS
    (
        SELECT
            CAST(ISNULL(SUM(root_hobt.Percentage), 0.00) AS DECIMAL(18, 2)) AS TotalPercentage
        FROM SFin.InvoiceSchedulePercentageConfiguration AS root_hobt
        WHERE root_hobt.RowStatus NOT IN (0, 254)
          AND root_hobt.InvoiceScheduleId = @InvoiceScheduleId
          AND EXISTS
          (
              SELECT 1
              FROM SCore.ObjectSecurityForUser_CanRead(root_hobt.Guid, @UserId) AS oscr
          )
    )
    SELECT
          mt.TotalAmount AS MonthlyTotalAmount
        , pt.TotalPercentage AS PercentageTotalPercentage
        , CAST((@ScheduleAmount * pt.TotalPercentage) / 100.00 AS DECIMAL(18, 2)) AS PercentageTotalAmount
        , @ScheduleAmount AS ScheduleAmount
    FROM MonthlyTotals AS mt
    CROSS JOIN PercentageTotals AS pt;
END
GO