using Concursus.API.Core;
using Grpc.Core;
using Microsoft.Data.SqlClient;
using System.Data;

namespace Concursus.API.Services;

public partial class CoreService
{
    public override async Task<DeveloperInspectorResult> DeveloperInspectorGet(DeveloperInspectorRequest request, ServerCallContext context)
    {
        var environmentType = (_config["Environment:Type"] ?? string.Empty).Trim();
        var response = new DeveloperInspectorResult
        {
            EnvironmentType = environmentType,
            ComponentName = request.ComponentName ?? string.Empty,
            Route = request.Route ?? string.Empty,
            IsEnabled = IsDeveloperInspectorEnvironment(environmentType)
        };

        if (!response.IsEnabled)
        {
            response.IsSuccess = false;
            response.Message = "Developer Inspector is disabled outside DEV/QA/TEST environments.";
            return response;
        }

        if (!Guid.TryParse(request.EntityPropertyGuid, out var entityPropertyGuid) || entityPropertyGuid == Guid.Empty)
        {
            response.IsSuccess = false;
            response.Message = "A valid EntityPropertyGuid is required.";
            return response;
        }

        await using var cn = await OpenSqlAsync(context.CancellationToken).ConfigureAwait(false);
        await using var cmd = cn.CreateCommand();
        cmd.CommandType = CommandType.Text;
        cmd.CommandTimeout = 30;
        cmd.CommandText = DeveloperInspectorSql;
        cmd.Parameters.Add(new SqlParameter("@EntityPropertyGuid", SqlDbType.UniqueIdentifier) { Value = entityPropertyGuid });
        cmd.Parameters.Add(new SqlParameter("@RecordGuid", SqlDbType.UniqueIdentifier)
        {
            Value = Guid.TryParse(request.RecordGuid, out var recordGuid) ? recordGuid : Guid.Empty
        });

        await using var reader = await cmd.ExecuteReaderAsync(context.CancellationToken).ConfigureAwait(false);

        if (!await reader.ReadAsync(context.CancellationToken).ConfigureAwait(false))
        {
            response.IsSuccess = false;
            response.Message = "No active EntityProperty metadata was found for this field.";
            return response;
        }

        response.Field = new DeveloperInspectorFieldInfo
        {
            Label = FirstNonEmpty(request.Label, GetString(reader, "Label"), GetString(reader, "PropertyName")),
            PropertyName = FirstNonEmpty(request.PropertyName, GetString(reader, "PropertyName")),
            EntityPropertyGuid = GetGuidString(reader, "EntityPropertyGuid"),
            EntityTypeGuid = GetGuidString(reader, "EntityTypeGuid"),
            EntityTypeName = GetString(reader, "EntityTypeName"),
            RecordGuid = request.RecordGuid ?? string.Empty,
            DataTypeName = GetString(reader, "EntityDataTypeName"),
            IsCompulsory = GetBool(reader, "IsCompulsory"),
            IsReadOnly = GetBool(reader, "IsReadOnly"),
            IsHidden = GetBool(reader, "IsHidden"),
            IsVirtual = GetBool(reader, "IsVirtual"),
            MaxLength = GetInt(reader, "PropertyMaxLength"),
            Precision = GetInt(reader, "PropertyPrecision"),
            Scale = GetInt(reader, "PropertyScale"),
            CurrentValuePreview = request.CurrentValuePreview ?? string.Empty,
            FieldState = request.FieldState ?? string.Empty
        };

        var schemaName = GetString(reader, "SchemaName");
        var objectName = GetString(reader, "ObjectName");
        var columnName = GetString(reader, "ColumnName");
        response.Sql = new DeveloperInspectorSqlInfo
        {
            SchemaName = schemaName,
            ObjectName = objectName,
            ColumnName = columnName,
            FullName = string.IsNullOrWhiteSpace(schemaName) || string.IsNullOrWhiteSpace(objectName) || string.IsNullOrWhiteSpace(columnName)
                ? string.Empty
                : $"{schemaName}.{objectName}.{columnName}",
            SqlType = GetString(reader, "SqlType"),
            MaxLength = GetInt(reader, "SqlMaxLength"),
            Precision = GetInt(reader, "SqlPrecision"),
            Scale = GetInt(reader, "SqlScale"),
            IsNullable = GetBool(reader, "IsNullable"),
            ColumnFound = GetBool(reader, "ColumnFound"),
            Source = GetString(reader, "SqlSource")
        };

        response.Metadata = new DeveloperInspectorMetadataInfo
        {
            EntityHobtGuid = GetGuidString(reader, "EntityHoBTGuid"),
            EntityHobtName = string.IsNullOrWhiteSpace(schemaName) || string.IsNullOrWhiteSpace(objectName) ? string.Empty : $"{schemaName}.{objectName}",
            EntityPropertyGroupName = GetString(reader, "EntityPropertyGroupName"),
            DropDownListDefinitionGuid = GetGuidString(reader, "DropDownListDefinitionGuid"),
            DropDownListDefinitionName = GetString(reader, "DropDownListDefinitionName"),
            DropDownListSql = GetString(reader, "DropDownListSql"),
            DetailPageUri = GetString(reader, "DetailPageUri"),
            InformationPageUri = GetString(reader, "InformationPageUri"),
            ExternalSearchPageUrl = GetString(reader, "ExternalSearchPageUrl"),
            HelpText = GetString(reader, "HelpText")
        };

        response.Workflow = new DeveloperInspectorWorkflowInfo
        {
            DataObjectFound = GetBool(reader, "DataObjectFound"),
            DataObjectGuid = GetGuidString(reader, "DataObjectGuid"),
            DataObjectRowStatus = GetInt(reader, "DataObjectRowStatus"),
            CurrentStatusGuid = GetGuidString(reader, "CurrentStatusGuid"),
            CurrentStatusName = GetString(reader, "CurrentStatusName"),
            CurrentTransitionOnUtc = GetString(reader, "CurrentTransitionOnUtc")
        };

        response.IsSuccess = true;
        response.Message = "OK";
        return response;
    }

