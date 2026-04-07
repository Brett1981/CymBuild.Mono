using Concursus.API.Client.Models;
using Concursus.API.Core;
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.Extensions.Logging;
using System.IO.Compression;
using System.Threading.Channels;
using static Concursus.API.Core.Core;

namespace Concursus.API.Client.Services
{
    public class FileProcessingService
    {
        private readonly ChannelReader<FileModel> _reader;
        private readonly CoreClient _coreClient;
        private HubConnection _hubConnection;
        private readonly NavigationManager _navManager;
        private readonly ILogger<FileProcessingService> _logger;
        private readonly UserService _userService;

        public FileProcessingService(Channel<FileModel> channel, CoreClient coreClient, NavigationManager navManager, ILogger<FileProcessingService> logger, UserService userService)
        {
            _reader = channel.Reader;
            _coreClient = coreClient;
            _navManager = navManager;
            _logger = logger;
            _userService = userService; // Store the UserService instance
        }

        public void SetHubConnectionUrl(string apiUrl)
        {
            Console.WriteLine($"ApiUrl - {apiUrl}");
            _hubConnection = new HubConnectionBuilder()
                .WithUrl($"{apiUrl}/fileProcessingHub")
                .WithAutomaticReconnect()
                .Build();

            _hubConnection.On<string>("FileProcessed", (fileName) =>
            {
                // Notify the user that the file has been processed
                Console.WriteLine($"File {fileName} processing...");
            });

            _hubConnection.Closed += async (error) =>
            {
                Console.WriteLine($"Connection closed due to error: {error?.Message}");
                await Task.Delay(new Random().Next(0, 5) * 1000); // Wait before reconnecting
                await _hubConnection.StartAsync();
            };

            _hubConnection.Reconnected += connectionId =>
            {
                _logger.LogInformation($"Reconnected with connection ID: {connectionId}");
                return Task.CompletedTask;
            };

            _hubConnection.Reconnecting += error =>
            {
                _logger.LogWarning("Reconnecting due to: " + error?.Message);
                return Task.CompletedTask;
            };
        }

        public async Task StartProcessingAsync()
        {
            try
            {
                await _hubConnection.StartAsync();
                _logger.LogInformation("SignalR Hub connection started successfully");
                // Add a log or condition to ensure connection state
                if (_hubConnection.State == HubConnectionState.Connected)
                {
                    _logger.LogInformation("SignalR connection is in Connected state");
                }
                _ = Task.Run(async () => await ProcessFiles());
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error starting SignalR connection");
            }
        }

        public async Task StopProcessingAsync()
        {
            await _hubConnection.StopAsync();
        }

        private async Task ProcessFiles()
        {
            while (await _reader.WaitToReadAsync())
            {
                while (_reader.TryRead(out var file))
                {
                    try
                    {
                        if (file.Content == null || file.Content.Length == 0)
                        {
                            _logger.LogWarning($"File {file.Name} has null or empty content. Skipping processing.");
                            continue;
                        }

                        // Removed compression as this can cause issue with files already compressed
                        // like Images var compressedBytes = CompressByteArray(new List<byte[]> {
                        // fileBytes });
                        using (var memoryStream = new MemoryStream(file.Content)) // Assuming file.Content is already a byte array
                        {
                            await SendToGrpcService(memoryStream, file.Name, file.StorageUrl);
                        }

                        await _hubConnection.InvokeAsync("SendFileProcessed", file.Name, _userService.Email);
                        _logger.LogInformation($"Successfully processed file {file.Name}, for Email: {_userService.Email}, storing at {file.StorageUrl}");
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, $"Error processing file {file.Name}");
                    }
                }
            }
        }

        private byte[] CompressByteArray(List<byte[]> byteArrayList)
        {
            using var memoryStream = new MemoryStream();
            using (var gzip = new GZipStream(memoryStream, CompressionMode.Compress))
            {
                foreach (var byteArray in byteArrayList)
                {
                    gzip.Write(byteArray, 0, byteArray.Length);
                }
            }
            return memoryStream.ToArray();
        }

        private async Task SendToGrpcService(Stream fileStream, string fileName, string storageUrl)
        {
            Console.WriteLine($"Sending file {fileName} to GRPC service at {storageUrl}");

            if (fileStream == null || fileStream.Length == 0)
            {
                throw new ArgumentException("File stream cannot be null or empty.");
            }

            if (string.IsNullOrEmpty(storageUrl))
            {
                throw new ArgumentException("Storage URL cannot be null or empty.");
            }
            // Validate the URI
            if (!Uri.IsWellFormedUriString(storageUrl, UriKind.Absolute))
            {
                throw new UriFormatException($"Invalid URI: {storageUrl}");
            }

            try
            {
                using (var call = _coreClient.UploadFileChunk())
                {
                    int chunkSize = 64 * 1024; // 64KB per chunk
                    byte[] buffer = new byte[chunkSize];
                    int bytesRead;

                    while ((bytesRead = await fileStream.ReadAsync(buffer, 0, buffer.Length)) > 0)
                    {
                        var chunkMsg = new ChunkMsg
                        {
                            FileName = fileName,
                            FileSize = fileStream.Length,
                            StorageUrl = storageUrl,
                            Chunk = Google.Protobuf.ByteString.CopyFrom(buffer, 0, bytesRead)
                        };

                        await call.RequestStream.WriteAsync(chunkMsg);
                    }

                    await call.RequestStream.CompleteAsync();

                    var response = await call.ResponseAsync;

                    if (!response.Success)
                    {
                        throw new Exception($"File upload failed: {response.Message}");
                    }

                    Console.WriteLine($"Successfully uploaded {fileName} to SharePoint at {storageUrl}");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to upload {fileName} to SharePoint: {ex.Message}");
                throw; // Consider re-throwing or handling the exception based on your requirements
            }
        }
    }
}