SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[VatCode_Upsert]')
GO

CREATE PROCEDURE [SFin].[VatCode_Upsert]
(
    @Guid              UNIQUEIDENTIFIER,
    @SageVatNo         NVARCHAR(20),
    @Description       NVARCHAR(200),
    @VatPercentage     DECIMAL(9,4),
    @EffectiveFromDate DATE = NULL,
    @Active            BIT = 1
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Guid IS NULL OR @Guid = '00000000-0000-0000-0000-000000000000'
    BEGIN
        ;THROW 70000, N'A valid Guid is required for SFin.VatCodes.', 1;
    END;

    IF NULLIF(LTRIM(RTRIM(@SageVatNo)), N'') IS NULL
    BEGIN
        ;THROW 70001, N'Sage Vat Code is required.', 1;
    END;

    IF @EffectiveFromDate IS NULL
    BEGIN
        SET @EffectiveFromDate = CONVERT(DATE, GETDATE());
    END;

    DECLARE @EntityTypeId INT;

    SELECT TOP (1)
           @EntityTypeId = eh.EntityTypeID
    FROM SCore.EntityHobts eh
    WHERE eh.RowStatus NOT IN (0, 254)
      AND eh.SchemaName = N'SFin'
      AND eh.ObjectName = N'VatCodes';

    IF @EntityTypeId IS NULL
    BEGIN
        ;THROW 70002, N'EntityTypeId for SFin.VatCodes could not be resolved from SCore.EntityHobts.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM SCore.DataObjects dox
        WHERE dox.Guid = @Guid
    )
    BEGIN
        INSERT INTO SCore.DataObjects
        (
            Guid,
            RowStatus,
            EntityTypeId
        )
        VALUES
        (
            @Guid,
            1,
            @EntityTypeId
        );
    END;

    IF EXISTS
    (
        SELECT 1
        FROM SFin.VatCodes vc
        WHERE vc.Guid = @Guid
          AND vc.RowStatus NOT IN (0, 254)
    )
    BEGIN
        UPDATE vc
        SET
            vc.SageVatNo         = @SageVatNo,
            vc.Description       = ISNULL(@Description, N''),
            vc.VatPercentage     = @VatPercentage,
            vc.EffectiveFromDate = @EffectiveFromDate,
            vc.Active            = @Active
        FROM SFin.VatCodes vc
        WHERE vc.Guid = @Guid
          AND vc.RowStatus NOT IN (0, 254);
    END
    ELSE
    BEGIN
        INSERT INTO SFin.VatCodes
        (
            RowStatus,
            Guid,
            SageVatNo,
            Description,
            VatPercentage,
            EffectiveFromDate,
            Active
        )
        VALUES
        (
            1,
            @Guid,
            @SageVatNo,
            ISNULL(@Description, N''),
            @VatPercentage,
            @EffectiveFromDate,
            @Active
        );
    END;
END
GO