using Concursus.API.DMS;
using Concursus.Common.Shared;
using Concursus.Common.Shared.Data;
using Concursus.Common.Shared.Extensions;
using Google.Protobuf;
using Google.Protobuf.WellKnownTypes;
using Grpc.Core;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Data.SqlClient;
using Newtonsoft.Json;
using System.Data;
using System.Dynamic;
using static Concursus.Common.Shared.Enums;
using Enum = System.Enum;
using FileInfo = Concursus.Common.Shared.Data.FileInfo;

namespace Concursus.API.Services;

[Authorize]
public class DmsService : Dms.DmsBase
{
    #region Private Fields

    private readonly IConfiguration _config;
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly string _serverBaseLocation;
    private readonly ServiceBase _serviceBase;

    #endregion Private Fields

    #region Public Constructors

    public DmsService(ILogger<DmsService> logger, IConfiguration config, IHttpContextAccessor httpContextAccessor)
    {
        _config = config;
        _serviceBase = new ServiceBase(config, httpContextAccessor, new Logging(logger, config));

        _httpContextAccessor = httpContextAccessor;

        _serverBaseLocation = _config.GetValue<string>("ServerBaseLoc") ?? "";
    }

    #endregion Public Constructors

    #region Public Methods

    [Authorize(Roles = "User.ReadWrite")]
    public override async Task<CopyDmsEntryResponse> CopyDmsEntry(CopyDmsEntryRequest copyDmsEntryRequest, ServerCallContext context)
    {
        CopyDmsEntryResponse copyDmsEntryResponse = new();
        var connection = _serviceBase._entityFramework.CreateConnection();

        try
        {
            await _serviceBase._entityFramework.OpenConnectionAsync(connection);

            if (copyDmsEntryRequest.FileManagerEntry.Extension == ".shore")
            {
                await connection.ExecuteInTransaction(async transaction =>
                {
                    var reportId = 0;
                    var reportName = "";

                    // Step 1: Retrieve the report details
                    var getReportStatement = @"
                SELECT Id, Name
                FROM SCore.Reports
                WHERE RootFolderId = @RootFolderId
                  AND VirtualPath + CASE WHEN VirtualPath <> N'' THEN N'\' ELSE N'' END + Name + N'.shore' = @VirtualPath
                  AND RowStatus = @RowStatus";

                    await using (var command = connection.CreateCommandWithParameters(
                               getReportStatement, CommandType.Text,
                               new SqlParameter("@RootFolderId", (int)Enum.Parse(typeof(RootFolder), copyDmsEntryRequest.FileManagerEntry.RootFolder)),
                               new SqlParameter("@VirtualPath", copyDmsEntryRequest.FileManagerEntry.Path),
                               new SqlParameter("@RowStatus", (int)Enums.RowStatus.Active)))
                    {
                        command.Transaction = transaction;

                        await using var reader = await command.ExecuteReaderAsync();
                        if (reader.Read())
                        {
                            reportId = reader.GetIntSafe("Id");
                            reportName = reader.GetStringOrNull("Name");
                        }
                    }

                    // Step 2: Copy the report
                    var copyReportStatement = @"
                EXECUTE SCore.ReportCopy
                    @ReportId = @ReportId,
                    @NewName = @NewName,
                    @VirtualPath = @VirtualPath,
                    @NewReportId = @NewReportId OUT";

                    var newReportId = new SqlParameter("@NewReportId", 0) { Direction = ParameterDirection.Output };

                    await using (var command = connection.CreateCommandWithParameters(
                               copyReportStatement, CommandType.Text,
                               new SqlParameter("@ReportId", reportId),
                               new SqlParameter("@NewName", reportName),
                               new SqlParameter("@VirtualPath", copyDmsEntryRequest.Target),
                               newReportId))
                    {
                        command.Transaction = transaction;
                        await command.ExecuteNonQueryAsync();
                    }

                    // Step 3: Retrieve the new report details
                    var getReportByIdStatement = @"
                SELECT Id, Name, CreatedDateTimeUtc, ModifiedDateTimeUtc
                FROM SCore.Reports
                WHERE Id = @Id";

                    await using (var command = connection.CreateCommandWithParameters(
                               getReportByIdStatement, CommandType.Text,
                               new SqlParameter("@Id", newReportId.Value)))
                    {
                        command.Transaction = transaction;

                        await using var reader = await command.ExecuteReaderAsync();
                        if (reader.Read())
                        {
                            var fileManagerEntry = new FileManagerEntry
                            {
                                Extension = ".shore",
                                Name = reader.GetStringOrNull("Name"),
                                Path = $"{copyDmsEntryRequest.Target}\\{reader.GetStringOrNull("Name")}.shore",
                                Created = Timestamp.FromDateTime(reader.GetDateTimeOrNull("CreatedDateTimeUtc")?.ToUniversalTime() ?? DateTime.UtcNow),
                                CreatedUtc = Timestamp.FromDateTime(reader.GetDateTimeOrNull("CreatedDateTimeUtc")?.ToUniversalTime() ?? DateTime.UtcNow),
                                IsDirectory = false,
                                HasDirectories = false,
                                Modified = Timestamp.FromDateTime(reader.GetDateTimeOrNull("ModifiedDateTimeUtc")?.ToUniversalTime() ?? DateTime.UtcNow),
                                ModifiedUtc = Timestamp.FromDateTime(reader.GetDateTimeOrNull("ModifiedDateTimeUtc")?.ToUniversalTime() ?? DateTime.UtcNow)
                            };

                            copyDmsEntryResponse.FileManagerEntry = fileManagerEntry;
                        }
                    }
                });
            }
            else
            {
                // Handle non-shore file case
                FilePath filePath = new()
                {
                    IsDirectory = copyDmsEntryRequest.FileManagerEntry.IsDirectory,
                    RootFolder = (RootFolder)Enum.Parse(typeof(RootFolder), copyDmsEntryRequest.FileManagerEntry.RootFolder),
                    RecordId = copyDmsEntryRequest.FileManagerEntry.RecordId,
                    VirtualPath = copyDmsEntryRequest.FileManagerEntry.Path.Replace(
                        copyDmsEntryRequest.FileManagerEntry.Name + copyDmsEntryRequest.FileManagerEntry.Extension, ""),
                    ServerBaseLocation = _serverBaseLocation,
                    FileName = copyDmsEntryRequest.FileManagerEntry.Name,
                    Extension = copyDmsEntryRequest.FileManagerEntry.Extension
                };

                var copiedFile = Storage.CopyDmsEntry(filePath, copyDmsEntryRequest.Target);
                copyDmsEntryResponse.FileManagerEntry = TypeHelpers.GetFileManagerEntryFromFileInfo(copiedFile);
            }
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
        }
        finally
        {
            // Ensure the connection is always closed
            if (connection.State != System.Data.ConnectionState.Closed)
            {
                connection.Close();
            }
            connection.Dispose();
        }

        _serviceBase.logger.LogInformation("DMS Entry Copied: " + JsonConvert.SerializeObject(copyDmsEntryResponse));
        return copyDmsEntryResponse;
    }

