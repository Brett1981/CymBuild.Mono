SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SJob].[MergeAssets]')
GO
PRINT (N'Create procedure [SJob].[MergeAssets]')
GO

CREATE PROCEDURE [SJob].[MergeAssets]
(
    @FromAssetGuid UNIQUEIDENTIFIER,
    @ToAssetGuid   UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @FromAssetID INT,
        @ToAssetID INT,
        @FromParentAssetID INT,
        @AppLockResult INT,
        @AppLockResource NVARCHAR(255);

    DECLARE @RetiredPossibleDuplicateDataObjects TABLE
    (
        Guid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY
    );

    IF @FromAssetGuid IS NULL
    BEGIN
        ;THROW 603581, N'SJob.MergeAssets failed: From asset Guid is required.', 1;
    END;

    IF @ToAssetGuid IS NULL
    BEGIN
        ;THROW 603582, N'SJob.MergeAssets failed: To asset Guid is required.', 1;
    END;

    IF @FromAssetGuid = @ToAssetGuid
    BEGIN
        ;THROW 603583, N'SJob.MergeAssets failed: source and target assets cannot be the same record.', 1;
    END;

    BEGIN TRY
        BEGIN TRAN;

        SET @AppLockResource = CONCAT
        (
            N'SJob.MergeAssets:',
            CONVERT(NVARCHAR(36), @FromAssetGuid),
            N':',
            CONVERT(NVARCHAR(36), @ToAssetGuid)
        );

        EXEC @AppLockResult = sys.sp_getapplock
             @Resource = @AppLockResource,
             @LockMode = N'Exclusive',
             @LockOwner = N'Transaction',
             @LockTimeout = 10000;

        IF ISNULL(@AppLockResult, -999) < 0
        BEGIN
            ;THROW 603584, N'SJob.MergeAssets failed: could not acquire merge lock.', 1;
        END;

        ---------------------------------------------------------------------
        -- Source may already be RowStatus 254 due a previous partial merge.
        -- We still allow it so CYB-358-style broken merges can be repaired.
        ---------------------------------------------------------------------
        SELECT
            @FromAssetID = a.ID,
            @FromParentAssetID = a.ParentAssetID
        FROM SJob.Assets AS a WITH (UPDLOCK, HOLDLOCK)
        WHERE a.Guid = @FromAssetGuid
          AND a.RowStatus <> 0;

        SELECT
            @ToAssetID = a.ID
        FROM SJob.Assets AS a WITH (UPDLOCK, HOLDLOCK)
        WHERE a.Guid = @ToAssetGuid
          AND a.RowStatus NOT IN (0,254);

        IF @FromAssetID IS NULL
        BEGIN
            ;THROW 603585, N'SJob.MergeAssets failed: source asset could not be resolved.', 1;
        END;

        IF @ToAssetID IS NULL
        BEGIN
            ;THROW 603586, N'SJob.MergeAssets failed: active target asset could not be resolved.', 1;
        END;

        IF @FromAssetID = @ToAssetID
        BEGIN
            ;THROW 603587, N'SJob.MergeAssets failed: source and target asset IDs resolved to the same record.', 1;
        END;

        ---------------------------------------------------------------------
        -- If the target is currently a child of the source, do not create a
        -- self-parent relationship when re-parenting source children.
        ---------------------------------------------------------------------
        UPDATE targetAsset
        SET targetAsset.ParentAssetID =
            CASE
                WHEN ISNULL(@FromParentAssetID, -1) = @ToAssetID THEN -1
                ELSE ISNULL(@FromParentAssetID, -1)
            END
        FROM SJob.Assets AS targetAsset
        WHERE targetAsset.ID = @ToAssetID
          AND targetAsset.ParentAssetID = @FromAssetID
          AND targetAsset.RowStatus NOT IN (0,254);

        ---------------------------------------------------------------------
        -- Move active child assets from source to target.
        ---------------------------------------------------------------------
        UPDATE childAsset
        SET childAsset.ParentAssetID = @ToAssetID
        FROM SJob.Assets AS childAsset
        WHERE childAsset.ParentAssetID = @FromAssetID
          AND childAsset.ID <> @ToAssetID
          AND childAsset.RowStatus NOT IN (0,254);

        ---------------------------------------------------------------------
        -- Move active Job references.
        ---------------------------------------------------------------------
        UPDATE j
        SET j.UprnID = @ToAssetID
        FROM SJob.Jobs AS j
        WHERE j.UprnID = @FromAssetID
          AND j.RowStatus NOT IN (0,254);

        ---------------------------------------------------------------------
        -- Move active Enquiry references.
        ---------------------------------------------------------------------
        UPDATE e
        SET e.PropertyId = @ToAssetID
        FROM SSop.Enquiries AS e
        WHERE e.PropertyId = @FromAssetID
          AND e.RowStatus NOT IN (0,254);

        ---------------------------------------------------------------------
        -- Move active Quote references.
        ---------------------------------------------------------------------
        UPDATE q
        SET q.UprnId = @ToAssetID
        FROM SSop.Quotes AS q
        WHERE q.UprnId = @FromAssetID
          AND q.RowStatus NOT IN (0,254);

        ---------------------------------------------------------------------
        -- CYB-358: this was missing from the original merge routine.
        ---------------------------------------------------------------------
        UPDATE po
        SET po.SiteId = @ToAssetID
        FROM SJob.PurchaseOrders AS po
        WHERE po.SiteId = @FromAssetID
          AND po.RowStatus NOT IN (0,254);

        ---------------------------------------------------------------------
        -- Retire active duplicate-candidate rows involving the source asset.
        -- The merge batch remains the audit record; possible duplicate rows are
        -- candidate/worklist records and should not keep the retired asset alive.
        ---------------------------------------------------------------------
        UPDATE apd
        SET apd.RowStatus = 254
        OUTPUT inserted.Guid
        INTO @RetiredPossibleDuplicateDataObjects
        (
            Guid
        )
        FROM SJob.AssetPossibleDuplicates AS apd
        WHERE apd.RowStatus NOT IN (0,254)
          AND
          (
                apd.SourceAssetID = @FromAssetID
             OR apd.TargetAssetID = @FromAssetID
          );

        UPDATE dataObject
        SET dataObject.RowStatus = 254
        FROM SCore.DataObjects AS dataObject
        JOIN @RetiredPossibleDuplicateDataObjects AS retired
            ON retired.Guid = dataObject.Guid
        WHERE dataObject.RowStatus NOT IN (0,254);

        ---------------------------------------------------------------------
        -- Align the source asset DataObject with the hidden HoBT row.
        ---------------------------------------------------------------------
        EXEC SCore.DeleteDataObject
             @Guid = @FromAssetGuid;

        UPDATE sourceAsset
        SET sourceAsset.RowStatus = 254
        FROM SJob.Assets AS sourceAsset
        WHERE sourceAsset.ID = @FromAssetID
          AND sourceAsset.Guid = @FromAssetGuid
          AND sourceAsset.RowStatus <> 254;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRAN;
        END;

        THROW;
    END CATCH;
END;
GO