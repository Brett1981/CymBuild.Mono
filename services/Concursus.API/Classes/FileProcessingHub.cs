using Microsoft.AspNetCore.SignalR;

namespace Concursus.API.Classes
{
    public class FileProcessingHub : Hub
    {
        private static Dictionary<string, string> userConnections = new Dictionary<string, string>();

        public Task RegisterConnectionId(string connectionId, string email)
        {
            userConnections[email] = connectionId;
            Console.WriteLine($"Registered ConnectionId: {connectionId} for Email: {email}");
            return Task.CompletedTask;
        }

        public async Task SendFileProcessed(string fileName, string email)
        {
            if (userConnections.TryGetValue(email, out var connectionId))
            {
                Console.WriteLine($"Sending file processed message to ConnectionId: {connectionId} for Email: {email}");
                await Clients.Client(connectionId).SendAsync("FileProcessed", fileName);
            }
            else
            {
                Console.WriteLine($"ConnectionId not found for Email: {email}");
            }
        }

        public async Task SendFileAllProcessed(string Information)
        {
            await Clients.All.SendAsync("InformationProcessed", Information);
        }

        public async Task NotifySyncQueueUpdated(string userEmail)
        {
            if (userConnections.TryGetValue(userEmail, out var connectionId))
            {
                await Clients.Client(connectionId).SendAsync("SyncQueueUpdated");
                Console.WriteLine($"🔔 Sent SyncQueueUpdated to {connectionId} ({userEmail})");
            }
            else
            {
                Console.WriteLine($"⚠️ No connection ID found for {userEmail}");
            }
        }
    }
}