    [Authorize(Roles = "User.ReadWrite")]
    public override Task<CreateDirectoryResponse> CreateDirectory(CreateDirectoryRequest createDirectoryRequest,
        ServerCallContext context)
    {
        CreateDirectoryResponse createDirectoryResponse = new();

        var newDirectory = Storage.CreateDirectory(new FilePath
        {
            RootFolder = (RootFolder)System.Enum.Parse(typeof(RootFolder), createDirectoryRequest.RootFolder),
            RecordId = createDirectoryRequest.RecordId,
            VirtualPath = Path.Combine(createDirectoryRequest.Path, createDirectoryRequest.Name),
            ServerBaseLocation = _serverBaseLocation
        });

        createDirectoryResponse.NewDirectory = TypeHelpers.GetFileManagerEntryFromFileInfo(newDirectory);

        _serviceBase.logger.LogInformation("DMS Directory Created: " +
                                           JsonConvert.SerializeObject(createDirectoryRequest));

        return Task.FromResult(createDirectoryResponse);
    }

    [Authorize(Roles = "User.ReadWrite")]
    public override async Task<DeleteDmsEntryResponse> DeleteDmsEntry(DeleteDmsEntryRequest deleteDmsEntryRequest, ServerCallContext context)
    {
        DeleteDmsEntryResponse deleteDmsEntryResponse = new();
        var connection = _serviceBase._entityFramework.CreateConnection();

        try
        {
            await _serviceBase._entityFramework.OpenConnectionAsync(connection);

            if (deleteDmsEntryRequest.FileManagerEntry.Path.EndsWith(".shore"))
            {
                await connection.ExecuteInTransaction(async transaction =>
                {
                    var statement = @"
                    UPDATE SCore.Reports
                    SET ModifiedDateTimeUtc = GetUTCDate(),
                        RowStatus = @DeletedStatus
                    WHERE FolderId = @FolderId
                      AND RootFolderId = @RootFolderId
                      AND RowStatus = @ActiveStatus
                      AND Name = @Name
                      AND VirtualPath = @VirtualPath";

                    var strippedPath = deleteDmsEntryRequest.FileManagerEntry.Path.Substring(
                        0, deleteDmsEntryRequest.FileManagerEntry.Path.LastIndexOf("\\"));

                    await using var command = connection.CreateCommandWithParameters(
                        statement, CommandType.Text,
                        new SqlParameter("@FolderId", deleteDmsEntryRequest.FileManagerEntry.RecordId),
                        new SqlParameter("@Name", deleteDmsEntryRequest.FileManagerEntry.Name),
                        new SqlParameter("@VirtualPath", strippedPath),
                        new SqlParameter("@RootFolderId", (int)Enum.Parse(typeof(RootFolder), deleteDmsEntryRequest.FileManagerEntry.RootFolder)),
                        new SqlParameter("@ActiveStatus", (int)Enums.RowStatus.Active),
                        new SqlParameter("@DeletedStatus", (int)Enums.RowStatus.Deleted)
                    );

                    command.Transaction = transaction;
                    await command.ExecuteNonQueryAsync();
                });

                deleteDmsEntryResponse.Success = true;
            }
            else
            {
                FilePath filePath = new()
                {
                    IsDirectory = deleteDmsEntryRequest.FileManagerEntry.IsDirectory,
                    RootFolder = (RootFolder)Enum.Parse(typeof(RootFolder), deleteDmsEntryRequest.FileManagerEntry.RootFolder),
                    RecordId = deleteDmsEntryRequest.FileManagerEntry.RecordId,
                    VirtualPath = deleteDmsEntryRequest.FileManagerEntry.Path,
                    ServerBaseLocation = _serverBaseLocation,
                    FileName = ""
                };

                deleteDmsEntryResponse.Success = Storage.DeleteDmsEntry(filePath);

                _serviceBase.logger.LogInformation("DMS Entry Deleted: " +
                                                   JsonConvert.SerializeObject(deleteDmsEntryRequest));
            }
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            deleteDmsEntryResponse.Success = false;
        }
        finally
        {
            // Ensure the connection is always closed
            if (connection.State != System.Data.ConnectionState.Closed)
            {
                connection.Close();
            }
            connection.Dispose();
        }

        return deleteDmsEntryResponse;
    }

