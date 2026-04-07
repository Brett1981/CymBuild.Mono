using Concursus.API.Services;
using Microsoft.Graph;
using Microsoft.Graph.Models;

namespace Concursus.API.Interfaces
{
    public interface ISharepointService
    {
        SharepointDirectory GetFoldersForFireStructuralBuildingInJobs();
        SharepointDirectory GetFoldersForFireStructuralBuildingInQuotes();
        SharepointDirectory GetFoldersForFireStructuralBuildingInEnquiry();

        Task EnsureFolderStructureExists(
            GraphServiceClient graphServiceClient,
            string siteId,
            string baseUrl,
            List<string> folderNames,
            Drive drive,
            DriveItem driveItem,
            string jobNumber,
            string QuoteNo = "",
            string QuoteURL = "",
            bool isEnquiry = false,
            Dictionary<string, List<string>>? subFoldersToCreate = null);
    }
}