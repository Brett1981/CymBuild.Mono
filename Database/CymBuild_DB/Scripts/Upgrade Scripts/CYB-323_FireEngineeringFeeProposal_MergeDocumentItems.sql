/*
CYB-323 - Fire Engineering Fee Proposal Document Auto-Population

Seeds the "Fire Engineering UK - Fee Proposal" MergeDocument
(c26adae4-cbd1-44a6-876a-1f51d7733ae6) with:

  * one "Signature" item (ConsultantSignature - the Quote Consultant's signature image,
    resolved by EF.Core.GetQuoteConsultantSignatoryInfo), and
  * the "Conditional Row" items for Table 1 (fee breakdown) and Table 2 (invoicing schedule),
    with their SCore.MergeDocumentItemGatingProducts rules.

Each Conditional Row item is a Word bookmark placed inside a static template table row. The
row is removed unless an active quote item matches one of its gating rules (product, and RIBA
stage when StageNumber is not NULL). A kept row can use «{Bookmark}_Fee» (sum of the matched
items' net) and «{Bookmark}_Deliverables» (their Details text) - see
ConditionalRowMergeEvaluator. Rows with no item here (PI insurance, Optional rows, mobilisation
fees, subtotals) are static template content.

Meetings rows follow their stage's main rows (same gating rules, no fee/deliverable fields).

Every quote item gets a row (BA Q1 option B, Jira 809245 / 809875): a gating rule with no
ProductCode is a catch-all (ProductId -1). It matches the quote lines that no product rule on
this document claims - at its RIBA stage, or, with no stage, whatever no stage catch-all takes.
"_EACH" rows are repeated once per matched line; "_SUB" (section subtotal, «{Bookmark}_Fee») and
"_GAP" (spacer) rows are kept with them. "_KEEP" rows are always kept; their rules only fill
the fee, which is blank when nothing matches (every Table 2 invoice schedule row is always
shown, quoted or not, and users delete the rows they don't need - Jira 810439, AC9). Renaming a bookmark here updates the
existing item by its Guid. Stages 0, 1, 5, 6, 7 and "other" (non-RIBA stages) are
whole sections that disappear when nothing is quoted there.

Requires, in order:
  1. Schema: SCore.MergeDocumentItemGatingProducts including RibaStageId.
  2. CYB-323_MergeDocumentItemType_ConditionalRow.sql.
  3. SProd.Products codes aligned to the "Product Allocations for Proposals" spec
     (CYB-323_ProductCode_Alignment.sql).

Idempotent: items have fixed Guids. Gating rows are matched on (item, product, stage), one per
active product with the rule's code, because LIVE has duplicate active codes (e.g. FIRE-DFS).
Re-running converges the rows to the state below. Products,
stages, item types and the merge document are resolved by natural key or Guid, never by
environment-specific ID. Fails (and changes nothing) if any of them cannot be resolved.
*/
SET QUOTED_IDENTIFIER, ANSI_NULLS ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @MergeDocumentGuid UNIQUEIDENTIFIER = 'c26adae4-cbd1-44a6-876a-1f51d7733ae6',
        @QuoteEntityTypeGuid UNIQUEIDENTIFIER = '1c4794c1-f956-4c32-b886-5500ac778a56',
        @ConditionalRowTypeGuid UNIQUEIDENTIFIER = '7892a85b-8312-43fc-b13c-c8e0f3f185c8',
        @SignatureTypeGuid UNIQUEIDENTIFIER;

DECLARE @Items TABLE
(
    ItemGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    BookmarkName NVARCHAR(50) NOT NULL,
    IsSignature BIT NOT NULL
);