    [Authorize(Roles = "User.Read,User.ReadWrite")]
    public override async Task FileDownload(FileDownloadRequest request,
        IServerStreamWriter<FileDownloadResponse> responseStream, ServerCallContext context)
    {
        FileDownloadResponse fileDownloadResponse = new();

        try
        {
            FilePath filePath = new();
            filePath.ServerBaseLocation = _serverBaseLocation;
            filePath.FilingLocation = FilingLocation.Local;
            filePath.RecordId = request.RecordId;
            filePath.RootFolder = (RootFolder)System.Enum.Parse(typeof(RootFolder), request.RootFolder);
            filePath.FileName = request.Path;

            var fileInfo = Storage.GetFileInfoFor(filePath);

            System.Net.Mime.ContentDisposition cd = new()
            {
                FileName = fileInfo.Name + fileInfo.Extension,
                Inline = false
            };

            var contentType = Storage.GetContentType(filePath);

            fileDownloadResponse.Metadata = new DmsMetaData
            {
                ContentDisposition = cd.ToString(),
                Name = fileInfo.Name,
                Type = contentType
            };

            using (var fs = Storage.OpenFileFrom(filePath))
            {
                fileDownloadResponse.File = new DmsFile();
                fileDownloadResponse.File.Content = ByteString.FromStream(fs);

                fs.Close();
            }

            _serviceBase.logger.LogInformation("File download: " + JsonConvert.SerializeObject(request));

            await responseStream.WriteAsync(fileDownloadResponse);
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
        }
    }

