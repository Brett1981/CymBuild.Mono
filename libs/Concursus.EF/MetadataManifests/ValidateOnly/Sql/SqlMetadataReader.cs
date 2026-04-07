using Microsoft.Data.SqlClient;
using System.Data;

namespace Concursus.EF.MetadataManifests.ValidateOnly.Sql;

/// <summary>
/// Read-only SQL helper for ValidateOnly.
/// - Uses ADO.NET directly to avoid coupling to EF.
/// - All connections/commands are disposed deterministically.
/// </summary>
public sealed class SqlMetadataReader
{
    private readonly string _connectionString;

    public SqlMetadataReader(string connectionString)
    {
        _connectionString = connectionString;
    }

    public async Task<GridDefinitionRow?> GetGridDefinitionByGuidAsync(Guid guid, CancellationToken ct)
    {
        const string sql = @"
SELECT TOP (1)
    gd.ID,
    gd.Guid,
    gd.RowStatus,
    gd.Code,
    gd.PageUri,
    gd.TabName,
    gd.ShowAsTiles,
    gd.LanguageLabelId
FROM SUserInterface.GridDefinitions gd
WHERE gd.Guid = @Guid;";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(ct).ConfigureAwait(false);

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.Add(new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = guid });

        await using var rdr = await cmd.ExecuteReaderAsync(CommandBehavior.SingleRow, ct).ConfigureAwait(false);
        if (!await rdr.ReadAsync(ct).ConfigureAwait(false))
            return null;