INSERT @Items (ItemGuid, BookmarkName, IsSignature)
VALUES
    ('be59a602-5cd9-445d-af3c-5cc2eff26870', N'ConsultantSignature', 1),
    -- Table 1 - Design fire safety strategy fee breakdown
    ('448aab26-b61c-440f-9a0a-cee133c13f9b', N'FP_T1_QDR', 0),
    ('0ce522cc-dd38-4ed7-ac4f-b7829a4beeae', N'FP_T1_S2_MKD', 0),
    ('92cda109-62c0-43b3-9e75-a9e682baa85e', N'FP_T1_S2_GW1D12', 0),
    ('7db10493-985b-4626-9433-a54bb550c95b', N'FP_T1_S2_MTG', 0),
    ('f7f438b5-9650-437b-ae7c-2ff943faa2a1', N'FP_T1_S3_DFS', 0),
    ('3352e324-bd07-40f3-be8a-2350c0c097d7', N'FP_T1_S3_MTG', 0),
    ('a7606d5a-bb00-47f3-bfe2-725f09e80746', N'FP_T1_S4_DFS', 0),
    ('32298363-0dd9-4145-8427-adeefb748b56', N'FP_T1_S4_MTG', 0),
    -- Table 2 - Design fire safety strategy invoicing schedule
    ('4656474c-1014-4e4a-9d79-d53d5fc42f63', N'FP_T2_QDR_KEEP', 0),
    ('b807f37d-88c3-400b-ac61-becae91cbd12', N'FP_T2_S2_MKD_KEEP', 0),
    ('45b61d1c-6036-4962-aec7-712530a2d57d', N'FP_T2_S2_D12_KEEP', 0),
    ('984214b7-ad0d-4265-8233-3133771df023', N'FP_T2_S2_GW1_KEEP', 0),
    ('0d3d1a43-7000-4e4b-b022-5a28cb8114d8', N'FP_T2_S3_MKD_KEEP', 0),
    ('c92ae671-9eb5-421c-b724-2cdbf9b0da99', N'FP_T2_S3_DFS_KEEP', 0),
    ('e6cea620-94cf-45c1-8cbf-3c8f28e2ace1', N'FP_T2_S4_MKD_KEEP', 0),
    ('15f1234d-1081-4d95-81d3-719450dd58a1', N'FP_T2_S4_DFS_KEEP', 0),
    -- Table 1 - catch-all rows: every quote item gets a row
    ('fa14a5e4-843f-4618-9c43-5fc13b54e3c7', N'FP_T1_S2_EACH', 0),
    ('70f496b3-63da-48af-8970-8929e781515f', N'FP_T1_S3_EACH', 0),
    ('8601920e-5d18-4c5b-9573-722ba2cef85f', N'FP_T1_S4_EACH', 0),
    ('286eb48b-dceb-484a-9195-eeba9faef632', N'FP_T1_S0_EACH', 0),
    ('307b8607-4025-49c2-8ed1-3fccf54bdfd1', N'FP_T1_S0_SUB', 0),
    ('6f51a6e5-2b18-4874-86a8-bc694bf17b79', N'FP_T1_S0_GAP', 0),
    ('5840e6b6-fb69-415f-9f07-1fdb461b5046', N'FP_T1_S1_EACH', 0),
    ('a9206393-f7ec-4654-bdd2-b754522e4b17', N'FP_T1_S1_SUB', 0),
    ('5b0717b6-6f7d-49e0-b781-dd73bd7af01a', N'FP_T1_S1_GAP', 0),
    ('9929ae86-7731-43fd-880d-0e18b299b349', N'FP_T1_S5_EACH', 0),
    ('2551fec9-0de4-46a7-a6c8-1018df6a27b2', N'FP_T1_S5_SUB', 0),
    ('5df9e3b7-3fdd-4ad8-b479-49c2c0925e1e', N'FP_T1_S5_GAP', 0),
    ('44886e05-e68e-40be-8e1f-a4b0082875da', N'FP_T1_S6_EACH', 0),
    ('ff8bddc1-c17c-483b-8e78-0e4cb2bf41ae', N'FP_T1_S6_SUB', 0),
    ('3cf2fbf4-5a5f-43c0-8d1c-4a5bb915b846', N'FP_T1_S6_GAP', 0),
    ('32ad91bd-b57e-4616-baaa-058a2c0600ab', N'FP_T1_S7_EACH', 0),
    ('eaf95cd6-ec1c-41dd-b1d1-57ce52ec42a8', N'FP_T1_S7_SUB', 0),
    ('bbeb02e3-4662-47b4-b82e-f0c53bf3a21b', N'FP_T1_S7_GAP', 0),
    ('4ee31800-7f58-4a7f-90af-fbc790cda686', N'FP_T1_OTHER_EACH', 0),
    ('a6e119c2-cd29-4323-8c5e-475571fe9a22', N'FP_T1_OTHER_SUB', 0),
    ('a78f7578-8546-4540-9b8a-ce5b3991fc1f', N'FP_T1_OTHER_GAP', 0);

