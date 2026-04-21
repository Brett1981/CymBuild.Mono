USE [CymBuild_Dev]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [SFin].[TransactionExportsToSageUpsert]
(
      @InclusiveToDate         DATE
    , @OrganisationalUnitGuid  UNIQUEIDENTIFIER
    , @Guid                    UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
          @ExportData             NVARCHAR(MAX)
        , @ExportId               BIGINT
        , @OrganisationalUnitId   INT
        , @IsInsert               BIT;

    SELECT
        @OrganisationalUnitId = ou.ID
    FROM SCore.OrganisationalUnits AS ou
    WHERE ou.Guid = @OrganisationalUnitGuid
      AND ou.RowStatus NOT IN (0, 254);

    IF @OrganisationalUnitId IS NULL
    BEGIN
        ;THROW 60100, N'Organisational unit could not be resolved for TransactionExportsToSageUpsert.', 1;
    END;

    EXEC SCore.UpsertDataObject
          @Guid = @Guid
        , @SchemeName = N'SFin'
        , @ObjectName = N'SageExports'
        , @IncludeDefaultSecurity = 1
        , @IsInsert = @IsInsert OUT;

    BEGIN TRAN;

    IF @IsInsert = 1
    BEGIN
        INSERT INTO SFin.SageExports
        (
              RowStatus
            , Guid
            , InclusiveToDate
            , ExportData
            , OrganisationalUnitId
        )
        VALUES
        (
              1
            , @Guid
            , @InclusiveToDate
            , N''
            , @OrganisationalUnitId
        );

        SELECT
            @ExportId = SCOPE_IDENTITY();

        INSERT INTO SFin.SageExportTransactions
        (
              RowStatus
            , Guid
            , SageExportID
            , TransactionID
        )
        SELECT
              1
            , NEWID()
            , @ExportId
            , t.ID
        FROM SFin.Transactions AS t
        INNER JOIN SFin.TransactionTypes AS tt
            ON tt.ID = t.TransactionTypeID
           AND tt.RowStatus NOT IN (0, 254)
        WHERE t.[Date] <= @InclusiveToDate
          AND t.RowStatus NOT IN (0, 254)
          AND tt.Name = N'Invoice'
          AND t.LegacyId IS NULL
          AND t.OrganisationalUnitId = @OrganisationalUnitId
          AND NOT EXISTS
          (
              SELECT 1
              FROM SFin.SageExportTransactions AS e
              WHERE e.TransactionID = t.ID
                AND e.RowStatus NOT IN (0, 254)
          );
    END
    ELSE
    BEGIN
        SELECT
            @ExportId = se.ID
        FROM SFin.SageExports AS se
        WHERE se.Guid = @Guid
          AND se.RowStatus NOT IN (0, 254);
    END;

    IF @ExportId IS NULL
    BEGIN
        ROLLBACK TRAN;
        THROW 60101, N'Sage export record could not be resolved for TransactionExportsToSageUpsert.', 1;
    END;

    ;WITH ExportLines AS
    (
        SELECT
              t.Number AS TransactionNumber
            , LTRIM(RTRIM(ISNULL(a.Code, N''))) AS AccountCode
            , CONVERT(NVARCHAR(10), t.[Date], 103) AS TransactionDateText
            , CAST(ISNULL(vc.SageVatNo, N'') AS NVARCHAR(20)) AS SageVatNo
            , CAST(ISNULL(td.Qty, 1) AS DECIMAL(18, 4)) AS Qty
            , td.Net
            , td.[Description]
            , ISNULL(t.PurchaseOrderNumber, N'') AS PurchaseOrderNumber
            , CASE
                  WHEN ou.CostCentreCode IS NULL OR ou.CostCentreCode = N'' THEN N''
                  WHEN CHARINDEX(N'-', ou.CostCentreCode) > 0
                      THEN LEFT(ou.CostCentreCode, CHARINDEX(N'-', ou.CostCentreCode) - 1)
                  ELSE ou.CostCentreCode
              END AS CostCentreCode
            , CASE
                  WHEN ou.CostCentreCode IS NULL OR ou.CostCentreCode = N'' THEN N''
                  WHEN CHARINDEX(N'-', ou.CostCentreCode) > 0
                      THEN SUBSTRING(
                              ou.CostCentreCode,
                              CHARINDEX(N'-', ou.CostCentreCode) + 1,
                              LEN(ou.CostCentreCode))
                  ELSE N''
              END AS DepartmentCode
        FROM SFin.SageExportTransactions AS e
        INNER JOIN SFin.Transactions AS t
            ON t.ID = e.TransactionID
           AND t.RowStatus NOT IN (0, 254)
        INNER JOIN SFin.TransactionDetails AS td
            ON td.TransactionID = t.ID
           AND td.RowStatus NOT IN (0, 254)
        INNER JOIN SCore.OrganisationalUnits AS ou
            ON ou.ID = t.OrganisationalUnitId
           AND ou.RowStatus NOT IN (0, 254)
        INNER JOIN SCrm.Accounts AS a
            ON a.ID = t.AccountID
           AND a.RowStatus NOT IN (0, 254)
        LEFT JOIN SFin.VatCodes AS vc
            ON vc.ID = td.VatCodeID
           AND vc.RowStatus NOT IN (0, 254)
        WHERE e.SageExportID = @ExportId
          AND e.RowStatus NOT IN (0, 254)
    )
    SELECT
        @ExportData =
            STUFF
            (
                (
                    SELECT
                        CHAR(13)
                        + N'"' + el.AccountCode + N'"'
                        + N',' + REPLACE(el.TransactionDateText, N' ', N'-')
                        + N',' + CONVERT(NVARCHAR(MAX), el.TransactionNumber)
                        + N',' + el.SageVatNo
                        + N',INV,'
                        + CONVERT(NVARCHAR(MAX), el.Qty)
                        + N',' + CONVERT(NVARCHAR(MAX), el.Net)
                        + N',31010,'
                        + el.CostCentreCode
                        + N','
                        + el.DepartmentCode
                        + N',"'
                        + REPLACE(ISNULL(el.[Description], N''), N'"', N'''')
                        + N'","'
                        + REPLACE(el.PurchaseOrderNumber, N'"', N'''')
                        + N'"'
                    FROM ExportLines AS el
                    ORDER BY el.TransactionNumber
                    FOR XML PATH (''), TYPE
                ).value('text()[1]', 'nvarchar(max)')
                , 1
                , LEN(CHAR(13))
                , N''
            );

    UPDATE SFin.SageExports
    SET ExportData = ISNULL(@ExportData, N'')
    WHERE ID = @ExportId
      AND RowStatus NOT IN (0, 254);

    COMMIT TRAN;
END;
GO