        return new GridDefinitionRow
        {
            Id = rdr.GetInt32(rdr.GetOrdinal("ID")),
            Guid = rdr.GetGuid(rdr.GetOrdinal("Guid")),
            RowStatus = rdr.GetByte(rdr.GetOrdinal("RowStatus")),
            Code = rdr.GetString(rdr.GetOrdinal("Code")),
            PageUri = rdr.IsDBNull(rdr.GetOrdinal("PageUri")) ? null : rdr.GetString(rdr.GetOrdinal("PageUri")),
            TabName = rdr.IsDBNull(rdr.GetOrdinal("TabName")) ? null : rdr.GetString(rdr.GetOrdinal("TabName")),
            ShowAsTiles = rdr.GetBoolean(rdr.GetOrdinal("ShowAsTiles")),
            LanguageLabelId = rdr.IsDBNull(rdr.GetOrdinal("LanguageLabelId")) ? (int?)null : rdr.GetInt32(rdr.GetOrdinal("LanguageLabelId"))
        };
    }

    public async Task<List<GridViewDefinitionRow>> GetGridViewsByGridDefinitionIdAsync(int gridDefinitionId, CancellationToken ct)
    {
        const string sql = @"
SELECT
    gvd.ID,
    gvd.Guid,
    gvd.RowStatus,
    gvd.Code,
    gvd.DetailPageUri,
    gvd.SqlQuery,
    gvd.DefaultSortColumnName,
    gvd.IsDefaultSortDescending,
    gvd.SecurableCode,
    gvd.DisplayOrder,
    gvd.DisplayGroupName,
    gvd.ShowOnMobile,
    gvd.ShowOnDashboard,
    gvd.AllowNew,
    gvd.AllowExcelExport,
    gvd.AllowPdfExport,
    gvd.AllowCsvExport,
    gvd.AllowBulkChange,
    gvd.IsDetailWindowed,

    gvd.EntityTypeID,
    gvd.GridViewTypeId,
    gvd.DrawerIconId,
    gvd.LanguageLabelId,
    gvd.MetricTypeID
FROM SUserInterface.GridViewDefinitions gvd
WHERE gvd.GridDefinitionId = @GridDefinitionId;";

        var rows = new List<GridViewDefinitionRow>();

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(ct).ConfigureAwait(false);

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.Add(new SqlParameter("@GridDefinitionId", SqlDbType.Int) { Value = gridDefinitionId });

        await using var rdr = await cmd.ExecuteReaderAsync(ct).ConfigureAwait(false);
        while (await rdr.ReadAsync(ct).ConfigureAwait(false))
        {
            rows.Add(new GridViewDefinitionRow
            {
                Id = rdr.GetInt32(rdr.GetOrdinal("ID")),
                Guid = rdr.GetGuid(rdr.GetOrdinal("Guid")),
                RowStatus = rdr.GetByte(rdr.GetOrdinal("RowStatus")),
                Code = rdr.GetString(rdr.GetOrdinal("Code")),

                DetailPageUri = rdr.IsDBNull(rdr.GetOrdinal("DetailPageUri")) ? null : rdr.GetString(rdr.GetOrdinal("DetailPageUri")),
                SqlQuery = rdr.IsDBNull(rdr.GetOrdinal("SqlQuery")) ? null : rdr.GetString(rdr.GetOrdinal("SqlQuery")),
                DefaultSortColumnName = rdr.IsDBNull(rdr.GetOrdinal("DefaultSortColumnName")) ? null : rdr.GetString(rdr.GetOrdinal("DefaultSortColumnName")),
                IsDefaultSortDescending = rdr.GetBoolean(rdr.GetOrdinal("IsDefaultSortDescending")),
                SecurableCode = rdr.IsDBNull(rdr.GetOrdinal("SecurableCode")) ? null : rdr.GetString(rdr.GetOrdinal("SecurableCode")),
                DisplayOrder = rdr.GetInt32(rdr.GetOrdinal("DisplayOrder")),
                DisplayGroupName = rdr.IsDBNull(rdr.GetOrdinal("DisplayGroupName")) ? null : rdr.GetString(rdr.GetOrdinal("DisplayGroupName")),
                ShowOnMobile = rdr.GetBoolean(rdr.GetOrdinal("ShowOnMobile")),
                ShowOnDashboard = rdr.GetBoolean(rdr.GetOrdinal("ShowOnDashboard")),
                AllowNew = rdr.GetBoolean(rdr.GetOrdinal("AllowNew")),
                AllowExcelExport = rdr.GetBoolean(rdr.GetOrdinal("AllowExcelExport")),
                AllowPdfExport = rdr.GetBoolean(rdr.GetOrdinal("AllowPdfExport")),
                AllowCsvExport = rdr.GetBoolean(rdr.GetOrdinal("AllowCsvExport")),
                AllowBulkChange = rdr.GetBoolean(rdr.GetOrdinal("AllowBulkChange")),
                IsDetailWindowed = rdr.GetBoolean(rdr.GetOrdinal("IsDetailWindowed")),

                EntityTypeId = rdr.GetInt32(rdr.GetOrdinal("EntityTypeID")),
                GridViewTypeId = rdr.GetInt32(rdr.GetOrdinal("GridViewTypeId")),
                DrawerIconId = rdr.IsDBNull(rdr.GetOrdinal("DrawerIconId")) ? (int?)null : rdr.GetInt32(rdr.GetOrdinal("DrawerIconId")),
                LanguageLabelId = rdr.IsDBNull(rdr.GetOrdinal("LanguageLabelId")) ? (int?)null : rdr.GetInt32(rdr.GetOrdinal("LanguageLabelId")),
                MetricTypeId = rdr.IsDBNull(rdr.GetOrdinal("MetricTypeID")) ? (int?)null : rdr.GetInt32(rdr.GetOrdinal("MetricTypeID")),
            });
        }

        return rows;
    }

    public async Task<Dictionary<Guid, int>> ResolveLanguageLabelIdsByGuidAsync(IEnumerable<Guid> guids, CancellationToken ct)
    {
        var list = guids.Distinct().ToList();
        if (list.Count == 0) return new Dictionary<Guid, int>();

        var paramNames = list.Select((_, i) => $"@g{i}").ToList();

        var sql = $@"
SELECT ll.Guid, ll.ID
FROM SCore.LanguageLabels ll
WHERE ll.Guid IN ({string.Join(",", paramNames)});";

        var map = new Dictionary<Guid, int>();

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(ct).ConfigureAwait(false);

        await using var cmd = new SqlCommand(sql, con);
        for (var i = 0; i < list.Count; i++)
            cmd.Parameters.Add(new SqlParameter(paramNames[i], SqlDbType.UniqueIdentifier) { Value = list[i] });

        await using var rdr = await cmd.ExecuteReaderAsync(ct).ConfigureAwait(false);
        while (await rdr.ReadAsync(ct).ConfigureAwait(false))
        {
            var g = rdr.GetGuid(0);
            var id = rdr.GetInt32(1);
            map[g] = id;
        }

        return map;
    }

    // ---------------------------------------------------------------------
    // Stage 2 – Task 2.3 prerequisites (ValidateOnly):
    // - SCore.EntityQueries: Guid -> ID (int)
    // - SUserInterface.WidgetTypes: Guid -> Id (smallint)
    // ---------------------------------------------------------------------

    public async Task<Dictionary<Guid, int>> ResolveEntityQueryIdsByGuidAsync(IEnumerable<Guid> guids, CancellationToken ct)
    {
        var list = guids.Distinct().ToList();
        if (list.Count == 0) return new Dictionary<Guid, int>();

        var paramNames = list.Select((_, i) => $"@g{i}").ToList();
        var sql = $@"
SELECT eq.Guid, eq.ID
FROM SCore.EntityQueries eq
WHERE eq.Guid IN ({string.Join(",", paramNames)});";

        var map = new Dictionary<Guid, int>();

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(ct).ConfigureAwait(false);

        await using var cmd = new SqlCommand(sql, con);
        for (var i = 0; i < list.Count; i++)
            cmd.Parameters.Add(new SqlParameter(paramNames[i], SqlDbType.UniqueIdentifier) { Value = list[i] });

        await using var rdr = await cmd.ExecuteReaderAsync(ct).ConfigureAwait(false);
        while (await rdr.ReadAsync(ct).ConfigureAwait(false))
        {
            var g = rdr.GetGuid(0);
            var id = rdr.GetInt32(1);
            map[g] = id;
        }

        return map;
    }

    public async Task<Dictionary<Guid, short>> ResolveWidgetTypeIdsByGuidAsync(IEnumerable<Guid> guids, CancellationToken ct)
    {
        var list = guids.Distinct().ToList();
        if (list.Count == 0) return new Dictionary<Guid, short>();

        var paramNames = list.Select((_, i) => $"@g{i}").ToList();
        var sql = $@"
SELECT wt.Guid, wt.Id
FROM SUserInterface.WidgetTypes wt
WHERE wt.Guid IN ({string.Join(",", paramNames)});";

        var map = new Dictionary<Guid, short>();

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(ct).ConfigureAwait(false);

        await using var cmd = new SqlCommand(sql, con);
        for (var i = 0; i < list.Count; i++)
            cmd.Parameters.Add(new SqlParameter(paramNames[i], SqlDbType.UniqueIdentifier) { Value = list[i] });

        await using var rdr = await cmd.ExecuteReaderAsync(ct).ConfigureAwait(false);
        while (await rdr.ReadAsync(ct).ConfigureAwait(false))
        {
            var g = rdr.GetGuid(0);
            var id = rdr.GetInt16(1); // smallint
            map[g] = id;
        }

        return map;
    }

    // =====================================================================
    // Stage 2 – Task 2.1 (counts) - unchanged
    // =====================================================================

    public Task<Dictionary<Guid, int>> GetGridViewColumnCountsByGridDefinitionIdAsync(int gridDefinitionId, CancellationToken ct)
    {
        const string sql = @"
SELECT
    gvd.Guid AS GridViewGuid,
    COUNT(1) AS Cnt
FROM SUserInterface.GridViewColumnDefinitions c
JOIN SUserInterface.GridViewDefinitions gvd
    ON gvd.ID = c.GridViewDefinitionId
WHERE gvd.GridDefinitionId = @GridDefinitionId
  AND gvd.RowStatus NOT IN (0,254)
  AND c.RowStatus NOT IN (0,254)
GROUP BY gvd.Guid;";

        return ReadCountsByViewGuidAsync(sql, gridDefinitionId, ct);
    }

    public Task<Dictionary<Guid, int>> GetGridViewActionCountsByGridDefinitionIdAsync(int gridDefinitionId, CancellationToken ct)
    {
        const string sql = @"
SELECT
    gvd.Guid AS GridViewGuid,
    COUNT(1) AS Cnt
FROM SUserInterface.GridViewActions a
JOIN SUserInterface.GridViewDefinitions gvd
    ON gvd.ID = a.GridViewDefinitionId
WHERE gvd.GridDefinitionId = @GridDefinitionId
  AND gvd.RowStatus NOT IN (0,254)
  AND a.RowStatus NOT IN (0,254)
GROUP BY gvd.Guid;";

        return ReadCountsByViewGuidAsync(sql, gridDefinitionId, ct);
    }

    public Task<Dictionary<Guid, int>> GetGridViewWidgetCountsByGridDefinitionIdAsync(int gridDefinitionId, CancellationToken ct)
    {
        const string sql = @"
SELECT
    gvd.Guid AS GridViewGuid,
    COUNT(1) AS Cnt
FROM SUserInterface.GridViewWidgetQueries w
JOIN SUserInterface.GridViewDefinitions gvd
    ON gvd.ID = w.GridViewDefinitionId
WHERE gvd.GridDefinitionId = @GridDefinitionId
  AND gvd.RowStatus NOT IN (0,254)
  AND w.RowStatus NOT IN (0,254)
GROUP BY gvd.Guid;";

        return ReadCountsByViewGuidAsync(sql, gridDefinitionId, ct);
    }

    private async Task<Dictionary<Guid, int>> ReadCountsByViewGuidAsync(string sql, int gridDefinitionId, CancellationToken ct)
    {
        var map = new Dictionary<Guid, int>();

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(ct).ConfigureAwait(false);

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.Add(new SqlParameter("@GridDefinitionId", SqlDbType.Int) { Value = gridDefinitionId });

        await using var rdr = await cmd.ExecuteReaderAsync(ct).ConfigureAwait(false);
        while (await rdr.ReadAsync(ct).ConfigureAwait(false))
        {
            var viewGuid = rdr.GetGuid(rdr.GetOrdinal("GridViewGuid"));
            var cnt = rdr.GetInt32(rdr.GetOrdinal("Cnt"));
            map[viewGuid] = cnt;
        }

        return map;
    }

    // =====================================================================
    // Stage 2 – Task 2.3 (ValidateOnly): load internals per GridViewDefinition
    // - Filters RowStatus NOT IN (0,254) for child rows only
    // - Parent view RowStatus filtering is already enforced when views are loaded
    // =====================================================================

    public async Task<List<GridViewColumnRow>> GetGridViewColumnsByViewIdAsync(int gridViewDefinitionId, CancellationToken ct)
    {
        const string sql = @"
SELECT
    c.Guid,
    c.RowStatus,
    c.Name,
    c.ColumnOrder,
    c.IsPrimaryKey,
    c.IsHidden,
    c.IsFiltered,
    c.DisplayFormat,
    c.Width,
    c.TopHeaderCategory,
    c.TopHeaderCategoryOrder,
    c.LanguageLabelId
FROM SUserInterface.GridViewColumnDefinitions c
WHERE c.GridViewDefinitionId = @ViewId
  AND c.RowStatus NOT IN (0,254);";

        var rows = new List<GridViewColumnRow>();

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(ct).ConfigureAwait(false);

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.Add(new SqlParameter("@ViewId", SqlDbType.Int) { Value = gridViewDefinitionId });

        await using var rdr = await cmd.ExecuteReaderAsync(ct).ConfigureAwait(false);
        while (await rdr.ReadAsync(ct).ConfigureAwait(false))
        {
            rows.Add(new GridViewColumnRow
            {
                Guid = rdr.GetGuid(0),
                RowStatus = rdr.GetByte(1),
                Name = rdr.GetString(2),
                ColumnOrder = rdr.GetInt32(3),
                IsPrimaryKey = rdr.GetBoolean(4),
                IsHidden = rdr.GetBoolean(5),
                IsFiltered = rdr.GetBoolean(6),
                DisplayFormat = rdr.GetString(7),
                Width = rdr.GetString(8),
                TopHeaderCategory = rdr.GetString(9),
                TopHeaderCategoryOrder = rdr.GetInt32(10),
                LanguageLabelId = rdr.GetInt32(11)
            });
        }

        return rows;
    }

    public async Task<List<GridViewActionRow>> GetGridViewActionsByViewIdAsync(int gridViewDefinitionId, CancellationToken ct)
    {
        const string sql = @"
SELECT
    a.Guid,
    a.RowStatus,
    a.LanguageLabelId,
    a.EntityQueryId
FROM SUserInterface.GridViewActions a
WHERE a.GridViewDefinitionId = @ViewId
  AND a.RowStatus NOT IN (0,254);";

        var rows = new List<GridViewActionRow>();

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(ct).ConfigureAwait(false);

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.Add(new SqlParameter("@ViewId", SqlDbType.Int) { Value = gridViewDefinitionId });

        await using var rdr = await cmd.ExecuteReaderAsync(ct).ConfigureAwait(false);
        while (await rdr.ReadAsync(ct).ConfigureAwait(false))
        {
            rows.Add(new GridViewActionRow
            {
                Guid = rdr.GetGuid(0),
                RowStatus = rdr.GetByte(1),
                LanguageLabelId = rdr.GetInt32(2),
                EntityQueryId = rdr.GetInt32(3)
            });
        }

        return rows;
    }

    public async Task<List<GridViewWidgetRow>> GetGridViewWidgetsByViewIdAsync(int gridViewDefinitionId, CancellationToken ct)
    {
        // NOTE: DB column is LanguageLabelID (capital D) but we project as LanguageLabelId.
        const string sql = @"
SELECT
    w.Guid,
    w.RowStatus,
    w.EntityQueryId,
    w.WidgetTypeId,
    w.LanguageLabelID
FROM SUserInterface.GridViewWidgetQueries w
WHERE w.GridViewDefinitionId = @ViewId
  AND w.RowStatus NOT IN (0,254);";

        var rows = new List<GridViewWidgetRow>();

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(ct).ConfigureAwait(false);

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.Add(new SqlParameter("@ViewId", SqlDbType.Int) { Value = gridViewDefinitionId });

        await using var rdr = await cmd.ExecuteReaderAsync(ct).ConfigureAwait(false);
        while (await rdr.ReadAsync(ct).ConfigureAwait(false))
        {
            rows.Add(new GridViewWidgetRow
            {
                Guid = rdr.GetGuid(0),
                RowStatus = rdr.GetByte(1),
                EntityQueryId = rdr.GetInt32(2),
                WidgetTypeId = rdr.GetInt16(3),
                LanguageLabelId = rdr.GetInt32(4)
            });
        }

        return rows;
    }
}

