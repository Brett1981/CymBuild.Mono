/*
    CYB-475 - Sage purchase-order and standard VAT mapping correction

    Deployment-safe, idempotent reference-data correction.
    Apply only through the controlled CymBuild schema deployment process.

    Application mapping change:
      - Sage customerOrderNo is populated from SFin.Transactions.PurchaseOrderNumber.

    Reference-data correction:
      - Standard UK VAT (20%) is mapped to Sage tax-code identifier 10.
      - The previous value 22 resolves to 17.5% in the target Sage dataset.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE
    @StandardUkVatGuid UNIQUEIDENTIFIER = 'A5D9D80F-2F8A-4E65-83B6-1A10D267A201',
    @RequiredSageTaxCode NVARCHAR(20) = N'10',
    @Description NVARCHAR(200),
    @VatPercentage DECIMAL(9,4),
    @EffectiveFromDate DATE,
    @Active BIT,
    @CurrentSageTaxCode NVARCHAR(20);

IF OBJECT_ID(N'[SFin].[VatCode_Upsert]', N'P') IS NULL
BEGIN
    THROW 51000, 'CYB-475 deployment failed: [SFin].[VatCode_Upsert] is missing.', 1;
END;

SELECT
    @CurrentSageTaxCode = vc.SageVatNo,
    @Description = vc.Description,
    @VatPercentage = vc.VatPercentage,
    @EffectiveFromDate = vc.EffectiveFromDate,
    @Active = vc.Active
FROM SFin.VatCodes AS vc
WHERE vc.Guid = @StandardUkVatGuid
  AND vc.RowStatus <> 0
  AND vc.RowStatus <> 254;

IF @CurrentSageTaxCode IS NULL
BEGIN
    THROW 51000, 'CYB-475 deployment failed: the controlled Standard UK VAT row was not found or is inactive.', 1;
END;

IF @VatPercentage <> CONVERT(DECIMAL(9,4), 20.0000)
BEGIN
    THROW 51000, 'CYB-475 deployment failed: the controlled Standard UK VAT row is not configured at 20%.', 1;
END;

IF @CurrentSageTaxCode <> @RequiredSageTaxCode
BEGIN
    BEGIN TRANSACTION;

    EXEC SFin.VatCode_Upsert
        @Guid = @StandardUkVatGuid,
        @SageVatNo = @RequiredSageTaxCode,
        @Description = @Description,
        @VatPercentage = @VatPercentage,
        @EffectiveFromDate = @EffectiveFromDate,
        @Active = @Active;

    COMMIT TRANSACTION;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM SFin.VatCodes AS vc
    INNER JOIN SCore.DataObjects AS dataObject
        ON dataObject.Guid = vc.Guid
       AND dataObject.RowStatus <> 0
       AND dataObject.RowStatus <> 254
    WHERE vc.Guid = @StandardUkVatGuid
      AND vc.SageVatNo = @RequiredSageTaxCode
      AND vc.VatPercentage = CONVERT(DECIMAL(9,4), 20.0000)
      AND vc.Active = 1
      AND vc.RowStatus <> 0
      AND vc.RowStatus <> 254
)
BEGIN
    THROW 51000, 'CYB-475 deployment validation failed: Standard UK VAT is not mapped to Sage tax-code identifier 10.', 1;
END;
GO