-- StageNumber NULL = any stage (RibaStageId -1). ProductCode NULL = catch-all (ProductId -1).
DECLARE @Gating TABLE
(
    GatingGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    ItemGuid UNIQUEIDENTIFIER NOT NULL,
    ProductCode NVARCHAR(50) NULL,   -- NULL = catch-all (ProductId -1)
    StageNumber INT NULL
);

INSERT @Gating (GatingGuid, ItemGuid, ProductCode, StageNumber)
VALUES
    ('ec96814f-5775-4931-a030-818f7513090a', '448aab26-b61c-440f-9a0a-cee133c13f9b', N'FIRE-QDR', NULL), -- FP_T1_QDR
    ('b25a4b15-1fc3-4f88-9369-d3696887afa4', '0ce522cc-dd38-4ed7-ac4f-b7829a4beeae', N'FIRE-MKD', 2),    -- FP_T1_S2_MKD
    ('0c06e6e6-c446-4769-934b-b37f21a87664', '92cda109-62c0-43b3-9e75-a9e682baa85e', N'FIRE-GW1', 2),    -- FP_T1_S2_GW1D12
    ('e4cb1ddc-93ce-4116-8390-9c4b3ee0fcb8', '92cda109-62c0-43b3-9e75-a9e682baa85e', N'FIRE-D12', 2),
    ('42c47405-d3a2-4910-a1ab-872568519e0b', '7db10493-985b-4626-9433-a54bb550c95b', N'FIRE-MKD', 2),    -- FP_T1_S2_MTG
    ('e83a4aba-40b5-4578-bee9-d5093942a54b', '7db10493-985b-4626-9433-a54bb550c95b', N'FIRE-GW1', 2),
    ('85db4719-ef53-4f68-a058-ed231b25ce92', '7db10493-985b-4626-9433-a54bb550c95b', N'FIRE-D12', 2),
    ('0b056458-e5e3-4ede-b11b-fccbc6f3bd0f', 'f7f438b5-9650-437b-ae7c-2ff943faa2a1', N'FIRE-DFS', 3),    -- FP_T1_S3_DFS
    ('7205fc66-3c6a-4fc8-96cc-dbaf19336666', 'f7f438b5-9650-437b-ae7c-2ff943faa2a1', N'FIRE-MKD', 3),
    ('7e784409-f2ba-467e-a78d-83604abae7f5', '3352e324-bd07-40f3-be8a-2350c0c097d7', N'FIRE-DFS', 3),    -- FP_T1_S3_MTG
    ('e4131107-ffe8-4098-a221-45073772737c', '3352e324-bd07-40f3-be8a-2350c0c097d7', N'FIRE-MKD', 3),
    ('4e1538d7-8778-4e84-8226-7f6e5a567279', 'a7606d5a-bb00-47f3-bfe2-725f09e80746', N'FIRE-DFS', 4),    -- FP_T1_S4_DFS
    ('160c0679-3b42-4265-b43f-24fcb573be2a', 'a7606d5a-bb00-47f3-bfe2-725f09e80746', N'FIRE-MKD', 4),
    ('970d23c6-2db1-46eb-85ec-b500e7117a2f', '32298363-0dd9-4145-8427-adeefb748b56', N'FIRE-DFS', 4),    -- FP_T1_S4_MTG
    ('fa16f64a-f9dc-489c-a23b-62e381d02e2e', '32298363-0dd9-4145-8427-adeefb748b56', N'FIRE-MKD', 4),
    ('acc6722d-3f74-44c6-aaf0-3afb5967857b', '4656474c-1014-4e4a-9d79-d53d5fc42f63', N'FIRE-QDR', NULL), -- FP_T2_QDR_KEEP
    ('39f3e365-074b-4583-91fb-660729d8b98f', 'b807f37d-88c3-400b-ac61-becae91cbd12', N'FIRE-MKD', 2),    -- FP_T2_S2_MKD_KEEP
    ('80b83034-56b5-49a6-9def-932cf78405db', '45b61d1c-6036-4962-aec7-712530a2d57d', N'FIRE-D12', 2),    -- FP_T2_S2_D12_KEEP (always kept; the rule only feeds the fee)
    ('4c20379b-5bd8-4a26-adba-b5555e3176b3', '984214b7-ad0d-4265-8233-3133771df023', N'FIRE-GW1', 2),    -- FP_T2_S2_GW1_KEEP
    ('3d3d142f-a536-47c5-8eac-aca756ae7c45', '0d3d1a43-7000-4e4b-b022-5a28cb8114d8', N'FIRE-MKD', 3),    -- FP_T2_S3_MKD_KEEP
    ('f775f058-52ba-4d2d-8c39-716dc6577bcb', 'c92ae671-9eb5-421c-b724-2cdbf9b0da99', N'FIRE-DFS', 3),    -- FP_T2_S3_DFS_KEEP
    ('56668ccc-8f11-4f7b-8a4b-25dad8afdf45', 'e6cea620-94cf-45c1-8cbf-3c8f28e2ace1', N'FIRE-MKD', 4),    -- FP_T2_S4_MKD_KEEP
    ('887ac0fa-5076-4fd4-9f05-f81cc9c22422', '15f1234d-1081-4d95-81d3-719450dd58a1', N'FIRE-DFS', 4),    -- FP_T2_S4_DFS_KEEP
    ('7694a2ae-e5ef-4d93-a1a2-eb62167ad8e1', 'fa14a5e4-843f-4618-9c43-5fc13b54e3c7', NULL, 2),     -- FP_T1_S2_EACH
    ('551b441e-6ad7-43e7-88fc-414b06ef1ef9', '70f496b3-63da-48af-8970-8929e781515f', NULL, 3),     -- FP_T1_S3_EACH
    ('30ea0e39-706e-4608-a005-c0c63386f288', '8601920e-5d18-4c5b-9573-722ba2cef85f', NULL, 4),     -- FP_T1_S4_EACH
    ('56dbdbdb-df5c-43dd-a5a9-15572e8eecc1', '286eb48b-dceb-484a-9195-eeba9faef632', NULL, 0),     -- FP_T1_S0_EACH
    ('47a1a736-e826-4610-a065-3a15437aa876', '307b8607-4025-49c2-8ed1-3fccf54bdfd1', NULL, 0),     -- FP_T1_S0_SUB
    ('0b5bd00b-bc2e-4b71-87f0-1896750795e3', '6f51a6e5-2b18-4874-86a8-bc694bf17b79', NULL, 0),     -- FP_T1_S0_GAP
    ('cbec7188-7df1-4e80-8a5f-6470ab2ba837', '5840e6b6-fb69-415f-9f07-1fdb461b5046', NULL, 1),     -- FP_T1_S1_EACH
    ('0f95e3c0-c378-4701-a2c5-54e86c764efc', 'a9206393-f7ec-4654-bdd2-b754522e4b17', NULL, 1),     -- FP_T1_S1_SUB
    ('3cf24519-0a80-4e98-9289-c7659ae9e0d3', '5b0717b6-6f7d-49e0-b781-dd73bd7af01a', NULL, 1),     -- FP_T1_S1_GAP
    ('3737e7ad-bc2d-4187-a51e-2c60845e5cb8', '9929ae86-7731-43fd-880d-0e18b299b349', NULL, 5),     -- FP_T1_S5_EACH
    ('6dfc933c-33f4-4324-9ebc-80a2c0be3fb1', '2551fec9-0de4-46a7-a6c8-1018df6a27b2', NULL, 5),     -- FP_T1_S5_SUB
    ('4ea0c4e8-7360-4cd7-a5ec-ed2b807c2df7', '5df9e3b7-3fdd-4ad8-b479-49c2c0925e1e', NULL, 5),     -- FP_T1_S5_GAP
    ('d6329e10-6816-43dc-b045-c2a79035c343', '44886e05-e68e-40be-8e1f-a4b0082875da', NULL, 6),     -- FP_T1_S6_EACH
    ('321f4d1e-a5de-4d2f-a9ab-0a915b501c22', 'ff8bddc1-c17c-483b-8e78-0e4cb2bf41ae', NULL, 6),     -- FP_T1_S6_SUB
    ('fd2dbe4f-7da7-4968-b9d2-2d52f5c17b35', '3cf2fbf4-5a5f-43c0-8d1c-4a5bb915b846', NULL, 6),     -- FP_T1_S6_GAP
    ('d7857ff9-9420-4075-a4eb-dc2036361635', '32ad91bd-b57e-4616-baaa-058a2c0600ab', NULL, 7),     -- FP_T1_S7_EACH
    ('88199d34-70cf-47c5-81e0-b2c1a7eca600', 'eaf95cd6-ec1c-41dd-b1d1-57ce52ec42a8', NULL, 7),     -- FP_T1_S7_SUB
    ('f3209830-4431-4cac-b1e1-81bc6a753d73', 'bbeb02e3-4662-47b4-b82e-f0c53bf3a21b', NULL, 7),     -- FP_T1_S7_GAP
    ('165dc09c-6442-415f-bd3a-e98e29b5ad1e', '4ee31800-7f58-4a7f-90af-fbc790cda686', NULL, NULL),  -- FP_T1_OTHER_EACH
    ('b320b07f-0ca7-4cce-afc1-cc424c87cdf8', 'a6e119c2-cd29-4323-8c5e-475571fe9a22', NULL, NULL),  -- FP_T1_OTHER_SUB
    ('1e7eb0ce-6e3b-4cb9-ad26-637fecb2e6c1', 'a78f7578-8546-4540-9b8a-ce5b3991fc1f', NULL, NULL);  -- FP_T1_OTHER_GAP