    [Authorize(Roles = "User.ReadWrite")]
    public override async Task<FileUploadResponse> FileUpload(IAsyncStreamReader<FileUploadRequest> requestStream,
        ServerCallContext context)
    {
        FileUploadResponse fileUploadResponse = new() { Status = DmsStatus.Failed };
        FileInfo file;
        FilePath filePath = new();

        try
        {
            var fileUploadRequestCount = 0;
            MemoryStream memoryStream = new();
            BinaryWriter binaryWriter = new(memoryStream);

            while (await requestStream.MoveNext())
            {
                var fileUploadRequest = requestStream.Current;
                if (fileUploadRequestCount == 0)
                {
                    filePath.ServerBaseLocation = _serverBaseLocation;
                    filePath.FilingLocation = FilingLocation.Local;
                    filePath.RecordId = fileUploadRequest.RecordId;
                    filePath.RootFolder =
                        (RootFolder)System.Enum.Parse(typeof(RootFolder), fileUploadRequest.RootFolder);
                    filePath.VirtualPath = fileUploadRequest.Path;
                    filePath.FileName = fileUploadRequest.Metadata.Name;

                    fileUploadRequestCount++;

                    binaryWriter.Write(fileUploadRequest.File.Content.ToByteArray());
                }

                fileUploadRequest.File.Content = ByteString.CopyFrom(new byte[0]);

                _serviceBase.logger.LogInformation("DMS File Uploaded: " +
                                                   JsonConvert.SerializeObject(fileUploadRequest));
            }

            Storage.SaveFileTo(memoryStream, filePath);

            file = Storage.GetFileInfoFor(filePath);
            fileUploadResponse.FileManagerEntry = TypeHelpers.GetFileManagerEntryFromFileInfo(file);

            binaryWriter.Close();

            fileUploadResponse.Status = DmsStatus.Success;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
        }

        return fileUploadResponse;
    }

