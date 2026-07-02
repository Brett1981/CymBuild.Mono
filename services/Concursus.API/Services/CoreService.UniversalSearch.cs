using Concursus.API.Core;
using Grpc.Core;

namespace Concursus.API.Services;

public partial class CoreService
{
    public override async Task<UniversalSearchReply> UniversalSearch(
        UniversalSearchRequest request,
        ServerCallContext context)
    {
        var response = new UniversalSearchReply();

        try
        {
            var searchText = (request.SearchText ?? string.Empty).Trim();
            if (searchText.Length == 0)
            {
                response.IsSuccess = true;
                response.Message = "Enter at least one search character.";
                return response;
            }

            var rows = await _serviceBase._entityFramework
                .UniversalSearchAsync(
                    searchText,
                    request.ModuleFilters.ToArray(),
                    request.Take,
                    request.UserId,
                    context.CancellationToken)
                .ConfigureAwait(false);

            foreach (var row in rows)
            {
                response.Results.Add(new UniversalSearchRow
                {
                    ModuleKey = row.ModuleKey,
                    ModuleDisplayName = row.ModuleDisplayName,
                    RecordGuid = row.RecordGuid.ToString(),
                    EntityTypeGuid = row.EntityTypeGuid.ToString(),
                    EntityTypeName = row.EntityTypeName,
                    DetailPageUri = row.DetailPageUri,
                    PrimaryText = row.PrimaryText,
                    SecondaryText = row.SecondaryText,
                    TertiaryText = row.TertiaryText,
                    SearchRank = row.SearchRank
                });
            }

            response.IsSuccess = true;
            response.Message = rows.Count == 0 ? "No matching records found." : "OK";
            return response;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "UniversalSearch failed.");
            response.IsSuccess = false;
            response.Message = ex.Message;
            return response;
        }
    }
}
