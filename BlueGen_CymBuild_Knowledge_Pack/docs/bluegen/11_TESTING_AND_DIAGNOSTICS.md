# Testing and Diagnostics

This file provides safe diagnostic patterns. Treat these as templates and adapt object/table names only after checking schema.

## Check DataObject for a record

```sql
DECLARE @RecordGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';

SELECT
    do.ID,
    do.Guid,
    do.EntityTypeId,
    et.Name AS EntityTypeName,
    do.RowStatus
FROM SCore.DataObjects AS do
LEFT JOIN SCore.EntityTypes AS et
    ON et.ID = do.EntityTypeId
WHERE do.Guid = @RecordGuid
  AND do.RowStatus NOT IN (0, 254);
```

## Check latest workflow/status transition

```sql
DECLARE @DataObjectGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';

SELECT TOP (1)
    dot.ID,
    dot.DataObjectGuid,
    dot.StatusID,
    ws.Name AS StatusName,
    dot.CreatedDate,
    dot.RowStatus
FROM SCore.DataObjectTransition AS dot
LEFT JOIN SCore.WorkflowStatus AS ws
    ON ws.ID = dot.StatusID
WHERE dot.DataObjectGuid = @DataObjectGuid
  AND dot.RowStatus NOT IN (0, 254)
ORDER BY dot.CreatedDate DESC, dot.ID DESC;
```

## Check transition history

```sql
DECLARE @DataObjectGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';

SELECT
    dot.ID,
    dot.StatusID,
    ws.Name AS StatusName,
    dot.CreatedDate,
    dot.RowStatus
FROM SCore.DataObjectTransition AS dot
LEFT JOIN SCore.WorkflowStatus AS ws
    ON ws.ID = dot.StatusID
WHERE dot.DataObjectGuid = @DataObjectGuid
ORDER BY dot.CreatedDate DESC, dot.ID DESC;
```

## Check integration outbox

```sql
DECLARE @RecordGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';

SELECT
    io.ID,
    io.Guid,
    io.RowStatus,
    io.CreatedDate,
    io.*
FROM SCore.IntegrationOutbox AS io
WHERE io.RowStatus NOT IN (0, 254)
  AND CONVERT(NVARCHAR(MAX), io.Payload) LIKE '%' + CONVERT(NVARCHAR(36), @RecordGuid) + '%'
ORDER BY io.ID DESC;
```

## Check classifications

```sql
SELECT
    dc.ID,
    dc.Guid,
    dc.Name,
    dc.RowStatus
FROM SCore.DataClassifications AS dc
WHERE dc.RowStatus NOT IN (0, 254)
ORDER BY dc.Name;

SELECT
    sc.ID,
    sc.Guid,
    sc.Name,
    sc.RowStatus
FROM SCore.SecurityClassifications AS sc
WHERE sc.RowStatus NOT IN (0, 254)
ORDER BY sc.Name;
```

## Check grid metadata by name

```sql
DECLARE @GridName NVARCHAR(255) = N'Grid Name Here';

SELECT
    gd.ID,
    gd.Guid,
    gd.Name,
    gd.RowStatus
FROM SUserInterface.GridDefinitions AS gd
WHERE gd.Name = @GridName
  AND gd.RowStatus NOT IN (0, 254);
```

## Check grid columns

```sql
DECLARE @GridViewDefinitionGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';

SELECT
    gvcd.ID,
    gvcd.Guid,
    gvcd.Name,
    gvcd.SortOrder,
    gvcd.RowStatus
FROM SUserInterface.GridViewColumnDefinitions AS gvcd
WHERE gvcd.GridViewDefinitionGuid = @GridViewDefinitionGuid
  AND gvcd.RowStatus NOT IN (0, 254)
ORDER BY gvcd.SortOrder, gvcd.ID;
```

## BlueGen diagnostic rule

Prefer read-only diagnostics first. Only provide remediation SQL when the root cause is confirmed and the script is idempotent, non-destructive, and environment-appropriate.