------------------------------------------------------------------------------------------
-- Resolve and validate dependencies before changing anything.
------------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM SCore.MergeDocuments WHERE Guid = @MergeDocumentGuid AND RowStatus NOT IN (0,254))
    THROW 60000, N'CYB-323: Fire Engineering Fee Proposal MergeDocument not found.', 1;

IF NOT EXISTS (SELECT 1 FROM SCore.EntityTypes WHERE Guid = @QuoteEntityTypeGuid)
    THROW 60000, N'CYB-323: Quote EntityType not found.', 1;

IF NOT EXISTS (SELECT 1 FROM SCore.MergeDocumentItemTypes WHERE Guid = @ConditionalRowTypeGuid AND RowStatus NOT IN (0,254))
    THROW 60000, N'CYB-323: "Conditional Row" MergeDocumentItemType not found - run CYB-323_MergeDocumentItemType_ConditionalRow.sql first.', 1;

-- WordDocumentService matches item types by Name, so Name is the contract here.
IF (SELECT COUNT(1) FROM SCore.MergeDocumentItemTypes WHERE Name = N'Signature' AND RowStatus NOT IN (0,254)) <> 1
    THROW 60000, N'CYB-323: expected exactly one active "Signature" MergeDocumentItemType.', 1;

SELECT @SignatureTypeGuid = Guid
FROM SCore.MergeDocumentItemTypes
WHERE Name = N'Signature'
  AND RowStatus NOT IN (0,254);

