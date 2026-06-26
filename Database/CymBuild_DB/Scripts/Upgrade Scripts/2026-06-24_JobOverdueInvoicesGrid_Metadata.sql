SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER FUNCTION [SFin].[tvf_JobOverdueTransactions]
(
    @UserId     INT,
    @ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
AS
RETURN
    SELECT
        t.ID,
        t.RowStatus,
        t.RowVersion,
        t.Guid,
        ISNULL(CurrentStatus.Name, N'') AS Status,
        t.Date,
        t.Number,
        tt.Name AS Type,
        account.Name AS FinanceAccount,
        CONVERT(DECIMAL(19, 2), tc.Gross) AS Gross,
        CONVERT(DECIMAL(19, 2), tc.Net) AS Net,
        CONVERT(DECIMAL(19, 2), tc.Vat) AS Vat,
        CONVERT(DECIMAL(19, 2), tc.RealOutstanding) AS Outstanding,
        CONVERT(DATE, tc.DueDate) AS DueDate,
        DATEDIFF(DAY, CONVERT(DATE, tc.DueDate), CONVERT(DATE, GETDATE())) AS DaysOverdue,
        t.PurchaseOrderNumber,
        t.SageTransactionReference,
        ISNULL(surveyor.FullName, N'') AS Consultant
    FROM
        SFin.Transactions AS t
    JOIN
        SJob.Jobs AS j ON (j.ID = t.JobID)
    JOIN
        SFin.TransactionTypes AS tt ON (tt.ID = t.TransactionTypeID)
    JOIN
        SFin.TransactionCalculations AS tc ON (tc.ID = t.ID)
    JOIN
        SCrm.Accounts AS account ON (account.ID = t.AccountID)
    LEFT JOIN
        SCore.Identities AS surveyor ON (surveyor.ID = t.SurveyorUserId)
    OUTER APPLY
        (
            SELECT TOP (1)
                wfs.Name
            FROM
                SCore.DataObjectTransition AS dot
            JOIN
                SCore.WorkflowStatus AS wfs ON (wfs.ID = dot.StatusID)
            WHERE
                (dot.DataObjectGuid = t.Guid)
                AND (dot.RowStatus NOT IN (0, 254))
                AND (wfs.RowStatus NOT IN (0, 254))
            ORDER BY
                dot.DateTimeUTC DESC,
                dot.ID DESC
        ) AS CurrentStatus
    WHERE
        (j.Guid = @ParentGuid)
        AND (j.RowStatus NOT IN (0, 254))
        AND (t.RowStatus NOT IN (0, 254))
        AND (tt.RowStatus NOT IN (0, 254))
        AND (tt.IsBank = 0)
        AND (tc.RealOutstanding <> 0)
        AND (tc.DueDate < GETDATE())
        AND EXISTS
            (
                SELECT 1
                FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscrJob
            )
        AND EXISTS
            (
                SELECT 1
                FROM SCore.ObjectSecurityForUser_CanRead(t.Guid, @UserId) AS oscrTransaction
            );
GO

SET XACT_ABORT ON;
GO

BEGIN TRANSACTION;

DECLARE @GridDefinitionGuid UNIQUEIDENTIFIER = 'b6385fa4-e8cf-4484-a0e3-2a8399505618';
DECLARE @GridViewDefinitionGuid UNIQUEIDENTIFIER = 'c3b116df-529c-43d3-855e-c6327e6854b1';
DECLARE @GridCode NVARCHAR(30) = N'JOBOVERDUEINVOICES';
DECLARE @GridViewCode NVARCHAR(20) = N'JOBOVERDUEINVOICES';
DECLARE @TransactionEntityTypeId INT;
DECLARE @GridDefinitionId INT;
DECLARE @GridViewDefinitionId INT;
DECLARE @GridLabelId INT;
DECLARE @DefaultLanguageId INT;

SELECT
    @TransactionEntityTypeId = et.ID
FROM
    SCore.EntityTypes AS et
WHERE
    et.Guid = '3679db86-9a2f-45bd-9e37-8e40967166d1'
    AND et.RowStatus NOT IN (0, 254);

SELECT
    @DefaultLanguageId = COALESCE(
        (SELECT TOP (1) l.ID FROM SCore.Languages AS l WHERE l.ID = 1 AND l.RowStatus NOT IN (0, 254)),
        (SELECT TOP (1) l.ID FROM SCore.Languages AS l WHERE l.RowStatus NOT IN (0, 254) ORDER BY l.ID)
    );

IF @DefaultLanguageId IS NULL
BEGIN
    THROW 51001, 'No active language was found. Cannot apply JOBOVERDUEINVOICES labels.', 1;
END;

IF @TransactionEntityTypeId IS NULL
BEGIN
    THROW 51000, 'Transactions EntityType was not found. Cannot apply JOBOVERDUEINVOICES metadata.', 1;
END;

DECLARE @Labels TABLE
(
    LabelGuid UNIQUEIDENTIFIER NOT NULL,
    LabelName NVARCHAR(250) NOT NULL,
    LabelText NVARCHAR(250) NOT NULL,
    LabelTextPlural NVARCHAR(250) NOT NULL
);

INSERT INTO @Labels
    (LabelGuid, LabelName, LabelText, LabelTextPlural)
VALUES
    ('5bfbb9e5-d3b6-477c-bb78-0b72317ffe32', N'JOBOVERDUEINVOICES_grid', N'Overdue invoices', N'Overdue invoices'),
    ('4a2bff49-1c12-472b-a844-b12dcbfbad65', N'JOBOVERDUEINVOICES.Status', N'Status', N'Status'),
    ('5d74aa19-26a9-48ef-a003-0c63f9523a60', N'JOBOVERDUEINVOICES.Date', N'Date', N'Date'),
    ('fb4d4666-9095-4409-acf1-02e385ef4b91', N'JOBOVERDUEINVOICES.Number', N'Number', N'Number'),
    ('63383278-9539-4bcb-9057-e5ca84159436', N'JOBOVERDUEINVOICES.Type', N'Type', N'Type'),
    ('aff877c7-8d52-4132-ab78-4f5514e44590', N'JOBOVERDUEINVOICES.FinanceAccount', N'Finance Account', N'Finance Accounts'),
    ('c0dfde77-f00f-4690-ba8b-e5cd81b7e52e', N'JOBOVERDUEINVOICES.Gross', N'Gross', N'Gross'),
    ('25a87a93-fcf9-46ba-a12a-a8e43bafc236', N'JOBOVERDUEINVOICES.Net', N'Net', N'Net'),
    ('475aba7b-d7bd-401e-9318-abf9d123064c', N'JOBOVERDUEINVOICES.Vat', N'VAT', N'VAT'),
    ('373d23f1-3dbc-4f7c-9a39-4661c6a611b7', N'JOBOVERDUEINVOICES.Outstanding', N'Outstanding', N'Outstanding'),
    ('e7986f08-7244-4cd2-bf90-822f54ae8c85', N'JOBOVERDUEINVOICES.DueDate', N'Due Date', N'Due Date'),
    ('b0a55947-c329-4b5e-a81e-b1d952114389', N'JOBOVERDUEINVOICES.DaysOverdue', N'Days Overdue', N'Days Overdue'),
    ('e961c8b5-0275-4b70-a57f-4f22c3c22010', N'JOBOVERDUEINVOICES.PurchaseOrderNumber', N'Purchase Order Number', N'Purchase Order Numbers'),
    ('ee4f0da8-4b9e-4dfb-966a-7a7642b679d8', N'JOBOVERDUEINVOICES.SageTransactionReference', N'Sage Transaction Reference', N'Sage Transaction References'),
    ('b5ff319a-7156-426f-b475-4b2c4a071bf8', N'JOBOVERDUEINVOICES.Consultant', N'Consultant', N'Consultants');

UPDATE ll
SET
    ll.RowStatus = 1,
    ll.Name = src.LabelName
FROM
    SCore.LanguageLabels AS ll
JOIN
    @Labels AS src ON (src.LabelGuid = ll.Guid);

INSERT INTO SCore.LanguageLabels
    (RowStatus, Guid, Name)
SELECT
    1,
    src.LabelGuid,
    src.LabelName
FROM
    @Labels AS src
WHERE
    NOT EXISTS
    (
        SELECT 1
        FROM SCore.LanguageLabels AS ll
        WHERE ll.Guid = src.LabelGuid
    );

UPDATE llt
SET
    llt.RowStatus = 1,
    llt.Text = src.LabelText,
    llt.TextPlural = src.LabelTextPlural,
    llt.HelpText = N''
FROM
    SCore.LanguageLabelTranslations AS llt
JOIN
    SCore.LanguageLabels AS ll ON (ll.ID = llt.LanguageLabelID)
JOIN
    @Labels AS src ON (src.LabelGuid = ll.Guid)
WHERE
    llt.LanguageID = @DefaultLanguageId;

INSERT INTO SCore.LanguageLabelTranslations
    (RowStatus, Guid, Text, TextPlural, LanguageLabelID, LanguageID, HelpText)
SELECT
    1,
    NEWID(),
    src.LabelText,
    src.LabelTextPlural,
    ll.ID,
    @DefaultLanguageId,
    N''
FROM
    @Labels AS src
JOIN
    SCore.LanguageLabels AS ll ON (ll.Guid = src.LabelGuid)
WHERE
    NOT EXISTS
    (
        SELECT 1
        FROM SCore.LanguageLabelTranslations AS llt
        WHERE
            llt.LanguageLabelID = ll.ID
            AND llt.LanguageID = @DefaultLanguageId
            AND llt.RowStatus NOT IN (0, 254)
    );

SELECT
    @GridLabelId = ll.ID
FROM
    SCore.LanguageLabels AS ll
WHERE
    ll.Guid = '5bfbb9e5-d3b6-477c-bb78-0b72317ffe32';

IF EXISTS (SELECT 1 FROM SUserInterface.GridDefinitions WHERE Guid = @GridDefinitionGuid)
BEGIN
    UPDATE SUserInterface.GridDefinitions
    SET
        RowStatus = 1,
        Code = @GridCode,
        PageUri = N'',
        TabName = N'',
        ShowAsTiles = 0,
        LanguageLabelId = @GridLabelId
    WHERE
        Guid = @GridDefinitionGuid;
END
ELSE IF EXISTS (SELECT 1 FROM SUserInterface.GridDefinitions WHERE Code = @GridCode AND RowStatus NOT IN (0, 254))
BEGIN
    UPDATE SUserInterface.GridDefinitions
    SET
        Guid = @GridDefinitionGuid,
        RowStatus = 1,
        PageUri = N'',
        TabName = N'',
        ShowAsTiles = 0,
        LanguageLabelId = @GridLabelId
    WHERE
        Code = @GridCode
        AND RowStatus NOT IN (0, 254);
END
ELSE
BEGIN
    INSERT INTO SUserInterface.GridDefinitions
        (RowStatus, Guid, Code, PageUri, TabName, ShowAsTiles, LanguageLabelId)
    VALUES
        (1, @GridDefinitionGuid, @GridCode, N'', N'', 0, @GridLabelId);
END;

SELECT
    @GridDefinitionId = gd.ID
FROM
    SUserInterface.GridDefinitions AS gd
WHERE
    gd.Guid = @GridDefinitionGuid;

IF EXISTS (SELECT 1 FROM SUserInterface.GridViewDefinitions WHERE Guid = @GridViewDefinitionGuid)
BEGIN
    UPDATE SUserInterface.GridViewDefinitions
    SET
        RowStatus = 1,
        Code = @GridViewCode,
        GridDefinitionId = @GridDefinitionId,
        DetailPageUri = N'TransactionDetail',
        SqlQuery = N'SELECT
        root_hobt.ID,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Guid,
        root_hobt.Status,
        root_hobt.Date,
        root_hobt.Number,
        root_hobt.Type,
        root_hobt.FinanceAccount,
        root_hobt.Gross,
        root_hobt.Net,
        root_hobt.Vat,
        root_hobt.Outstanding,
        root_hobt.DueDate,
        root_hobt.DaysOverdue,
        root_hobt.PurchaseOrderNumber,
        root_hobt.SageTransactionReference,
        root_hobt.Consultant
FROM    [SFin].[tvf_JobOverdueTransactions]([[UserId]], [[ParentGuid]]) AS root_hobt',
        DefaultSortColumnName = N'DueDate',
        SecurableCode = N'',
        DisplayOrder = 0,
        DisplayGroupName = N'',
        MetricSqlQuery = N'',
        ShowMetric = 0,
        IsDetailWindowed = 1,
        EntityTypeID = @TransactionEntityTypeId,
        MetricTypeID = -1,
        MetricMin = 0,
        MetricMax = 0,
        MetricMinorUnit = 0,
        MetricMajorUnit = 0,
        MetricStartAngle = 0,
        MetricEndAngle = 0,
        MetricReversed = 0,
        MetricRange1Min = 0,
        MetricRange1Max = 0,
        MetricRange1ColourHex = N'',
        MetricRange2Min = 0,
        MetricRange2Max = 0,
        MetricRange2ColourHex = N'',
        IsDefaultSortDescending = 0,
        AllowNew = 0,
        AllowExcelExport = 1,
        AllowPdfExport = 0,
        AllowCsvExport = 0,
        LanguageLabelId = @GridLabelId,
        DrawerIconId = 69,
        GridViewTypeId = 1,
        AllowBulkChange = 0,
        ShowOnMobile = 0,
        TreeListFirstOrderBy = N'',
        TreeListSecondOrderBy = N'',
        TreeListThirdOrderBy = N'',
        TreeListOrderBy = N'',
        TreeListGroupBy = N'',
        ShowOnDashboard = 0,
        FilteredListCreatedOnColumn = N'',
        FilteredListRedStatusIndicatorTxt = N'',
        FilteredListOrangeStatusIndicatorTxt = N'',
        FilteredListGreenStatusIndicatorTxt = N'',
        FilteredListGroupBy = N'',
        IsHidden = 0
    WHERE
        Guid = @GridViewDefinitionGuid;
END
ELSE IF EXISTS (SELECT 1 FROM SUserInterface.GridViewDefinitions WHERE GridDefinitionId = @GridDefinitionId AND Code = @GridViewCode AND RowStatus NOT IN (0, 254))
BEGIN
    UPDATE SUserInterface.GridViewDefinitions
    SET
        Guid = @GridViewDefinitionGuid,
        RowStatus = 1
    WHERE
        GridDefinitionId = @GridDefinitionId
        AND Code = @GridViewCode
        AND RowStatus NOT IN (0, 254);

    UPDATE SUserInterface.GridViewDefinitions
    SET
        DetailPageUri = N'TransactionDetail',
        SqlQuery = N'SELECT
        root_hobt.ID,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Guid,
        root_hobt.Status,
        root_hobt.Date,
        root_hobt.Number,
        root_hobt.Type,
        root_hobt.FinanceAccount,
        root_hobt.Gross,
        root_hobt.Net,
        root_hobt.Vat,
        root_hobt.Outstanding,
        root_hobt.DueDate,
        root_hobt.DaysOverdue,
        root_hobt.PurchaseOrderNumber,
        root_hobt.SageTransactionReference,
        root_hobt.Consultant
FROM    [SFin].[tvf_JobOverdueTransactions]([[UserId]], [[ParentGuid]]) AS root_hobt',
        DefaultSortColumnName = N'DueDate',
        IsDetailWindowed = 1,
        EntityTypeID = @TransactionEntityTypeId,
        IsDefaultSortDescending = 0,
        AllowNew = 0,
        AllowExcelExport = 1,
        LanguageLabelId = @GridLabelId,
        DrawerIconId = 69,
        GridViewTypeId = 1,
        IsHidden = 0
    WHERE
        Guid = @GridViewDefinitionGuid;
END
ELSE
BEGIN
    INSERT INTO SUserInterface.GridViewDefinitions
        (RowStatus, Guid, Code, GridDefinitionId, DetailPageUri, SqlQuery, DefaultSortColumnName, SecurableCode, DisplayOrder, DisplayGroupName, MetricSqlQuery, ShowMetric, IsDetailWindowed, EntityTypeID, MetricTypeID, MetricMin, MetricMax, MetricMinorUnit, MetricMajorUnit, MetricStartAngle, MetricEndAngle, MetricReversed, MetricRange1Min, MetricRange1Max, MetricRange1ColourHex, MetricRange2Min, MetricRange2Max, MetricRange2ColourHex, IsDefaultSortDescending, AllowNew, AllowExcelExport, AllowPdfExport, AllowCsvExport, LanguageLabelId, DrawerIconId, GridViewTypeId, AllowBulkChange, ShowOnMobile, TreeListFirstOrderBy, TreeListSecondOrderBy, TreeListThirdOrderBy, TreeListOrderBy, TreeListGroupBy, ShowOnDashboard, FilteredListCreatedOnColumn, FilteredListRedStatusIndicatorTxt, FilteredListOrangeStatusIndicatorTxt, FilteredListGreenStatusIndicatorTxt, FilteredListGroupBy, IsHidden)
    VALUES
        (1, @GridViewDefinitionGuid, @GridViewCode, @GridDefinitionId, N'TransactionDetail', N'SELECT
        root_hobt.ID,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Guid,
        root_hobt.Status,
        root_hobt.Date,
        root_hobt.Number,
        root_hobt.Type,
        root_hobt.FinanceAccount,
        root_hobt.Gross,
        root_hobt.Net,
        root_hobt.Vat,
        root_hobt.Outstanding,
        root_hobt.DueDate,
        root_hobt.DaysOverdue,
        root_hobt.PurchaseOrderNumber,
        root_hobt.SageTransactionReference,
        root_hobt.Consultant
FROM    [SFin].[tvf_JobOverdueTransactions]([[UserId]], [[ParentGuid]]) AS root_hobt', N'DueDate', N'', 0, N'', N'', 0, 1, @TransactionEntityTypeId, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, N'', 0, 0, N'', 0, 0, 1, 0, 0, @GridLabelId, 69, 1, 0, 0, N'', N'', N'', N'', N'', 0, N'', N'', N'', N'', N'', 0);
END;

SELECT
    @GridViewDefinitionId = gvd.ID
FROM
    SUserInterface.GridViewDefinitions AS gvd
WHERE
    gvd.Guid = @GridViewDefinitionGuid;

DECLARE @Columns TABLE
(
    ColumnGuid UNIQUEIDENTIFIER NOT NULL,
    Name NVARCHAR(100) NOT NULL,
    ColumnOrder INT NOT NULL,
    IsPrimaryKey BIT NOT NULL,
    IsHidden BIT NOT NULL,
    IsFiltered BIT NOT NULL,
    DisplayFormat NVARCHAR(50) NOT NULL,
    Width NVARCHAR(10) NOT NULL,
    LabelGuid UNIQUEIDENTIFIER NULL
);

INSERT INTO @Columns
    (ColumnGuid, Name, ColumnOrder, IsPrimaryKey, IsHidden, IsFiltered, DisplayFormat, Width, LabelGuid)
VALUES
    ('9e0c654a-cb48-4e49-8ef5-ac292c2c8a47', N'ID', 0, 1, 1, 0, N'', N'', NULL),
    ('af00f5af-0077-4244-8e9e-07e80e47eefa', N'RowStatus', 0, 0, 1, 0, N'', N'', NULL),
    ('7357ead8-1c25-49aa-bd42-c79522f01fd5', N'RowVersion', 0, 0, 1, 0, N'', N'', NULL),
    ('08c711a2-73b9-4020-9744-dffc4cc176bd', N'Guid', 0, 0, 1, 0, N'', N'', NULL),
    ('86750c6a-39a1-4106-b6ed-83ac372711b9', N'Status', 1, 0, 0, 1, N'', N'170px', '4a2bff49-1c12-472b-a844-b12dcbfbad65'),
    ('98c03285-0e89-4a38-b82c-48746533c133', N'Date', 2, 0, 0, 1, N'', N'130px', '5d74aa19-26a9-48ef-a003-0c63f9523a60'),
    ('23cd36ce-4cd4-4990-9bbf-b0918af6035d', N'Number', 3, 0, 0, 1, N'', N'130px', 'fb4d4666-9095-4409-acf1-02e385ef4b91'),
    ('b0315295-90da-4a30-80ee-b22c044c8655', N'Type', 4, 0, 0, 1, N'', N'110px', '63383278-9539-4bcb-9057-e5ca84159436'),
    ('680a3b89-257a-4676-86cc-7cfe205f30f1', N'FinanceAccount', 5, 0, 0, 1, N'', N'240px', 'aff877c7-8d52-4132-ab78-4f5514e44590'),
    ('1208f07e-e659-476e-a9e0-6aee65e88f61', N'Gross', 6, 0, 0, 0, N'', N'100px', 'c0dfde77-f00f-4690-ba8b-e5cd81b7e52e'),
    ('426d8fd5-1b31-4516-92c7-3d3c52b60cc1', N'Net', 7, 0, 0, 0, N'', N'100px', '25a87a93-fcf9-46ba-a12a-a8e43bafc236'),
    ('dfce0fb9-0a11-48d8-baff-a7eaa169807e', N'Vat', 8, 0, 0, 0, N'', N'100px', '475aba7b-d7bd-401e-9318-abf9d123064c'),
    ('752cea35-c7cc-47c8-91ad-6bd94e74bf3a', N'Outstanding', 9, 0, 0, 0, N'', N'120px', '373d23f1-3dbc-4f7c-9a39-4661c6a611b7'),
    ('d562e534-36d4-4b2a-b63b-ff59ebb6bb47', N'DueDate', 10, 0, 0, 1, N'', N'130px', 'e7986f08-7244-4cd2-bf90-822f54ae8c85'),
    ('ab2ffc87-a7e0-4d04-9896-ac05d3253024', N'DaysOverdue', 11, 0, 0, 0, N'', N'120px', 'b0a55947-c329-4b5e-a81e-b1d952114389'),
    ('8ec977b8-818f-4c9a-bf1b-c1d1c2f5577f', N'PurchaseOrderNumber', 12, 0, 0, 1, N'', N'160px', 'e961c8b5-0275-4b70-a57f-4f22c3c22010'),
    ('cf749659-5b81-42fb-931e-352b6c0e818a', N'SageTransactionReference', 13, 0, 0, 1, N'', N'190px', 'ee4f0da8-4b9e-4dfb-966a-7a7642b679d8'),
    ('1b413a28-5b09-4346-9c40-2e13977aba1f', N'Consultant', 14, 0, 0, 1, N'', N'170px', 'b5ff319a-7156-426f-b475-4b2c4a071bf8');

UPDATE gvcd
SET
    gvcd.RowStatus = 1,
    gvcd.Name = src.Name,
    gvcd.ColumnOrder = src.ColumnOrder,
    gvcd.GridViewDefinitionId = @GridViewDefinitionId,
    gvcd.IsPrimaryKey = src.IsPrimaryKey,
    gvcd.IsHidden = src.IsHidden,
    gvcd.IsFiltered = src.IsFiltered,
    gvcd.IsCombo = 0,
    gvcd.IsLongitude = 0,
    gvcd.IsLatitude = 0,
    gvcd.DisplayFormat = src.DisplayFormat,
    gvcd.Width = src.Width,
    gvcd.LanguageLabelId = ISNULL(ll.ID, -1),
    gvcd.TopHeaderCategory = N'',
    gvcd.TopHeaderCategoryOrder = 0
FROM
    SUserInterface.GridViewColumnDefinitions AS gvcd
JOIN
    @Columns AS src ON (src.ColumnGuid = gvcd.Guid)
LEFT JOIN
    SCore.LanguageLabels AS ll ON (ll.Guid = src.LabelGuid);

INSERT INTO SUserInterface.GridViewColumnDefinitions
    (RowStatus, Guid, Name, ColumnOrder, GridViewDefinitionId, IsPrimaryKey, IsHidden, IsFiltered, IsCombo, IsLongitude, IsLatitude, DisplayFormat, Width, LanguageLabelId, TopHeaderCategory, TopHeaderCategoryOrder)
SELECT
    1,
    src.ColumnGuid,
    src.Name,
    src.ColumnOrder,
    @GridViewDefinitionId,
    src.IsPrimaryKey,
    src.IsHidden,
    src.IsFiltered,
    0,
    0,
    0,
    src.DisplayFormat,
    src.Width,
    ISNULL(ll.ID, -1),
    N'',
    0
FROM
    @Columns AS src
LEFT JOIN
    SCore.LanguageLabels AS ll ON (ll.Guid = src.LabelGuid)
WHERE
    NOT EXISTS
    (
        SELECT 1
        FROM SUserInterface.GridViewColumnDefinitions AS gvcd
        WHERE gvcd.Guid = src.ColumnGuid
    );


COMMIT TRANSACTION;
GO

-- Verification
SELECT
    gd.Code AS GridCode,
    gvd.Code AS GridViewCode,
    gvd.DetailPageUri,
    gvd.DefaultSortColumnName,
    gvd.IsDetailWindowed,
    gvd.EntityTypeID,
    COUNT(gvcd.ID) AS ColumnCount
FROM
    SUserInterface.GridDefinitions AS gd
JOIN
    SUserInterface.GridViewDefinitions AS gvd ON (gvd.GridDefinitionId = gd.ID)
LEFT JOIN
    SUserInterface.GridViewColumnDefinitions AS gvcd ON (gvcd.GridViewDefinitionId = gvd.ID AND gvcd.RowStatus NOT IN (0, 254))
WHERE
    gd.Guid = 'b6385fa4-e8cf-4484-a0e3-2a8399505618'
    AND gvd.Guid = 'c3b116df-529c-43d3-855e-c6327e6854b1'
GROUP BY
    gd.Code,
    gvd.Code,
    gvd.DetailPageUri,
    gvd.DefaultSortColumnName,
    gvd.IsDetailWindowed,
    gvd.EntityTypeID;
GO
