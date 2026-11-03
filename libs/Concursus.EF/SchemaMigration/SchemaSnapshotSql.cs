namespace Concursus.EF.SchemaMigration;

/// <summary>
/// Catalog snapshot queries used by Schema Migration compare. tools/SchemaDeployment/SchemaTargetSnapshot.R7D.sql
/// must contain byte-identical copies (enforced by CymBuild.Architecture.Tests); never edit one without the other.
/// </summary>
public static class SchemaSnapshotSql
{
    public const string Schemas = @"
SELECT
    CONVERT(NVARCHAR(50), N'Schema') COLLATE DATABASE_DEFAULT AS ObjectType,
    CONVERT(NVARCHAR(256), s.name) COLLATE DATABASE_DEFAULT AS SchemaName,
    CONVERT(NVARCHAR(256), s.name) COLLATE DATABASE_DEFAULT AS ObjectName,
    CONVERT(NVARCHAR(256), N'') COLLATE DATABASE_DEFAULT AS ParentObjectName,
    CONCAT
    (
        CONVERT(NVARCHAR(MAX), N'CREATE SCHEMA ') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), QUOTENAME(s.name)) COLLATE DATABASE_DEFAULT
    ) COLLATE DATABASE_DEFAULT AS Definition
FROM sys.schemas AS s
WHERE s.name NOT IN (N'guest', N'INFORMATION_SCHEMA', N'sys')
ORDER BY s.name;";

    public const string Tables = @"
SELECT
    CONVERT(NVARCHAR(50), N'Table') COLLATE DATABASE_DEFAULT AS ObjectType,
    CONVERT(NVARCHAR(256), sch.name) COLLATE DATABASE_DEFAULT AS SchemaName,
    CONVERT(NVARCHAR(256), t.name) COLLATE DATABASE_DEFAULT AS ObjectName,
    CONVERT(NVARCHAR(256), N'') COLLATE DATABASE_DEFAULT AS ParentObjectName,
    CONCAT
    (
        CONVERT(NVARCHAR(MAX), N'CYB_TABLE_V2|') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX),
        (
            SELECT
                CONVERT(BIT, t.is_memory_optimized) AS IsMemoryOptimized,
                t.temporal_type_desc AS TemporalType,
                t.durability_desc AS Durability,
                t.lock_escalation_desc AS LockEscalation,
                JSON_QUERY(ISNULL
                (
                    (
                        SELECT
                            c.name AS ColumnName,
                            typeSchema.name AS TypeSchemaName,
                            ty.name AS DataTypeName,
                            CONVERT(BIT, ty.is_user_defined) AS IsUserDefined,
                            c.max_length AS MaxLength,
                            c.precision AS PrecisionValue,
                            c.scale AS ScaleValue,
                            CONVERT(BIT, c.is_nullable) AS IsNullable,
                            c.collation_name AS CollationName,
                            CONVERT(BIT, c.is_ansi_padded) AS IsAnsiPadded,
                            CONVERT(BIT, c.is_rowguidcol) AS IsRowGuidCol,
                            CONVERT(BIT, c.is_identity) AS IsIdentity,
                            CONVERT(NVARCHAR(128), ic.seed_value) AS IdentitySeed,
                            CONVERT(NVARCHAR(128), ic.increment_value) AS IdentityIncrement,
                            CONVERT(BIT, c.is_computed) AS IsComputed,
                            cc.definition AS ComputedDefinition,
                            CONVERT(BIT, cc.is_persisted) AS IsPersisted,
                            CASE
                                WHEN dc.is_system_named = 1 THEN
                                    CASE
                                        WHEN LEN(CONCAT(N'DF_', sch.name, N'_', t.name, N'_', c.name)) <= 128 THEN
                                            CONCAT(N'DF_', sch.name, N'_', t.name, N'_', c.name)
                                        ELSE
                                            CONCAT
                                            (
                                                N'DF_',
                                                LEFT(sch.name, 20),
                                                N'_',
                                                LEFT(t.name, 40),
                                                N'_',
                                                LEFT(c.name, 40),
                                                N'_',
                                                RIGHT
                                                (
                                                    CONVERT
                                                    (
                                                        NVARCHAR(64),
                                                        HASHBYTES
                                                        (
                                                            'SHA2_256',
                                                            CONCAT(sch.name, N'.', t.name, N'.', c.name)
                                                        ),
                                                        2
                                                    ),
                                                    20
                                                )
                                            )
                                    END
                                ELSE dc.name
                            END AS DefaultConstraintName,
                            dc.definition AS DefaultDefinition,
                            CONVERT(BIT, c.is_sparse) AS IsSparse,
                            CONVERT(BIT, c.is_column_set) AS IsColumnSet,
                            CONVERT(BIT, c.is_filestream) AS IsFileStream,
                            c.generated_always_type_desc AS GeneratedAlwaysType,
                            c.encryption_type_desc AS EncryptionType
                        FROM sys.columns AS c
                        INNER JOIN sys.types AS ty
                            ON ty.user_type_id = c.user_type_id
                        INNER JOIN sys.schemas AS typeSchema
                            ON typeSchema.schema_id = ty.schema_id
                        LEFT JOIN sys.identity_columns AS ic
                            ON ic.object_id = c.object_id
                           AND ic.column_id = c.column_id
                        LEFT JOIN sys.computed_columns AS cc
                            ON cc.object_id = c.object_id
                           AND cc.column_id = c.column_id
                        LEFT JOIN sys.default_constraints AS dc
                            ON dc.parent_object_id = c.object_id
                           AND dc.parent_column_id = c.column_id
                        WHERE c.object_id = t.object_id
                        -- Column ordinal is intentionally excluded. CymBuild SQL must use explicit
                        -- column lists, and changing physical ordinal requires a destructive table
                        -- rebuild without changing the logical schema.
                        ORDER BY c.name
                        FOR JSON PATH
                    ),
                    N'[]'
                )) AS Columns
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) COLLATE DATABASE_DEFAULT
    ) COLLATE DATABASE_DEFAULT AS Definition