/// <summary>Projection of the columns we validate for GridDefinitions.</summary>
public sealed class GridDefinitionRow
{
    public int Id { get; set; }
    public Guid Guid { get; set; }
    public byte RowStatus { get; set; }
    public string Code { get; set; } = string.Empty;
    public string? PageUri { get; set; }
    public string? TabName { get; set; }
    public bool ShowAsTiles { get; set; }
    public int? LanguageLabelId { get; set; }
}

/// <summary>Projection of the columns we validate for GridViewDefinitions.</summary>
public sealed class GridViewDefinitionRow
{
    public int Id { get; set; }
    public Guid Guid { get; set; }
    public byte RowStatus { get; set; }
    public string Code { get; set; } = string.Empty;

    public string? DetailPageUri { get; set; }
    public string? SqlQuery { get; set; }
    public string? DefaultSortColumnName { get; set; }
    public bool IsDefaultSortDescending { get; set; }
    public string? SecurableCode { get; set; }
    public int DisplayOrder { get; set; }
    public string? DisplayGroupName { get; set; }
    public bool ShowOnMobile { get; set; }
    public bool ShowOnDashboard { get; set; }

    public bool AllowNew { get; set; }
    public bool AllowExcelExport { get; set; }
    public bool AllowPdfExport { get; set; }
    public bool AllowCsvExport { get; set; }
    public bool AllowBulkChange { get; set; }