    private static bool IsDeveloperInspectorEnvironment(string environmentType)
    {
        return environmentType.Equals("DEV", StringComparison.OrdinalIgnoreCase)
            || environmentType.Equals("QA", StringComparison.OrdinalIgnoreCase)
            || environmentType.Equals("TEST", StringComparison.OrdinalIgnoreCase)
            || environmentType.Equals("UAT", StringComparison.OrdinalIgnoreCase);
    }

    private const string DeveloperInspectorSql = @"
SELECT TOP (1)
       ep.Guid AS EntityPropertyGuid,
       ep.Name AS PropertyName,
       COALESCE(NULLIF(ll.Name, N''), ep.Name) AS Label,
       et.Guid AS EntityTypeGuid,
       et.Name AS EntityTypeName,
       edt.Name AS EntityDataTypeName,
       ep.IsCompulsory,
       ep.IsReadOnly,
       ep.IsHidden,
       ep.IsVirtual,
       ep.MaxLength AS PropertyMaxLength,
       ep.Precision AS PropertyPrecision,
       ep.Scale AS PropertyScale,
       eh.Guid AS EntityHoBTGuid,
       eh.SchemaName,
       eh.ObjectName,
       epg.Name AS EntityPropertyGroupName,
       ddl.Guid AS DropDownListDefinitionGuid,
       ddl.Code AS DropDownListDefinitionName,
       ddl.SqlQuery AS DropDownListSql,
       ddl.DetailPageUrl AS DetailPageUri,
       ddl.InformationPageUrl AS InformationPageUri,
       ddl.ExternalSearchPageUrl AS ExternalSearchPageUrl,
       CONVERT(NVARCHAR(MAX), N'') AS HelpText,
       c.name AS ColumnName,
       typ.name AS SqlType,
       CONVERT(INT, CASE WHEN typ.name IN (N'nchar', N'nvarchar') AND c.max_length > 0 THEN c.max_length / 2 ELSE c.max_length END) AS SqlMaxLength,
       CONVERT(INT, c.precision) AS SqlPrecision,
       CONVERT(INT, c.scale) AS SqlScale,
       CONVERT(BIT, ISNULL(c.is_nullable, 0)) AS IsNullable,
       CONVERT(BIT, CASE WHEN c.object_id IS NULL THEN 0 ELSE 1 END) AS ColumnFound,
       CASE WHEN c.object_id IS NULL THEN N'Metadata only / virtual / computed query alias' ELSE N'sys.columns' END AS SqlSource,
       CONVERT(BIT, CASE WHEN dob.Guid IS NULL THEN 0 ELSE 1 END) AS DataObjectFound,
       dob.Guid AS DataObjectGuid,
       CONVERT(INT, ISNULL(dob.RowStatus, 0)) AS DataObjectRowStatus,
       ws.Guid AS CurrentStatusGuid,
       ws.Name AS CurrentStatusName,
       CONVERT(NVARCHAR(33), dot.DateTimeUTC, 126) AS CurrentTransitionOnUtc
FROM SCore.EntityProperties AS ep
JOIN SCore.EntityHobts AS eh
  ON eh.ID = ep.EntityHoBTID
 AND eh.RowStatus NOT IN (0,254)
JOIN SCore.EntityTypes AS et
  ON et.ID = eh.EntityTypeID
 AND et.RowStatus NOT IN (0,254)
JOIN SCore.EntityDataTypes AS edt
  ON edt.ID = ep.EntityDataTypeID
 AND edt.RowStatus NOT IN (0,254)
LEFT JOIN SCore.LanguageLabels AS ll
  ON ll.ID = ep.LanguageLabelID
 AND ll.RowStatus NOT IN (0,254)
LEFT JOIN SCore.EntityPropertyGroups AS epg
  ON epg.ID = ep.EntityPropertyGroupID
 AND epg.RowStatus NOT IN (0,254)
LEFT JOIN SUserInterface.DropDownListDefinitions AS ddl
  ON ddl.ID = ep.DropDownListDefinitionID
 AND ddl.RowStatus NOT IN (0,254)
LEFT JOIN sys.schemas AS sch
  ON sch.name = eh.SchemaName
LEFT JOIN sys.objects AS obj
  ON obj.schema_id = sch.schema_id
 AND obj.name = eh.ObjectName
LEFT JOIN sys.columns AS c
  ON c.object_id = obj.object_id
 AND c.name = ep.Name
LEFT JOIN sys.types AS typ
  ON typ.user_type_id = c.user_type_id
LEFT JOIN SCore.DataObjects AS dob
  ON dob.Guid = @RecordGuid
 AND dob.RowStatus NOT IN (0,254)
LEFT JOIN SCore.DataObjectTransition AS dot
  ON dot.ID =
     (
       SELECT TOP (1) dot2.ID
       FROM SCore.DataObjectTransition AS dot2
       WHERE dot2.DataObjectGuid = @RecordGuid
         AND dot2.RowStatus NOT IN (0,254)
       ORDER BY dot2.ID DESC
     )
LEFT JOIN SCore.WorkflowStatus AS ws
  ON ws.ID = dot.StatusID
 AND ws.RowStatus NOT IN (0,254)
WHERE ep.Guid = @EntityPropertyGuid
  AND ep.RowStatus NOT IN (0,254);
";

    private static string FirstNonEmpty(params string?[] values)
    {
        foreach (var value in values)
        {
            if (!string.IsNullOrWhiteSpace(value))
            {
                return value;
            }
        }

        return string.Empty;
    }

    private static string GetString(SqlDataReader reader, string name)
    {
        var ordinal = reader.GetOrdinal(name);
        return reader.IsDBNull(ordinal) ? string.Empty : Convert.ToString(reader.GetValue(ordinal)) ?? string.Empty;
    }

    private static string GetGuidString(SqlDataReader reader, string name)
    {
        var value = GetString(reader, name);
        return Guid.TryParse(value, out var guid) ? guid.ToString() : string.Empty;
    }

    private static int GetInt(SqlDataReader reader, string name)
    {
        var ordinal = reader.GetOrdinal(name);
        return reader.IsDBNull(ordinal) ? 0 : Convert.ToInt32(reader.GetValue(ordinal));
    }

    private static bool GetBool(SqlDataReader reader, string name)
    {
        var ordinal = reader.GetOrdinal(name);
        return !reader.IsDBNull(ordinal) && Convert.ToBoolean(reader.GetValue(ordinal));
    }
}