FROM sys.tables AS t
INNER JOIN sys.schemas AS sch
    ON sch.schema_id = t.schema_id
WHERE t.is_ms_shipped = 0
  AND sch.name NOT IN (N'guest', N'INFORMATION_SCHEMA', N'sys')
ORDER BY sch.name,
         t.name;";

    public const string TableTypes = @"
SELECT
    CONVERT(NVARCHAR(50), N'TableType') COLLATE DATABASE_DEFAULT AS ObjectType,
    CONVERT(NVARCHAR(256), sch.name) COLLATE DATABASE_DEFAULT AS SchemaName,
    CONVERT(NVARCHAR(256), tt.name) COLLATE DATABASE_DEFAULT AS ObjectName,
    CONVERT(NVARCHAR(256), N'') COLLATE DATABASE_DEFAULT AS ParentObjectName,
    CONVERT(NVARCHAR(MAX), ISNULL
    (
        (
            SELECT
                c.column_id AS ColumnId,
                c.name AS ColumnName,
                ty.name AS DataTypeName,
                c.max_length AS MaxLength,
                c.precision AS PrecisionValue,
                c.scale AS ScaleValue,
                c.is_nullable AS IsNullable
            FROM sys.columns AS c
            INNER JOIN sys.types AS ty
                ON ty.user_type_id = c.user_type_id
            WHERE c.object_id = tt.type_table_object_id
            ORDER BY c.column_id
            FOR JSON PATH
        ),
        N'[]'
    )) COLLATE DATABASE_DEFAULT AS Definition
FROM sys.table_types AS tt
INNER JOIN sys.schemas AS sch
    ON sch.schema_id = tt.schema_id
WHERE sch.name NOT IN (N'guest', N'INFORMATION_SCHEMA', N'sys')
ORDER BY sch.name,
         tt.name;";

    public const string Modules = @"
