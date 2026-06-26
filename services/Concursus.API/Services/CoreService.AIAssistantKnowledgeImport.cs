using Concursus.API.Core;
using Concursus.API.Services.AIAssistant;
using Grpc.Core;
using Microsoft.AspNetCore.Authorization;
using System.Text.Json;

namespace Concursus.API.Services;

[Authorize]
public partial class CoreService
{
    public override async Task<AIAssistantKnowledgeImportRunResponse> AIAssistantKnowledgeImportRun(
        AIAssistantKnowledgeImportRunRequest request,
        ServerCallContext context)
    {
        var response = new AIAssistantKnowledgeImportRunResponse();

        try
        {
            if (request.UserId <= 0)
            {
                response.ErrorReturned = "A valid user is required.";
                return response;
            }

            var importer = context.GetHttpContext().RequestServices.GetRequiredService<IAIAssistantSharePointKnowledgeImporter>();
            var result = await importer.ImportTrainingMaterialAsync(
                request.UserId,
                request.PublishImmediately,
                request.Authoritative,
                context.CancellationToken);

            response.FilesFound = result.FilesFound;
            response.FilesSkipped = result.FilesSkipped;
            response.ItemsUpserted = result.ItemsUpserted;
            response.Failures = result.Failures;

            foreach (var entry in result.Log)
            {
                response.Log.Add(new AIAssistantKnowledgeImportLogEntryMessage
                {
                    Level = entry.Level,
                    FileName = entry.FileName,
                    Message = entry.Message,
                    KnowledgeItemGuid = entry.KnowledgeItemGuid
                });
            }

            await InsertAssistantAnalyticsEventSafeAsync(
                request.UserId,
                "KNOWLEDGE_IMPORT_MANUAL_RUN",
                JsonSerializer.Serialize(new
                {
                    result.FilesFound,
                    result.FilesSkipped,
                    result.ItemsUpserted,
                    result.Failures
                }),
                result.Failures == 0,
                context.CancellationToken);

            return response;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "AIAssistantKnowledgeImportRun failed.");
            response.ErrorReturned = $"AI assistant knowledge import failed: {ex.Message}";
            return response;
        }
    }

    private async Task InsertAssistantAnalyticsEventSafeAsync(
        int userId,
        string eventTypeCode,
        string payloadJson,
        bool successFlag,
        CancellationToken cancellationToken)
    {
        try
        {
            await using var cn = await OpenSqlAsync(cancellationToken);
            await InsertAssistantAnalyticsEventAsync(
                cn,
                userId,
                null,
                eventTypeCode,
                null,
                payloadJson,
                successFlag,
                cancellationToken);
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "Failed to save AI Assistant knowledge import analytics event.");
        }
    }
}
