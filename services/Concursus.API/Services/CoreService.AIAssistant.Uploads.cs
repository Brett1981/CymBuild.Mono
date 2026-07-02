using Concursus.API.Core;
using Concursus.API.Services.AIAssistant;
using Grpc.Core;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Data.SqlClient;
using System.Data;

namespace Concursus.API.Services;

[Authorize]
public partial class CoreService
{
    public override async Task<AIAssistantUploadPresignResponse> AIAssistantUploadPresign(
        AIAssistantUploadPresignRequest request,
        ServerCallContext context)
    {
        var response = new AIAssistantUploadPresignResponse();

        try
        {
            if (_blueGenClient is null)
            {
                response.ErrorReturned = "BlueGen client is not configured.";
                return response;
            }

            if (request.UserId <= 0)
            {
                response.ErrorReturned = "A valid user is required.";
                return response;
            }

            if (string.IsNullOrWhiteSpace(request.FileName))
            {
                response.ErrorReturned = "A file name is required.";
                return response;
            }

            if (string.IsNullOrWhiteSpace(request.ContentType))
            {
                response.ErrorReturned = "A content type is required.";
                return response;
            }

            if (request.FileSizeBytes <= 0)
            {
                response.ErrorReturned = "A valid file size is required.";
                return response;
            }

            var purposeCode = NormaliseAssistantUploadPurpose(request.UploadPurposeCode);
            if (string.IsNullOrWhiteSpace(purposeCode))
            {
                response.ErrorReturned = "A valid upload purpose is required.";
                return response;
            }

            var presign = await _blueGenClient.CreatePresignedUploadUrlAsync(
                request.FileName.Trim(),
                request.ContentType.Trim(),
                context.CancellationToken);

            var uploadGuid = Guid.NewGuid();
            var storageUrl = BuildBlueGenUploadStorageReference(presign);

            await using var cn = await OpenSqlAsync(context.CancellationToken);

            await UpsertAssistantUploadAsync(
                cn,
                uploadGuid,
                request.UserId,
                TryParseGuidOrNullable(request.ConversationGuid),
                TryParseGuidOrNullable(request.KnowledgeItemGuid),
                storageUrl,
                request.FileName.Trim(),
                request.ContentType.Trim(),
                request.FileSizeBytes,
                purposeCode,
                "PENDING_UPLOAD",
                null,
                context.CancellationToken);

            response.UploadGuid = uploadGuid.ToString();
            response.UploadUrl = presign.Url;
            response.StorageUrl = storageUrl;

            foreach (var header in presign.Fields)
            {
                response.UploadHeaders[header.Key] = header.Value;
            }

            return response;
        }
        catch (SqlException ex)
        {
            _serviceBase.logger.LogException(ex, "AIAssistantUploadPresign SQL failed.");
            response.ErrorReturned = $"AI assistant upload presign SQL failed: {ex.Message}";
            return response;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "AIAssistantUploadPresign failed.");
            response.ErrorReturned = $"AI assistant upload presign failed: {ex.Message}";
            return response;
        }
    }

    public override async Task<AIAssistantUploadCompleteResponse> AIAssistantUploadComplete(
        AIAssistantUploadCompleteRequest request,
        ServerCallContext context)
    {
        var response = new AIAssistantUploadCompleteResponse();

        try
        {
            if (request.UserId <= 0)
            {
                response.ErrorReturned = "A valid user is required.";
                return response;
            }

            if (!Guid.TryParse(request.UploadGuid, out var uploadGuid) || uploadGuid == Guid.Empty)
            {
                response.ErrorReturned = "A valid upload Guid is required.";
                return response;
            }

            var purposeCode = NormaliseAssistantUploadPurpose(request.UploadPurposeCode);
            if (string.IsNullOrWhiteSpace(purposeCode))
            {
                response.ErrorReturned = "A valid upload purpose is required.";
                return response;
            }

            var processingStatusCode = string.IsNullOrWhiteSpace(request.ProcessingStatusCode)
                ? "UPLOADED"
                : request.ProcessingStatusCode.Trim().ToUpperInvariant();

            await using var cn = await OpenSqlAsync(context.CancellationToken);

            await UpsertAssistantUploadAsync(
                cn,
                uploadGuid,
                request.UserId,
                TryParseGuidOrNullable(request.ConversationGuid),
                TryParseGuidOrNullable(request.KnowledgeItemGuid),
                request.StorageUrl.Trim(),
                request.FileName.Trim(),
                request.ContentType.Trim(),
                request.FileSizeBytes,
                purposeCode,
                processingStatusCode,
                null,
                context.CancellationToken);

            response.Upload = await ReadAssistantUploadAsync(cn, uploadGuid, context.CancellationToken);

            try
            {
                await InsertAssistantAnalyticsEventAsync(
                    cn,
                    request.UserId,
                    TryParseGuidOrNullable(request.ConversationGuid),
                    "UPLOAD_COMPLETED",
                    request.FileName,
                    null,
                    true,
                    context.CancellationToken);
            }
            catch (Exception ex)
            {
                _serviceBase.logger.LogException(ex, "AI assistant upload analytics insert failed. Upload completion will continue.");
            }

            return response;
        }
        catch (SqlException ex)
        {
            _serviceBase.logger.LogException(ex, "AIAssistantUploadComplete SQL failed.");
            response.ErrorReturned = $"AI assistant upload complete SQL failed: {ex.Message}";
            return response;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "AIAssistantUploadComplete failed.");
            response.ErrorReturned = $"AI assistant upload complete failed: {ex.Message}";
            return response;
        }
    }

    public override async Task<AIAssistantUploadListResponse> AIAssistantUploadList(
        AIAssistantUploadListRequest request,
        ServerCallContext context)
    {
        var response = new AIAssistantUploadListResponse();

        try
        {
            if (request.UserId <= 0)
            {
                response.ErrorReturned = "A valid user is required.";
                return response;
            }

            await using var cn = await OpenSqlAsync(context.CancellationToken);
            await using var cmd = new SqlCommand(@"
SELECT
    root_hobt.Guid,
    root_hobt.UserId,
    root_hobt.ConversationGuid,
    root_hobt.KnowledgeItemGuid,
    root_hobt.StorageUrl,
    root_hobt.FileName,
    root_hobt.ContentType,
    root_hobt.FileSizeBytes,
    root_hobt.UploadPurposeCode,
    root_hobt.ProcessingStatusCode,
    root_hobt.VisionSummary,
    root_hobt.CreatedUtc
FROM SAi.tvf_AssistantUploadListByUser(@UserId) AS root_hobt
ORDER BY root_hobt.CreatedUtc DESC;", cn)
            {
                CommandType = CommandType.Text,
                CommandTimeout = 120
            };

            cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = request.UserId });

            await using var reader = await cmd.ExecuteReaderAsync(context.CancellationToken);
            while (await reader.ReadAsync(context.CancellationToken))
            {
                response.Uploads.Add(MapAssistantUpload(reader));
            }

            return response;
        }
        catch (SqlException ex)
        {
            _serviceBase.logger.LogException(ex, "AIAssistantUploadList SQL failed.");
            response.ErrorReturned = $"AI assistant upload list SQL failed: {ex.Message}";
            return response;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "AIAssistantUploadList failed.");
            response.ErrorReturned = $"AI assistant upload list failed: {ex.Message}";
            return response;
        }
    }

    private async Task UpsertAssistantUploadAsync(
        SqlConnection cn,
        Guid uploadGuid,
        int userId,
        Guid? conversationGuid,
        Guid? knowledgeItemGuid,
        string storageUrl,
        string fileName,
        string contentType,
        long fileSizeBytes,
        string uploadPurposeCode,
        string processingStatusCode,
        string? visionSummary,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand("SAi.AssistantUploadCreate", cn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 120
        };

        cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = userId });
        cmd.Parameters.Add(new SqlParameter("@ConversationGuid", SqlDbType.UniqueIdentifier) { Value = conversationGuid.HasValue ? conversationGuid.Value : DBNull.Value });
        cmd.Parameters.Add(new SqlParameter("@KnowledgeItemGuid", SqlDbType.UniqueIdentifier) { Value = knowledgeItemGuid.HasValue ? knowledgeItemGuid.Value : DBNull.Value });
        cmd.Parameters.Add(new SqlParameter("@StorageUrl", SqlDbType.NVarChar, 1000) { Value = storageUrl });
        cmd.Parameters.Add(new SqlParameter("@FileName", SqlDbType.NVarChar, 500) { Value = fileName });
        cmd.Parameters.Add(new SqlParameter("@ContentType", SqlDbType.NVarChar, 200) { Value = contentType });
        cmd.Parameters.Add(new SqlParameter("@FileSizeBytes", SqlDbType.BigInt) { Value = fileSizeBytes });
        cmd.Parameters.Add(new SqlParameter("@UploadPurposeCode", SqlDbType.NVarChar, 30) { Value = uploadPurposeCode });
        cmd.Parameters.Add(new SqlParameter("@ProcessingStatusCode", SqlDbType.NVarChar, 30) { Value = processingStatusCode });
        cmd.Parameters.Add(new SqlParameter("@VisionSummary", SqlDbType.NVarChar, -1) { Value = DbValue(visionSummary) });

        var guidParameter = new SqlParameter("@Guid", SqlDbType.UniqueIdentifier)
        {
            Direction = ParameterDirection.InputOutput,
            Value = uploadGuid
        };
        cmd.Parameters.Add(guidParameter);

        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    private async Task<AIAssistantUpload> ReadAssistantUploadAsync(
        SqlConnection cn,
        Guid uploadGuid,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(@"
SELECT
    u.Guid,
    u.UserId,
    CONVERT(NVARCHAR(36), c.Guid) AS ConversationGuid,
    CONVERT(NVARCHAR(36), ki.Guid) AS KnowledgeItemGuid,
    u.StorageUrl,
    u.FileName,
    u.ContentType,
    u.FileSizeBytes,
    u.UploadPurposeCode,
    u.ProcessingStatusCode,
    u.VisionSummary,
    u.CreatedUtc
FROM SAi.AssistantUploads AS u
LEFT JOIN SAi.AssistantConversations AS c ON c.ID = u.ConversationId
LEFT JOIN SAi.AssistantKnowledgeItems AS ki ON ki.ID = u.KnowledgeItemId
WHERE u.Guid = @UploadGuid
  AND u.RowStatus NOT IN (0, 254)
  AND (c.ID IS NULL OR c.RowStatus NOT IN (0, 254))
  AND (ki.ID IS NULL OR ki.RowStatus NOT IN (0, 254));", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 120
        };

        cmd.Parameters.Add(new SqlParameter("@UploadGuid", SqlDbType.UniqueIdentifier) { Value = uploadGuid });

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            throw new InvalidOperationException("AI assistant upload was saved but could not be reloaded.");
        }

        return MapAssistantUpload(reader);
    }

    private static AIAssistantUpload MapAssistantUpload(SqlDataReader reader)
    {
        return new AIAssistantUpload
        {
            Guid = Convert.ToString(reader["Guid"]) ?? string.Empty,
            UserId = Convert.ToInt32(reader["UserId"]),
            ConversationGuid = Convert.ToString(reader["ConversationGuid"]) ?? string.Empty,
            KnowledgeItemGuid = Convert.ToString(reader["KnowledgeItemGuid"]) ?? string.Empty,
            StorageUrl = Convert.ToString(reader["StorageUrl"]) ?? string.Empty,
            FileName = Convert.ToString(reader["FileName"]) ?? string.Empty,
            ContentType = Convert.ToString(reader["ContentType"]) ?? string.Empty,
            FileSizeBytes = Convert.ToInt64(reader["FileSizeBytes"]),
            UploadPurposeCode = Convert.ToString(reader["UploadPurposeCode"]) ?? string.Empty,
            ProcessingStatusCode = Convert.ToString(reader["ProcessingStatusCode"]) ?? string.Empty,
            VisionSummary = Convert.ToString(reader["VisionSummary"]) ?? string.Empty,
            CreatedUtc = FormatUtc(reader["CreatedUtc"])
        };
    }

    private static string NormaliseAssistantUploadPurpose(string? uploadPurposeCode)
    {
        if (string.Equals(uploadPurposeCode, "SCREENSHOT", StringComparison.OrdinalIgnoreCase))
        {
            return "SCREENSHOT";
        }

        if (string.Equals(uploadPurposeCode, "KNOWLEDGE", StringComparison.OrdinalIgnoreCase))
        {
            return "KNOWLEDGE";
        }

        if (string.Equals(uploadPurposeCode, "ATTACHMENT", StringComparison.OrdinalIgnoreCase))
        {
            return "ATTACHMENT";
        }

        return string.Empty;
    }

    private static Guid? TryParseGuidOrNullable(string? value)
    {
        return Guid.TryParse(value, out var guid) && guid != Guid.Empty
            ? guid
            : null;
    }

    private const string BlueGenFolderStoragePrefix = "bluegen-folder:";

    private static string BuildBlueGenUploadStorageReference(BlueGenPresignedUrlResult presign)
    {
        if (!string.IsNullOrWhiteSpace(presign.Folder))
        {
            return BlueGenFolderStoragePrefix + Uri.EscapeDataString(presign.Folder.Trim());
        }

        if (!string.IsNullOrWhiteSpace(presign.FileUrl))
        {
            return presign.FileUrl.Trim();
        }

        return presign.Url.Trim();
    }

    private static string ExtractBlueGenFolderFromStorageReference(string storageReference)
    {
        if (string.IsNullOrWhiteSpace(storageReference)
            || !storageReference.StartsWith(BlueGenFolderStoragePrefix, StringComparison.OrdinalIgnoreCase))
        {
            return string.Empty;
        }

        var encodedFolder = storageReference[BlueGenFolderStoragePrefix.Length..];

        return string.IsNullOrWhiteSpace(encodedFolder)
            ? string.Empty
            : Uri.UnescapeDataString(encodedFolder);
    }

    private static string ExtractBlueGenFileUrlFromStorageReference(string storageReference)
    {
        if (string.IsNullOrWhiteSpace(storageReference)
            || storageReference.StartsWith(BlueGenFolderStoragePrefix, StringComparison.OrdinalIgnoreCase))
        {
            return string.Empty;
        }

        return storageReference.Trim();
    }
    private async Task<IReadOnlyList<BlueGenFileReference>> ReadBlueGenFileReferencesAsync(
        SqlConnection cn,
        int userId,
        IEnumerable<string> uploadGuids,
        CancellationToken cancellationToken)
    {
        var parsedUploadGuids = uploadGuids
            .Where(value => Guid.TryParse(value, out _))
            .Select(Guid.Parse)
            .Distinct()
            .ToList();

        if (parsedUploadGuids.Count == 0)
        {
            return Array.Empty<BlueGenFileReference>();
        }

        var parameters = new List<string>();
        await using var cmd = cn.CreateCommand();
        cmd.CommandType = CommandType.Text;
        cmd.CommandTimeout = 120;

        cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = userId });

        for (var index = 0; index < parsedUploadGuids.Count; index++)
        {
            var parameterName = $"@UploadGuid{index}";
            parameters.Add(parameterName);
            cmd.Parameters.Add(new SqlParameter(parameterName, SqlDbType.UniqueIdentifier) { Value = parsedUploadGuids[index] });
        }

        cmd.CommandText = $@"
SELECT
    u.StorageUrl,
    u.FileName,
    u.ContentType
FROM SAi.AssistantUploads AS u
WHERE u.UserId = @UserId
  AND u.Guid IN ({string.Join(", ", parameters)})
  AND u.RowStatus NOT IN (0, 254)
  AND u.ProcessingStatusCode IN (N'UPLOADED', N'EXTRACTED', N'PUBLISHED');";

        var files = new List<BlueGenFileReference>();
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            var storageUrl = Convert.ToString(reader["StorageUrl"]) ?? string.Empty;

            files.Add(new BlueGenFileReference
            {
                Url = ExtractBlueGenFileUrlFromStorageReference(storageUrl),
                FileName = Convert.ToString(reader["FileName"]) ?? string.Empty,
                ContentType = Convert.ToString(reader["ContentType"]) ?? string.Empty,
                Folder = ExtractBlueGenFolderFromStorageReference(storageUrl)
            });
        }

        return files;
    }
}