SELECT
    CASE o.type
        WHEN N'V' THEN CONVERT(NVARCHAR(50), N'View') COLLATE DATABASE_DEFAULT
        WHEN N'P' THEN CONVERT(NVARCHAR(50), N'StoredProcedure') COLLATE DATABASE_DEFAULT
        WHEN N'FN' THEN CONVERT(NVARCHAR(50), N'Function') COLLATE DATABASE_DEFAULT
        WHEN N'IF' THEN CONVERT(NVARCHAR(50), N'Function') COLLATE DATABASE_DEFAULT
        WHEN N'TF' THEN CONVERT(NVARCHAR(50), N'Function') COLLATE DATABASE_DEFAULT
        WHEN N'FS' THEN CONVERT(NVARCHAR(50), N'Function') COLLATE DATABASE_DEFAULT
        WHEN N'FT' THEN CONVERT(NVARCHAR(50), N'Function') COLLATE DATABASE_DEFAULT
        WHEN N'TR' THEN CONVERT(NVARCHAR(50), N'Trigger') COLLATE DATABASE_DEFAULT
        ELSE CONVERT(NVARCHAR(50), o.type_desc) COLLATE DATABASE_DEFAULT
    END AS ObjectType,
    CONVERT(NVARCHAR(256), sch.name) COLLATE DATABASE_DEFAULT AS SchemaName,
    CONVERT(NVARCHAR(256), o.name) COLLATE DATABASE_DEFAULT AS ObjectName,
    CASE
        WHEN o.parent_object_id > 0 THEN CONCAT
        (
            CONVERT(NVARCHAR(256), OBJECT_SCHEMA_NAME(o.parent_object_id)) COLLATE DATABASE_DEFAULT,
            CONVERT(NVARCHAR(1), N'.') COLLATE DATABASE_DEFAULT,
            CONVERT(NVARCHAR(256), OBJECT_NAME(o.parent_object_id)) COLLATE DATABASE_DEFAULT
        ) COLLATE DATABASE_DEFAULT
        ELSE CONVERT(NVARCHAR(256), N'') COLLATE DATABASE_DEFAULT
    END AS ParentObjectName,
    CONVERT(NVARCHAR(MAX), ISNULL(m.definition, N'')) COLLATE DATABASE_DEFAULT AS Definition
FROM sys.objects AS o
INNER JOIN sys.schemas AS sch
    ON sch.schema_id = o.schema_id
INNER JOIN sys.sql_modules AS m
    ON m.object_id = o.object_id
WHERE o.is_ms_shipped = 0
  AND o.type IN (N'V', N'P', N'FN', N'IF', N'TF', N'FS', N'FT', N'TR')
  AND sch.name NOT IN (N'guest', N'INFORMATION_SCHEMA', N'sys')
ORDER BY ObjectType,
         sch.name,
         o.name;";

    public const string Sequences = @"
SELECT
    CONVERT(NVARCHAR(50), N'Sequence') COLLATE DATABASE_DEFAULT AS ObjectType,
    CONVERT(NVARCHAR(256), sch.name) COLLATE DATABASE_DEFAULT AS SchemaName,
    CONVERT(NVARCHAR(256), seq.name) COLLATE DATABASE_DEFAULT AS ObjectName,
    CONVERT(NVARCHAR(256), N'') COLLATE DATABASE_DEFAULT AS ParentObjectName,
    CONCAT
    (
        CONVERT(NVARCHAR(MAX), N'TYPE=') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), TYPE_NAME(seq.system_type_id)) COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), N';START=') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), seq.start_value) COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), N';INCREMENT=') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), seq.increment) COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), N';MIN=') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), seq.minimum_value) COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), N';MAX=') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), seq.maximum_value) COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), N';CYCLE=') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), seq.is_cycling) COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), N';CACHE=') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX), seq.cache_size) COLLATE DATABASE_DEFAULT
    ) COLLATE DATABASE_DEFAULT AS Definition
FROM sys.sequences AS seq
INNER JOIN sys.schemas AS sch
    ON sch.schema_id = seq.schema_id
WHERE sch.name NOT IN (N'guest', N'INFORMATION_SCHEMA', N'sys')
ORDER BY sch.name,
         seq.name;";

    public const string KeyConstraints = @"