    [Authorize(Roles = "Mailer.ReadWrite")]
    public override async Task<FilingDestinationSearchResponse> FilingDestinationSearch(
    FilingDestinationSearchRequest request, ServerCallContext context)
    {
        FilingDestinationSearchResponse response = new();
        var connection = _serviceBase._entityFramework.CreateConnection();

        try
        {
            await _serviceBase._entityFramework.OpenConnectionAsync(connection);

            // Step 1: Retrieve the user ID
            var userIdStatement = @"
            SELECT Id
            FROM SCore.Identities
            WHERE LOWER(email) = @Email";

            var userId = -1;

            await using (var command = connection.CreateCommandWithParameters(
                           userIdStatement, CommandType.Text,
                           new SqlParameter("@Email", (_serviceBase.Identity.Name ?? "").ToLower())))
            {
                var scalarResult = await command.ExecuteScalarAsync();
                if (scalarResult != null)
                {
                    userId = int.Parse(scalarResult.ToString() ?? "0");
                }
            }

            _serviceBase.logger.UserId = userId;

            // Step 2: Perform the search if any criteria are provided
            if (!string.IsNullOrWhiteSpace(request.RecordSearch) ||
                !string.IsNullOrWhiteSpace(request.Subject) ||
                !string.IsNullOrWhiteSpace(request.ToAddressesCSV))
            {
                var searchStatement = @"
                SELECT *
                FROM SCore.tvf_ShoreMailerSearch(
                    @RecordSearch,
                    @ToAddressesCSV,
                    @FromAddress,
                    @Subject,
                    @UserId,
                    @EntityType)";

                await using (var command = connection.CreateCommandWithParameters(
                               searchStatement, CommandType.Text,
                               new SqlParameter("@RecordSearch", SqlDbType.NVarChar, 2000) { Value = request.RecordSearch },
                               new SqlParameter("@ToAddressesCSV", SqlDbType.NVarChar, 4000) { Value = request.ToAddressesCSV },
                               new SqlParameter("@FromAddress", SqlDbType.NVarChar, 500) { Value = request.FromAddress },
                               new SqlParameter("@Subject", SqlDbType.NVarChar, 2000) { Value = request.Subject },
                               new SqlParameter("@UserId", SqlDbType.Int) { Value = userId },
                               new SqlParameter("@EntityType", SqlDbType.NVarChar, 20) { Value = request.EntityType }))
                {
                    List<FilingDestination> unsorted = new();

                    await using var reader = await command.ExecuteReaderAsync();
                    while (reader.Read())
                    {
                        var filingDestination = new FilingDestination
                        {
                            RowId = reader.GetIntSafe("RowId"),
                            EntityType = reader.GetStringOrNull("EntityType"),
                            Record = reader.GetStringOrNull("Record"),
                            SearchRank = reader.GetIntSafe("SearchRank")
                        };

                        unsorted.Add(filingDestination);
                    }

                    response.FilingDestinations.AddRange(
                        unsorted.OrderByDescending(o => o.SearchRank)
                                .ThenByDescending(o => o.RowId)
                                .Take(20));
                }
            }
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            throw;
        }
        finally
        {
            // Ensure the connection is always closed and disposed
            if (connection.State != System.Data.ConnectionState.Closed)
            {
                connection.Close();
            }
            connection.Dispose();
        }

        return response;
    }

    [Authorize(Roles = "Mailer.ReadWrite")]
    public override async Task<GetFlattenedFilingStructureReply> GetFlattenedFilingStructure(
    GetFlattenedFilingStructureRequest request, ServerCallContext context)
    {
        GetFlattenedFilingStructureReply response = new();
        var connection = _serviceBase._entityFramework.CreateConnection();

        try
        {
            await _serviceBase._entityFramework.OpenConnectionAsync(connection);

            var statement = @"
            SELECT ID, Name
            FROM SCore.FlattenedFilingStructures";

            await using (var command = connection.CreateCommandWithParameters(statement, CommandType.Text))
            {
                await using var reader = await command.ExecuteReaderAsync();
                while (reader.Read())
                {
                    var flattenedFilingStructure = new FlattenedFilingStructure
                    {
                        Id = reader.GetIntSafe("Id"),
                        Name = reader.GetStringOrNull("Name")
                    };

                    response.FlattenedFilingStructures.Add(flattenedFilingStructure);
                }
            }
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            throw;
        }
        finally
        {
            // Ensure the connection is always closed and disposed
            if (connection.State != System.Data.ConnectionState.Closed)
            {
                connection.Close();
            }
            connection.Dispose();
        }

        return response;
    }