IF COL_LENGTH(N'SCore.MergeDocumentItemGatingProducts', N'RibaStageId') IS NULL
    THROW 60000, N'CYB-323: SCore.MergeDocumentItemGatingProducts.RibaStageId missing - deploy the schema first.', 1;

DECLARE @MissingProducts NVARCHAR(MAX) =
(
    SELECT STRING_AGG(m.ProductCode, N', ')
    FROM (SELECT DISTINCT g.ProductCode FROM @Gating AS g WHERE g.ProductCode IS NOT NULL) AS m
    WHERE NOT EXISTS (SELECT 1 FROM SProd.Products AS p WHERE p.Code = m.ProductCode AND p.RowStatus NOT IN (0,254))
);
IF @MissingProducts IS NOT NULL
BEGIN
    DECLARE @MissingProductsMessage NVARCHAR(2048) = N'CYB-323: active products not found: ' + @MissingProducts + N' - run the product code alignment first.';
    THROW 60000, @MissingProductsMessage, 1;
END;

IF NOT EXISTS (SELECT 1 FROM SProd.Products WHERE ID = -1)
    THROW 60000, N'CYB-323: SProd.Products row -1 (used by catch-all gating rules) not found.', 1;

IF EXISTS
(
    SELECT 1
    FROM (SELECT DISTINCT g.StageNumber FROM @Gating AS g WHERE g.StageNumber IS NOT NULL) AS s
    WHERE (SELECT COUNT(1) FROM SJob.RibaStages AS rs WHERE rs.Number = s.StageNumber AND rs.ID > 0 AND rs.RowStatus NOT IN (0,254)) <> 1
)
    THROW 60000, N'CYB-323: expected exactly one active SJob.RibaStages row for each RIBA stage number used.', 1;