SELECT
    CONVERT(NVARCHAR(50), N'Constraint') COLLATE DATABASE_DEFAULT AS ObjectType,
    CONVERT(NVARCHAR(256), OBJECT_SCHEMA_NAME(k.parent_object_id)) COLLATE DATABASE_DEFAULT AS SchemaName,
    CONVERT(NVARCHAR(256), k.name) COLLATE DATABASE_DEFAULT AS ObjectName,
    CONVERT(NVARCHAR(256), OBJECT_NAME(k.parent_object_id)) COLLATE DATABASE_DEFAULT AS ParentObjectName,
    CONCAT
    (
        CONVERT(NVARCHAR(MAX), N'CYB_CONSTRAINT_V2|') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX),
        (
            SELECT
                CASE k.type WHEN N'PK' THEN N'PRIMARY_KEY' ELSE N'UNIQUE' END AS ConstraintKind,
                CONVERT(BIT, k.is_system_named) AS IsSystemNamed,
                i.type_desc AS IndexType,
                CONVERT(BIT, i.is_padded) AS IsPadded,
                -- FillFactor 0 (""not specified"") and 100 are functionally identical in SQL Server
                -- (both mean ""no reserved free space""), but a server whose configured default fill
                -- factor is non-zero can only ever persist an explicit FILLFACTOR as its literal
                -- value (100), never as 0 - and SQL Server rejects an explicit FILLFACTOR = 0
                -- outright. Normalize both to 0 here so source (captured as 0) and a deployed target
                -- (persisted as 100) compare as equal instead of failing verification forever.
                CONVERT(INT, CASE WHEN i.fill_factor IN (0, 100) THEN 0 ELSE i.fill_factor END) AS [FillFactor],
                CONVERT(BIT, i.ignore_dup_key) AS IgnoreDuplicateKey,
                CONVERT(BIT, i.allow_row_locks) AS AllowRowLocks,
                CONVERT(BIT, i.allow_page_locks) AS AllowPageLocks,
                CONVERT(BIT, i.is_disabled) AS IsDisabled,
                ISNULL(ds.name, N'') AS DataSpaceName,
                ISNULL(ds.type_desc, N'') AS DataSpaceType,
                JSON_QUERY(ISNULL((
                    SELECT
                        c.name AS ColumnName,
                        ic.key_ordinal AS KeyOrdinal,
                        CONVERT(BIT, ic.is_descending_key) AS IsDescending,
                        ty.name AS DataTypeName,
                        c.max_length AS MaxLength,
                        c.precision AS PrecisionValue,
                        c.scale AS ScaleValue,
                        CONVERT(BIT, c.is_nullable) AS IsNullable
                    FROM sys.index_columns AS ic
                    INNER JOIN sys.columns AS c
                        ON c.object_id = ic.object_id
                       AND c.column_id = ic.column_id
                    INNER JOIN sys.types AS ty
                        ON ty.user_type_id = c.user_type_id
                    WHERE ic.object_id = k.parent_object_id
                      AND ic.index_id = k.unique_index_id
                      AND ic.key_ordinal > 0
                    ORDER BY ic.key_ordinal
                    FOR JSON PATH
                ), N'[]')) AS Columns
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) COLLATE DATABASE_DEFAULT
    ) COLLATE DATABASE_DEFAULT AS Definition
FROM sys.key_constraints AS k
INNER JOIN sys.tables AS parentTable
    ON parentTable.object_id = k.parent_object_id
INNER JOIN sys.indexes AS i
    ON i.object_id = k.parent_object_id
   AND i.index_id = k.unique_index_id
LEFT JOIN sys.data_spaces AS ds
    ON ds.data_space_id = i.data_space_id
WHERE parentTable.is_ms_shipped = 0
  AND OBJECT_SCHEMA_NAME(k.parent_object_id) NOT IN (N'guest', N'INFORMATION_SCHEMA', N'sys')
ORDER BY SchemaName,
         ParentObjectName,
         ObjectName;";

    public const string ForeignKeyConstraints = @"