    [Authorize(Roles = "User.Read,User.ReadWrite")]
    public override async Task<GetPathContentResponse> GetPathContent(GetPathContentRequest getFilesRequest, ServerCallContext context)
    {
        GetPathContentResponse getPathContentResponse = new();
        var connection = _serviceBase._entityFramework.CreateConnection();

        try
        {
            // Prepare the file path
            FilePath filePath = new()
            {
                ServerBaseLocation = _serverBaseLocation,
                FilingLocation = FilingLocation.Local,
                RecordId = getFilesRequest.RecordId,
                RootFolder = (RootFolder)Enum.Parse(typeof(RootFolder), getFilesRequest.RootFolder),
                VirtualPath = getFilesRequest.Path
            };

            // Fetch file path contents
            var filePathContents = Storage.GetFilePathContents(filePath, getFilesRequest.Filter);
            List<FileManagerEntry> fileList = filePathContents
                .Select(TypeHelpers.GetFileManagerEntryFromFileInfo)
                .ToList();

            var rootFolderId = (int)Enum.Parse(typeof(RootFolder), getFilesRequest.RootFolder);
            List<dynamic> reports = new();

            await _serviceBase._entityFramework.OpenConnectionAsync(connection);

            // Query to fetch report details
            var statement = @"
            SELECT r.Name, r.CreatedDateTimeUtc, r.ModifiedDateTimeUtc, r.VirtualPath, rt.Code
            FROM SCore.Reports r
            JOIN SCore.ReportingTemplates rt ON r.ReportingTemplateID = rt.Id
            WHERE r.FolderID = @FolderId
              AND r.RootFolderId = @RootFolderId
              AND r.VirtualPath = @VirtualPath
              AND r.RowStatus = @RowStatus";

            await using (var command = connection.CreateCommandWithParameters(
                           statement, CommandType.Text,
                           new SqlParameter("@FolderId", filePath.RecordId),
                           new SqlParameter("@RootFolderId", rootFolderId),
                           new SqlParameter("@VirtualPath", getFilesRequest.Path),
                           new SqlParameter("@RowStatus", (int)Enums.RowStatus.Active)))
            {
                await using var reader = await command.ExecuteReaderAsync();
                while (reader.Read())
                {
                    dynamic report = new ExpandoObject();
                    report.ReportingTemplateCode = reader.GetStringOrNull("Code");
                    report.Name = reader.GetStringOrNull("Name");
                    report.CreatedDateTimeUtc = reader.GetDateTimeOrNull("CreatedDateTimeUtc")?.ToUniversalTime();
                    report.ModifiedDateTimeUtc = reader.GetDateTimeOrNull("ModifiedDateTimeUtc")?.ToUniversalTime();
                    report.VirtualPath = reader.GetStringOrNull("VirtualPath");

                    reports.Add(report);
                }
            }

            // Convert reports to FileManagerEntry objects
            foreach (var report in reports)
            {
                fileList.Add(new FileManagerEntry
                {
                    Extension = ".shore",
                    Name = report.Name,
                    Path = $"{report.VirtualPath}\\{report.Name}.shore",
                    Created = Timestamp.FromDateTime(report.CreatedDateTimeUtc ?? DateTime.UtcNow),
                    CreatedUtc = Timestamp.FromDateTime(report.CreatedDateTimeUtc ?? DateTime.UtcNow),
                    IsDirectory = false,
                    HasDirectories = false,
                    Modified = Timestamp.FromDateTime(report.ModifiedDateTimeUtc ?? DateTime.UtcNow),
                    ModifiedUtc = Timestamp.FromDateTime(report.ModifiedDateTimeUtc ?? DateTime.UtcNow)
                });
            }

            // Add the collected file list to the response
            getPathContentResponse.Content.Add(fileList);
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            throw;
        }
        finally
        {
            // Ensure the connection is always closed and disposed
            if (connection.State != System.Data.ConnectionState.Closed)
            {
                connection.Close();
            }
            connection.Dispose();
        }

        return getPathContentResponse;
    }