------------------------------------------------------------------------------------------
-- Apply.
------------------------------------------------------------------------------------------
BEGIN TRANSACTION;

DECLARE @ItemGuid UNIQUEIDENTIFIER,
        @BookmarkName NVARCHAR(50),
        @IsSignature BIT,
        @TypeGuid UNIQUEIDENTIFIER;

DECLARE ItemCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT ItemGuid, BookmarkName, IsSignature FROM @Items;

OPEN ItemCursor;
FETCH NEXT FROM ItemCursor INTO @ItemGuid, @BookmarkName, @IsSignature;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @TypeGuid = CASE WHEN @IsSignature = 1 THEN @SignatureTypeGuid ELSE @ConditionalRowTypeGuid END;

    -- Creates the SCore.DataObjects row on insert.
    EXEC SCore.MergeDocumentItemsUpsert
        @MergeDocumentGuid = @MergeDocumentGuid,
        @MergeDocumentItemTypeGuid = @TypeGuid,
        @BookmarkName = @BookmarkName,
        @EntityTypeGuid = @QuoteEntityTypeGuid,
        @SubFolderPath = N'',
        @ImageColumns = 0,
        @Guid = @ItemGuid OUTPUT;

    FETCH NEXT FROM ItemCursor INTO @ItemGuid, @BookmarkName, @IsSignature;
END;
CLOSE ItemCursor;
DEALLOCATE ItemCursor;

-- One gating row per rule per active product with that code. Some environments (LIVE and its
-- QA2 replica) have duplicate active products under one code, e.g. two FIRE-DFS rows both used
-- on quote items, and ConditionalRowMergeEvaluator matches on ProductId, so every duplicate must
-- be gated. Rows are matched on the natural key (item, product, stage), which
-- IX_UQ_MergeDocumentItemGatingProducts_Item_Product enforces. The rule's fixed Guid goes to the
-- lowest-ID product; any further duplicates get a new Guid.
DECLARE @Desired TABLE
(
    GatingGuid UNIQUEIDENTIFIER NULL,
    MergeDocumentItemId INT NOT NULL,
    ProductId INT NOT NULL,
    RibaStageId INT NOT NULL,
    PRIMARY KEY (MergeDocumentItemId, ProductId, RibaStageId)
);

INSERT @Desired (GatingGuid, MergeDocumentItemId, ProductId, RibaStageId)
SELECT CASE WHEN p.ID = MIN(p.ID) OVER (PARTITION BY g.GatingGuid) THEN g.GatingGuid END,
       mdi.ID,
       p.ID,
       ISNULL(rs.ID, -1)