SELECT
    CONVERT(NVARCHAR(50), N'Constraint') COLLATE DATABASE_DEFAULT AS ObjectType,
    CONVERT(NVARCHAR(256), OBJECT_SCHEMA_NAME(fk.parent_object_id)) COLLATE DATABASE_DEFAULT AS SchemaName,
    CONVERT(NVARCHAR(256), fk.name) COLLATE DATABASE_DEFAULT AS ObjectName,
    CONVERT(NVARCHAR(256), OBJECT_NAME(fk.parent_object_id)) COLLATE DATABASE_DEFAULT AS ParentObjectName,
    CONCAT
    (
        CONVERT(NVARCHAR(MAX), N'CYB_CONSTRAINT_V2|') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX),
        (
            SELECT
                N'FOREIGN_KEY' AS ConstraintKind,
                CONVERT(BIT, fk.is_not_for_replication) AS IsNotForReplication,
                -- FKs to SCore.DataObjects are NOCHECKed by SCore.PreDeploymentScript and
                -- re-enabled WITH CHECK by SCore.PostDeploymentScript, so their enabled state
                -- is lifecycle-owned. Compare snapshots the target between the two; recording
                -- is_disabled here made every such FK a false 'Different' and then failed the
                -- runner drift check once PostDeploymentScript had restored it.
                CONVERT(BIT, CASE WHEN fk.referenced_object_id = OBJECT_ID(N'SCore.DataObjects', N'U') THEN 0 ELSE fk.is_disabled END) AS IsDisabled,
                fk.delete_referential_action_desc AS DeleteAction,
                fk.update_referential_action_desc AS UpdateAction,
                OBJECT_SCHEMA_NAME(fk.referenced_object_id) AS ReferencedSchemaName,
                OBJECT_NAME(fk.referenced_object_id) AS ReferencedTableName,
                JSON_QUERY(ISNULL((
                    SELECT
                        pc.name AS ParentColumn,
                        rc.name AS ReferencedColumn,
                        fkc.constraint_column_id AS ColumnOrder,
                        parentType.name AS ParentDataTypeName,
                        pc.max_length AS ParentMaxLength,
                        pc.precision AS ParentPrecision,
                        pc.scale AS ParentScale,
                        referencedType.name AS ReferencedDataTypeName,
                        rc.max_length AS ReferencedMaxLength,
                        rc.precision AS ReferencedPrecision,
                        rc.scale AS ReferencedScale
                    FROM sys.foreign_key_columns AS fkc
                    INNER JOIN sys.columns AS pc
                        ON pc.object_id = fkc.parent_object_id
                       AND pc.column_id = fkc.parent_column_id
                    INNER JOIN sys.columns AS rc
                        ON rc.object_id = fkc.referenced_object_id
                       AND rc.column_id = fkc.referenced_column_id
                    INNER JOIN sys.types AS parentType
                        ON parentType.user_type_id = pc.user_type_id
                    INNER JOIN sys.types AS referencedType
                        ON referencedType.user_type_id = rc.user_type_id
                    WHERE fkc.constraint_object_id = fk.object_id
                    ORDER BY fkc.constraint_column_id
                    FOR JSON PATH
                ), N'[]')) AS Columns
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) COLLATE DATABASE_DEFAULT
    ) COLLATE DATABASE_DEFAULT AS Definition
FROM sys.foreign_keys AS fk
INNER JOIN sys.tables AS parentTable
    ON parentTable.object_id = fk.parent_object_id
WHERE parentTable.is_ms_shipped = 0
  AND OBJECT_SCHEMA_NAME(fk.parent_object_id) NOT IN (N'guest', N'INFORMATION_SCHEMA', N'sys')
ORDER BY SchemaName,
         ParentObjectName,
         ObjectName;";

    public const string CheckConstraints = @"
SELECT
    CONVERT(NVARCHAR(50), N'Constraint') COLLATE DATABASE_DEFAULT AS ObjectType,
    CONVERT(NVARCHAR(256), OBJECT_SCHEMA_NAME(cc.parent_object_id)) COLLATE DATABASE_DEFAULT AS SchemaName,
    CONVERT(NVARCHAR(256), cc.name) COLLATE DATABASE_DEFAULT AS ObjectName,
    CONVERT(NVARCHAR(256), OBJECT_NAME(cc.parent_object_id)) COLLATE DATABASE_DEFAULT AS ParentObjectName,
    CONCAT
    (
        CONVERT(NVARCHAR(MAX), N'CYB_CONSTRAINT_V2|') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX),
        (
            SELECT
                N'CHECK' AS ConstraintKind,
                ISNULL(COL_NAME(cc.parent_object_id, cc.parent_column_id), N'') AS ParentColumnName,
                ISNULL(cc.definition, N'') AS CheckDefinition,
                CONVERT(BIT, cc.is_not_for_replication) AS IsNotForReplication,
                CONVERT(BIT, cc.is_disabled) AS IsDisabled,
                CONVERT(BIT, cc.uses_database_collation) AS UsesDatabaseCollation,
                JSON_QUERY(ISNULL((
                    SELECT
                        c.name AS ColumnName,
                        ty.name AS DataTypeName,
                        c.max_length AS MaxLength,
                        c.precision AS PrecisionValue,
                        c.scale AS ScaleValue,
                        CONVERT(BIT, c.is_nullable) AS IsNullable
                    FROM sys.columns AS c
                    INNER JOIN sys.types AS ty
                        ON ty.user_type_id = c.user_type_id
                    WHERE c.object_id = cc.parent_object_id
                    ORDER BY c.name
                    FOR JSON PATH
                ), N'[]')) AS ParentTableColumns
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) COLLATE DATABASE_DEFAULT
    ) COLLATE DATABASE_DEFAULT AS Definition