    [Authorize(Roles = "User.ReadWrite")]
    public override async Task<RenameDmsEntryResponse> RenameDmsEntry(RenameDmsEntryRequest renameDmsEntryRequest, ServerCallContext context)
    {
        RenameDmsEntryResponse renameDmsEntryResponse = new();
        var connection = _serviceBase._entityFramework.CreateConnection();

        try
        {
            await _serviceBase._entityFramework.OpenConnectionAsync(connection);

            if (renameDmsEntryRequest.FileManagerEntry.Extension == ".shore")
            {
                await connection.ExecuteInTransaction(async transaction =>
                {
                    // Query to find the report ID
                    var findReportStatement = @"
                    SELECT Id
                    FROM SCore.Reports
                    WHERE FolderId = @FolderId
                      AND RootFolderId = @RootFolderId
                      AND RowStatus = @RowStatus
                      AND VirtualPath + N'\' + Name + N'.shore' = @VirtualPath";

                    await using (var command = connection.CreateCommandWithParameters(
                                   findReportStatement, CommandType.Text,
                                   new SqlParameter("@FolderId", renameDmsEntryRequest.FileManagerEntry.RecordId),
                                   new SqlParameter("@RootFolderId", (int)Enum.Parse(typeof(RootFolder), renameDmsEntryRequest.FileManagerEntry.RootFolder)),
                                   new SqlParameter("@RowStatus", (int)Enums.RowStatus.Active),
                                   new SqlParameter("@VirtualPath", renameDmsEntryRequest.FileManagerEntry.Path)))
                    {
                        command.Transaction = transaction;

                        await using var reader = await command.ExecuteReaderAsync();
                        while (reader.Read())
                        {
                            var reportId = reader.GetIntSafe("Id");

                            // Update the report name
                            var renameReportStatement = @"
                            UPDATE SCore.Reports
                            SET Name = @Name, ModifiedDateTimeUtc = GETUTCDATE()
                            WHERE Id = @Id";

                            await using (var updateCommand = connection.CreateCommandWithParameters(
                                           renameReportStatement, CommandType.Text,
                                           new SqlParameter("@Name", renameDmsEntryRequest.NewName),
                                           new SqlParameter("@Id", reportId)))
                            {
                                updateCommand.Transaction = transaction;
                                await updateCommand.ExecuteNonQueryAsync();
                            }
                        }
                    }

                    // Prepare the response
                    renameDmsEntryResponse.FileManagerEntry = new FileManagerEntry
                    {
                        Extension = ".shore",
                        Name = renameDmsEntryRequest.NewName,
                        Path = $"{renameDmsEntryRequest.NewName}.shore",
                        Created = renameDmsEntryRequest.FileManagerEntry.CreatedUtc,
                        CreatedUtc = renameDmsEntryRequest.FileManagerEntry.CreatedUtc,
                        IsDirectory = false,
                        HasDirectories = false,
                        Modified = Timestamp.FromDateTime(DateTime.UtcNow),
                        ModifiedUtc = Timestamp.FromDateTime(DateTime.UtcNow)
                    };
                });
            }
            else
            {
                // Handle non-shore file case
                FilePath filePath = new()
                {
                    IsDirectory = renameDmsEntryRequest.FileManagerEntry.IsDirectory,
                    RootFolder = (RootFolder)Enum.Parse(typeof(RootFolder), renameDmsEntryRequest.FileManagerEntry.RootFolder),
                    RecordId = renameDmsEntryRequest.FileManagerEntry.RecordId,
                    VirtualPath = renameDmsEntryRequest.FileManagerEntry.Path,
                    ServerBaseLocation = _serverBaseLocation,
                    FileName = ""
                };

                var renamedFile = Storage.RenameDmsEntry(filePath, renameDmsEntryRequest.NewName);
                renameDmsEntryResponse.FileManagerEntry = TypeHelpers.GetFileManagerEntryFromFileInfo(renamedFile);
            }

            _serviceBase.logger.LogInformation(
                "DMS Entry Renamed: " + JsonConvert.SerializeObject(renameDmsEntryRequest));
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex);
            throw;
        }
        finally
        {
            // Ensure the connection is always closed and disposed
            if (connection.State != System.Data.ConnectionState.Closed)
            {
                connection.Close();
            }
            connection.Dispose();
        }

        return renameDmsEntryResponse;
    }

    #endregion Public Methods
}