FROM @Gating AS g
JOIN SCore.MergeDocumentItems AS mdi ON mdi.Guid = g.ItemGuid
JOIN SProd.Products AS p ON p.Code = g.ProductCode AND p.RowStatus NOT IN (0,254)
LEFT JOIN SJob.RibaStages AS rs ON rs.Number = g.StageNumber AND rs.ID > 0 AND rs.RowStatus NOT IN (0,254)
WHERE g.ProductCode IS NOT NULL
UNION ALL
SELECT g.GatingGuid,
       mdi.ID,
       -1,
       ISNULL(rs.ID, -1)
FROM @Gating AS g
JOIN SCore.MergeDocumentItems AS mdi ON mdi.Guid = g.ItemGuid
LEFT JOIN SJob.RibaStages AS rs ON rs.Number = g.StageNumber AND rs.ID > 0 AND rs.RowStatus NOT IN (0,254)
WHERE g.ProductCode IS NULL;

-- Reactivate desired rows that exist but were soft-deleted.
UPDATE gp
SET    gp.RowStatus = 1
FROM   SCore.MergeDocumentItemGatingProducts AS gp
JOIN   @Desired AS d ON d.MergeDocumentItemId = gp.MergeDocumentItemId
                    AND d.ProductId = gp.ProductId
                    AND d.RibaStageId = gp.RibaStageId
WHERE  gp.RowStatus <> 1;

-- Retire rows on this document's conditional items that are no longer desired.
UPDATE gp
SET    gp.RowStatus = 254
FROM   SCore.MergeDocumentItemGatingProducts AS gp
JOIN   SCore.MergeDocumentItems AS mdi ON mdi.ID = gp.MergeDocumentItemId
JOIN   @Items AS i ON i.ItemGuid = mdi.Guid
WHERE  gp.RowStatus NOT IN (0,254)
  AND  NOT EXISTS (SELECT 1 FROM @Desired AS d
                   WHERE d.MergeDocumentItemId = gp.MergeDocumentItemId
                     AND d.ProductId = gp.ProductId
                     AND d.RibaStageId = gp.RibaStageId);

-- Insert missing rows. If the rule's fixed Guid is already used by a retired row, use a new one.
INSERT SCore.MergeDocumentItemGatingProducts (Guid, RowStatus, MergeDocumentItemId, ProductId, RibaStageId)
SELECT CASE WHEN d.GatingGuid IS NOT NULL
             AND NOT EXISTS (SELECT 1 FROM SCore.MergeDocumentItemGatingProducts AS gg WHERE gg.Guid = d.GatingGuid)
            THEN d.GatingGuid
            ELSE NEWID()
       END,
       1,
       d.MergeDocumentItemId,
       d.ProductId,
       d.RibaStageId
FROM @Desired AS d
WHERE NOT EXISTS (SELECT 1 FROM SCore.MergeDocumentItemGatingProducts AS gp
                  WHERE gp.MergeDocumentItemId = d.MergeDocumentItemId
                    AND gp.ProductId = d.ProductId
                    AND gp.RibaStageId = d.RibaStageId);

COMMIT TRANSACTION;

------------------------------------------------------------------------------------------
-- Verify.
------------------------------------------------------------------------------------------
SELECT mdi.BookmarkName,
       mdit.Name AS ItemType,
       p.Code AS ProductCode,
       p.ID AS ProductId,
       rs.Number AS RibaStageNumber
FROM SCore.MergeDocumentItems AS mdi
JOIN SCore.MergeDocuments AS md ON md.ID = mdi.MergeDocumentId
JOIN SCore.MergeDocumentItemTypes AS mdit ON mdit.ID = mdi.MergeDocumentItemTypeId
LEFT JOIN SCore.MergeDocumentItemGatingProducts AS gp ON gp.MergeDocumentItemId = mdi.ID AND gp.RowStatus NOT IN (0,254)
LEFT JOIN SProd.Products AS p ON p.ID = gp.ProductId
LEFT JOIN SJob.RibaStages AS rs ON rs.ID = gp.RibaStageId AND rs.ID > 0
WHERE md.Guid = @MergeDocumentGuid
  AND mdi.RowStatus NOT IN (0,254)
ORDER BY mdi.BookmarkName, p.Code, p.ID;