FROM sys.check_constraints AS cc
INNER JOIN sys.tables AS parentTable
    ON parentTable.object_id = cc.parent_object_id
WHERE parentTable.is_ms_shipped = 0
  AND OBJECT_SCHEMA_NAME(cc.parent_object_id) NOT IN (N'guest', N'INFORMATION_SCHEMA', N'sys')
ORDER BY SchemaName,
         ParentObjectName,
         ObjectName;";

    public const string DefaultConstraints = @"
SELECT
    CONVERT(NVARCHAR(50), N'Constraint') COLLATE DATABASE_DEFAULT AS ObjectType,
    CONVERT(NVARCHAR(256), OBJECT_SCHEMA_NAME(dc.parent_object_id)) COLLATE DATABASE_DEFAULT AS SchemaName,
    CONVERT(NVARCHAR(256), defaultIdentity.CanonicalName) COLLATE DATABASE_DEFAULT AS ObjectName,
    CONVERT(NVARCHAR(256), OBJECT_NAME(dc.parent_object_id)) COLLATE DATABASE_DEFAULT AS ParentObjectName,
    CONCAT
    (
        CONVERT(NVARCHAR(MAX), N'CYB_CONSTRAINT_V2|') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX),
        (
            SELECT
                N'DEFAULT' AS ConstraintKind,
                CASE
                    WHEN dc.is_system_named = 1 THEN defaultIdentity.CanonicalName
                    ELSE dc.name
                END AS ConstraintName,
                COL_NAME(dc.parent_object_id, dc.parent_column_id) AS ParentColumnName,
                ISNULL(dc.definition, N'') AS DefaultDefinition,
                ty.name AS ParentDataTypeName,
                c.max_length AS ParentMaxLength,
                c.precision AS ParentPrecision,
                c.scale AS ParentScale,
                CONVERT(BIT, c.is_nullable) AS ParentIsNullable
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) COLLATE DATABASE_DEFAULT
    ) COLLATE DATABASE_DEFAULT AS Definition
FROM sys.default_constraints AS dc
INNER JOIN sys.columns AS c
    ON c.object_id = dc.parent_object_id
   AND c.column_id = dc.parent_column_id
INNER JOIN sys.types AS ty
    ON ty.user_type_id = c.user_type_id
INNER JOIN sys.tables AS parentTable
    ON parentTable.object_id = dc.parent_object_id
INNER JOIN sys.schemas AS sch
    ON sch.schema_id = parentTable.schema_id
CROSS APPLY
(
    SELECT
        CONVERT
        (
            NVARCHAR(128),
            CASE
                WHEN LEN(CONCAT(N'DF_', sch.name, N'_', parentTable.name, N'_', c.name)) <= 128 THEN
                    CONCAT(N'DF_', sch.name, N'_', parentTable.name, N'_', c.name)
                ELSE
                    CONCAT
                    (
                        N'DF_',
                        LEFT(sch.name, 20),
                        N'_',
                        LEFT(parentTable.name, 40),
                        N'_',
                        LEFT(c.name, 40),
                        N'_',
                        RIGHT
                        (
                            CONVERT
                            (
                                NVARCHAR(64),
                                HASHBYTES
                                (
                                    'SHA2_256',
                                    CONCAT(sch.name, N'.', parentTable.name, N'.', c.name)
                                ),
                                2
                            ),
                            20
                        )
                    )
            END
        ) AS CanonicalName
) AS defaultIdentity
WHERE parentTable.is_ms_shipped = 0
  AND sch.name NOT IN (N'guest', N'INFORMATION_SCHEMA', N'sys')
ORDER BY SchemaName,
         ParentObjectName,
         ObjectName;";

    public const string Indexes = @"
