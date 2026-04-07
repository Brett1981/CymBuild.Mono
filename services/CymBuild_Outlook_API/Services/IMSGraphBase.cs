// ==============================
// FILE: CymBuild_Outlook_API/Services/IMSGraphBase.cs
// ==============================
using Microsoft.Graph;

namespace CymBuild_Outlook_API.Services
{
    public interface IMSGraphBase
    {
        GraphServiceClient GetGraphClient(string? correlationId = null);
    }

}