    public bool IsDetailWindowed { get; set; }

    public int EntityTypeId { get; set; }
    public int GridViewTypeId { get; set; }
    public int? DrawerIconId { get; set; }
    public int? LanguageLabelId { get; set; }
    public int? MetricTypeId { get; set; }
}

/// <summary>DB row projection for SUserInterface.GridViewColumnDefinitions.</summary>
public sealed class GridViewColumnRow
{
    public Guid Guid { get; set; }
    public byte RowStatus { get; set; }
    public string Name { get; set; } = string.Empty;
    public int ColumnOrder { get; set; }
    public bool IsPrimaryKey { get; set; }
    public bool IsHidden { get; set; }
    public bool IsFiltered { get; set; }
    public string DisplayFormat { get; set; } = string.Empty;
    public string Width { get; set; } = string.Empty;
    public string TopHeaderCategory { get; set; } = string.Empty;
    public int TopHeaderCategoryOrder { get; set; }
    public int LanguageLabelId { get; set; }
}

/// <summary>DB row projection for SUserInterface.GridViewActions.</summary>
public sealed class GridViewActionRow
{
    public Guid Guid { get; set; }
    public byte RowStatus { get; set; }
    public int LanguageLabelId { get; set; }
    public int EntityQueryId { get; set; }
}

/// <summary>DB row projection for SUserInterface.GridViewWidgetQueries.</summary>
public sealed class GridViewWidgetRow
{
    public Guid Guid { get; set; }
    public byte RowStatus { get; set; }
    public int EntityQueryId { get; set; }
    public short WidgetTypeId { get; set; }
    public int LanguageLabelId { get; set; }
}