SELECT
    CONVERT(NVARCHAR(50), N'Index') COLLATE DATABASE_DEFAULT AS ObjectType,
    CONVERT(NVARCHAR(256), OBJECT_SCHEMA_NAME(i.object_id)) COLLATE DATABASE_DEFAULT AS SchemaName,
    CONCAT
    (
        CONVERT(NVARCHAR(256), OBJECT_NAME(i.object_id)) COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(1), N'.') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(256), i.name) COLLATE DATABASE_DEFAULT
    ) COLLATE DATABASE_DEFAULT AS ObjectName,
    CONVERT(NVARCHAR(256), OBJECT_NAME(i.object_id)) COLLATE DATABASE_DEFAULT AS ParentObjectName,
    CONCAT
    (
        CONVERT(NVARCHAR(MAX), N'CYB_INDEX_V2|') COLLATE DATABASE_DEFAULT,
        CONVERT(NVARCHAR(MAX),
        (
            SELECT
                i.name AS IndexName,
                i.type AS IndexTypeId,
                i.type_desc AS IndexType,
                CONVERT(BIT, i.is_unique) AS IsUnique,
                CONVERT(BIT, i.is_padded) AS IsPadded,
                -- FillFactor 0 (""not specified"") and 100 are functionally identical in SQL Server
                -- (both mean ""no reserved free space""), but a server whose configured default fill
                -- factor is non-zero can only ever persist an explicit FILLFACTOR as its literal
                -- value (100), never as 0 - and SQL Server rejects an explicit FILLFACTOR = 0
                -- outright. Normalize both to 0 here so source (captured as 0) and a deployed target
                -- (persisted as 100) compare as equal instead of failing verification forever.
                CONVERT(INT, CASE WHEN i.fill_factor IN (0, 100) THEN 0 ELSE i.fill_factor END) AS [FillFactor],
                CONVERT(BIT, i.ignore_dup_key) AS IgnoreDuplicateKey,
                CONVERT(BIT, i.allow_row_locks) AS AllowRowLocks,
                CONVERT(BIT, i.allow_page_locks) AS AllowPageLocks,
                CONVERT(BIT, i.is_disabled) AS IsDisabled,
                CONVERT(BIT, i.has_filter) AS HasFilter,
                ISNULL(i.filter_definition, N'') AS FilterDefinition,
                ISNULL(ds.name, N'') AS DataSpaceName,
                ISNULL(ds.type_desc, N'') AS DataSpaceType,
                JSON_QUERY(ISNULL
                (
                    (
                        SELECT
                            c.name AS ColumnName,
                            ic.key_ordinal AS KeyOrdinal,
                            ic.index_column_id AS IndexColumnId,
                            CONVERT(BIT, ic.is_included_column) AS IsIncluded,
                            CONVERT(BIT, ic.is_descending_key) AS IsDescending,
                            ty.name AS DataTypeName,
                            c.max_length AS MaxLength,
                            c.precision AS PrecisionValue,
                            c.scale AS ScaleValue,
                            CONVERT(BIT, c.is_nullable) AS IsNullable
                        FROM sys.index_columns AS ic
                        INNER JOIN sys.columns AS c
                            ON c.object_id = ic.object_id
                           AND c.column_id = ic.column_id
                        INNER JOIN sys.types AS ty
                            ON ty.user_type_id = c.user_type_id
                        WHERE ic.object_id = i.object_id
                          AND ic.index_id = i.index_id
                        ORDER BY ic.index_column_id
                        FOR JSON PATH
                    ),
                    N'[]'
                )) AS Columns,
                JSON_QUERY(ISNULL
                (
                    (
                        SELECT
                            p.partition_number AS PartitionNumber,
                            p.data_compression_desc AS DataCompression
                        FROM sys.partitions AS p
                        WHERE p.object_id = i.object_id
                          AND p.index_id = i.index_id
                        ORDER BY p.partition_number
                        FOR JSON PATH
                    ),
                    N'[]'
                )) AS Partitions
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) COLLATE DATABASE_DEFAULT
    ) COLLATE DATABASE_DEFAULT AS Definition
FROM sys.indexes AS i
INNER JOIN sys.tables AS parentTable
    ON parentTable.object_id = i.object_id
LEFT JOIN sys.data_spaces AS ds
    ON ds.data_space_id = i.data_space_id
WHERE i.index_id > 0
  AND i.is_hypothetical = 0
  AND i.is_primary_key = 0
  AND i.is_unique_constraint = 0
  AND parentTable.is_ms_shipped = 0
  AND OBJECT_SCHEMA_NAME(i.object_id) NOT IN (N'guest', N'INFORMATION_SCHEMA', N'sys')
ORDER BY SchemaName,
         ParentObjectName,
         ObjectName;";
}
