// ==============================
// FILE: CymBuild_Outlook_API/Controllers/GraphController.cs
// ==============================
using Concursus.EF;
using Concursus.EF.Types;
using CymBuild_Outlook_API.Data;
using CymBuild_Outlook_API.Helpers;
using CymBuild_Outlook_API.Services;
using CymBuild_Outlook_Common.Controls;
using CymBuild_Outlook_Common.Dto;
using CymBuild_Outlook_Common.Helpers;
using CymBuild_Outlook_Common.Models;
using CymBuild_Outlook_Common.Models.SharePoint;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Cors;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Graph;
using Microsoft.Graph.Models;
using Microsoft.Graph.Users.Item.MailFolders.Item.Messages.Delta;
using Microsoft.Identity.Web;
using Newtonsoft.Json;
using System.Diagnostics;
using System.IdentityModel.Tokens.Jwt;
using System.Net.Http.Headers;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Message = Microsoft.Graph.Models.Message;

namespace CymBuild_Outlook_API.Controllers
{
    [Authorize(Policy = "AccessAsUserPolicy")]
    [Route("api/[controller]")]
    [ApiController]
    [EnableCors("AddinCors")]
    public class GraphController : ControllerBase
    {
        private readonly IMSGraphBase _graphBaseService;
        private readonly IConfiguration _configuration;
        private readonly LoggingHelper _loggingHelper;
        private readonly AppDbContext _dbContext;
        private readonly ITokenAcquisition _tokenAcquisition;
        private readonly IHttpContextAccessor _httpContextAccessor;
        private readonly CoreServices_API _coreServicesAPI;

        private readonly GraphHelper _graphHelper;
        private readonly SharePointHelper _sharePointHelper;

        public GraphController(
            IMSGraphBase graphBaseService,
            IConfiguration configuration,
            LoggingHelper loggingHelper,
            ITokenAcquisition tokenAcquisition,
            IHttpContextAccessor httpContextAccessor,
            AppDbContext dbContext,
            CoreServices_API coreServicesAPI,
            SharePointHelper sharePointHelper)
        {
            _graphBaseService = graphBaseService;
            _configuration = configuration;
            _loggingHelper = loggingHelper;
            _tokenAcquisition = tokenAcquisition;
            _httpContextAccessor = httpContextAccessor;
            _dbContext = dbContext;
            _coreServicesAPI = coreServicesAPI;

            _graphHelper = new GraphHelper(loggingHelper, configuration);
            _sharePointHelper = sharePointHelper;
        }

        // ---------------------------------------------------------------------
        // Diagnostics helpers
        // ---------------------------------------------------------------------

        private string GetCorrelationId(string prefix)
        {
            if (Request.Headers.TryGetValue("X-Correlation-Id", out var v) && !string.IsNullOrWhiteSpace(v))
                return v.ToString();

            // short + readable, stable for logs
            return $"{prefix}-{DateTime.UtcNow:HHmmssfff}-{Guid.NewGuid():N}".Substring(0, 30);
        }

        private void LogInfo(string corr, string member, string stage, string message)
            => _loggingHelper.LogInfo($"[{corr}] [{stage}] {message}", $"{member}()");

        private void LogWarn(string corr, string member, string stage, string message)
            => _loggingHelper.LogWarning($"[{corr}] [{stage}] {message}", $"{member}()");

        private void LogError(string corr, string member, string stage, string message, Exception ex)
            => _loggingHelper.LogError($"[{corr}] [{stage}] {message}", ex, $"{member}()");

        private static string Hash10(string? s)
        {
            if (string.IsNullOrEmpty(s)) return "(empty)";
            using var sha = SHA256.Create();
            var bytes = sha.ComputeHash(Encoding.UTF8.GetBytes(s));
            return Convert.ToHexString(bytes).Substring(0, 10).ToLowerInvariant();
        }

        private static string SafeText(string? s, int max)
        {
            if (string.IsNullOrWhiteSpace(s)) return "";
            s = s.Replace("\r", " ").Replace("\n", " ").Trim();
            return s.Length <= max ? s : s.Substring(0, max) + "…";
        }

        private static string DescribeMessageForLog(string? messageId, string? subject = null)
            => $"messageIdLen={(messageId?.Length ?? 0)} messageIdHash={Hash10(messageId)} subj='{SafeText(subject, 80)}'";

        private static string DescribeGraphServiceException(ServiceException ex)
        {
            // Best effort. SDK versions differ.
            var status = ex.ResponseStatusCode;
            var msg = ex.Message ?? "";
            var code = "";

            try
            {
                // Try to extract error code from the message if possible
                // Example: "Error code: X" in message
                var msgText = ex.Message ?? "";
                var codePrefix = "Error code:";
                var idx = msgText.IndexOf(codePrefix, StringComparison.OrdinalIgnoreCase);
                if (idx >= 0)
                {
                    var after = msgText.Substring(idx + codePrefix.Length).Trim();
                    var spaceIdx = after.IndexOf(' ');
                    code = spaceIdx > 0 ? after.Substring(0, spaceIdx) : after;
                }
            }
            catch { /* ignore */ }

            return $"status={(int)status} code='{code}' msg='{SafeText(msg, 500)}'";
        }

        // ---------------------------------------------------------------------
        // Existing helpers (unchanged behaviour)
        // ---------------------------------------------------------------------

        private string? TryGetBearerTokenFromHeader()
        {
            var auth = Request.Headers.Authorization.ToString();
            if (string.IsNullOrWhiteSpace(auth)) return null;

            if (auth.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
                return auth.Substring("Bearer ".Length).Trim();

            return null;
        }

        private ClaimsPrincipal CreateClaimsPrincipalFromToken(string token)
        {
            var handler = new JwtSecurityTokenHandler();
            var jwtToken = handler.ReadJwtToken(token);

            var claims = jwtToken.Claims.Select(c => new Claim(c.Type, c.Value)).ToList();

            var nameClaimType =
                jwtToken.Claims.FirstOrDefault(c => c.Type == "email")?.Type ??
                jwtToken.Claims.FirstOrDefault(c => c.Type == "upn")?.Type ??
                jwtToken.Claims.FirstOrDefault(c => c.Type == "preferred_username")?.Type ??
                ClaimTypes.Name;

            var identity = new ClaimsIdentity(claims, "jwt", nameClaimType, ClaimTypes.Role);
            return new ClaimsPrincipal(identity);
        }

        private MailRead ConvertToMailRead(Message message)
        {
            return new MailRead
            {
                Subject = message.Subject ?? string.Empty,
                Body = message.BodyPreview ?? string.Empty,
                Sender = new SenderInfo
                {
                    SenderEmail = message.From?.EmailAddress?.Address ?? string.Empty,
                    SenderName = message.From?.EmailAddress?.Name ?? string.Empty
                },
                ToRecipients = message.ToRecipients?
                    .Select(r => new RecipientInfo
                    {
                        Email = r.EmailAddress?.Address ?? string.Empty,
                        Name = r.EmailAddress?.Name ?? string.Empty
                    })
                    .ToList() ?? new List<RecipientInfo>(),

                CcRecipients = message.CcRecipients?
                    .Select(r => new RecipientInfo
                    {
                        Email = r.EmailAddress?.Address ?? string.Empty,
                        Name = r.EmailAddress?.Name ?? string.Empty
                    })
                    .ToList() ?? new List<RecipientInfo>(),

                BccRecipients = message.BccRecipients?
                    .Select(r => new RecipientInfo
                    {
                        Email = r.EmailAddress?.Address ?? string.Empty,
                        Name = r.EmailAddress?.Name ?? string.Empty
                    })
                    .ToList() ?? new List<RecipientInfo>(),

                CustomProperties = message.SingleValueExtendedProperties?
                    .Where(p => !string.IsNullOrWhiteSpace(p.Id))
                    .ToDictionary(
                        p => p.Id!.Split(' ').Last(),
                        p => p.Value ?? string.Empty
                    )
            };
        }

        private string GetUserIdForGraph(string? explicitUserId, string? bearerToken)
        {
            if (!string.IsNullOrWhiteSpace(explicitUserId))
                return explicitUserId;

            try
            {
                var oid = User?.GetObjectId();
                if (!string.IsNullOrWhiteSpace(oid))
                    return oid;
            }
            catch { /* ignore */ }

            if (!string.IsNullOrWhiteSpace(bearerToken))
            {
                try
                {
                    var tokenDecoder = new TokenDecoder(_loggingHelper);
                    var decoded = tokenDecoder.DecodeUserIdFromToken(bearerToken);
                    if (!string.IsNullOrWhiteSpace(decoded))
                        return decoded;
                }
                catch { /* ignore */ }
            }

            return string.Empty;
        }

        private string GetMailboxFromTokenOrClaims(string? bearerToken)
        {
            try
            {
                var mailbox = User?.GetPreferredUsername();
                if (!string.IsNullOrWhiteSpace(mailbox))
                    return mailbox;
            }
            catch { /* ignore */ }

            if (!string.IsNullOrWhiteSpace(bearerToken))
            {
                try
                {
                    var tokenDecoder = new TokenDecoder(_loggingHelper);
                    return tokenDecoder.DecodeMailBoxFromToken(bearerToken) ?? string.Empty;
                }
                catch { /* ignore */ }
            }

            return string.Empty;
        }

        private async Task<string?> TryAcquireGraphTokenOBOAsync()
        {
            try
            {
                var scopes = _configuration.GetSection("Graph:Scopes").Get<string[]>() ??
                             new[]
                             {
                                 "https://graph.microsoft.com/User.Read",
                                 "https://graph.microsoft.com/Mail.ReadWrite",
                                 "https://graph.microsoft.com/Mail.Read.Write.Shared",
                                 "https://graph.microsoft.com/Sites.ReadWrite.All"
                             };

                var graphToken = await _tokenAcquisition.GetAccessTokenForUserAsync(
                    scopes,
                    user: User,
                    authenticationScheme: JwtBearerDefaults.AuthenticationScheme);

                return graphToken;
            }
            catch (Exception ex)
            {
                _loggingHelper.LogError("Failed acquiring Graph token (OBO).", ex, "TryAcquireGraphTokenOBOAsync()");
                return null;
            }
        }

        // ---------------------------------------------------------------------
        // Endpoints
        // ---------------------------------------------------------------------

        public sealed class TranslateExchangeIdsRequest
        {
            public List<string> InputIds { get; set; } = new();
            public string SourceIdType { get; set; } = "restId";
            public string TargetIdType { get; set; } = "restImmutableEntryId";
        }

        [HttpPost("TranslateExchangeIds")]
        public async Task<IActionResult> TranslateExchangeIds([FromBody] TranslateExchangeIdsRequest request)
        {
            var corr = GetCorrelationId("TranslateExIds");
            var sw = Stopwatch.StartNew();

            LogInfo(corr, nameof(TranslateExchangeIds), "START",
                $"inputIds={request?.InputIds?.Count ?? 0} source='{SafeText(request?.SourceIdType, 50)}' target='{SafeText(request?.TargetIdType, 50)}'");

            try
            {
                if (request?.InputIds == null || request.InputIds.Count == 0)
                {
                    LogWarn(corr, nameof(TranslateExchangeIds), "VALIDATION", "No InputIds provided.");
                    return BadRequest("InputIds is required.");
                }

                // This will FORCE the Kiota auth provider to run => GetAuthorizationTokenAsync will be called.
                var graphClient = _graphBaseService.GetGraphClient();

                // Parse string to ExchangeIdFormat enum
                ExchangeIdFormat? sourceIdType = null;
                ExchangeIdFormat? targetIdType = null;
                if (!string.IsNullOrWhiteSpace(request.SourceIdType) &&
                    Enum.TryParse<ExchangeIdFormat>(request.SourceIdType, true, out var parsedSource))
                {
                    sourceIdType = parsedSource;
                }
                if (!string.IsNullOrWhiteSpace(request.TargetIdType) &&
                    Enum.TryParse<ExchangeIdFormat>(request.TargetIdType, true, out var parsedTarget))
                {
                    targetIdType = parsedTarget;
                }

                var body = new Microsoft.Graph.Me.TranslateExchangeIds.TranslateExchangeIdsPostRequestBody
                {
                    InputIds = request.InputIds,
                    SourceIdType = sourceIdType,
                    TargetIdType = targetIdType
                };

                var result = await graphClient.Me.TranslateExchangeIds.PostAsTranslateExchangeIdsPostResponseAsync(body);

                LogInfo(corr, nameof(TranslateExchangeIds), "END",
                    $"OK totalElapsedMs={sw.ElapsedMilliseconds} outCount={(result?.Value?.Count ?? 0)}");

                return Ok(result);
            }
            catch (ServiceException ex)
            {
                LogError(corr, nameof(TranslateExchangeIds), "GRAPH_ERR",
                    $"ServiceException {DescribeGraphServiceException(ex)} totalElapsedMs={sw.ElapsedMilliseconds}", ex);

                return StatusCode((int)ex.ResponseStatusCode, ex.Message);
            }
            catch (Exception ex)
            {
                LogError(corr, nameof(TranslateExchangeIds), "ERR",
                    $"Unexpected error totalElapsedMs={sw.ElapsedMilliseconds}", ex);

                return StatusCode(500, "Internal server error");
            }
        }

        [HttpGet("GetMessage/{messageId}")]
        public async Task<IActionResult> GetMessage(string messageId)
        {
            var corr = GetCorrelationId("GetMessage");
            var sw = Stopwatch.StartNew();

            LogInfo(corr, nameof(GetMessage), "START", DescribeMessageForLog(messageId));

            try
            {
                var bearer = TryGetBearerTokenFromHeader();
                if (string.IsNullOrWhiteSpace(bearer))
                {
                    LogWarn(corr, nameof(GetMessage), "AUTH", "Missing Authorization header (Bearer).");
                    return Unauthorized("Missing Authorization header.");
                }

                var claimsPrincipal = User?.Identity?.IsAuthenticated == true
                    ? User
                    : CreateClaimsPrincipalFromToken(bearer);

                _ = new Core(_configuration.GetConnectionString("DefaultConnection") ?? "", claimsPrincipal);
                LogInfo(corr, nameof(GetMessage), "CORE", "Core initialised.");

                var graphClient = _graphBaseService.GetGraphClient();

                var userId = GetUserIdForGraph(explicitUserId: null, bearerToken: bearer);
                LogInfo(corr, nameof(GetMessage), "USER", $"Graph userId resolved='{SafeText(userId, 80)}' (len={userId?.Length ?? 0}).");

                var swGraph = Stopwatch.StartNew();
                var message = await _graphHelper.GetEmailWithCustomProperties(graphClient, userId, messageId);
                swGraph.Stop();

                if (message == null)
                {
                    LogWarn(corr, nameof(GetMessage), "GRAPH", $"Message not found. ElapsedMs={swGraph.ElapsedMilliseconds}");
                    return NotFound($"Message with ID {messageId} not found.");
                }

                LogInfo(corr, nameof(GetMessage), "GRAPH", $"Message fetched OK. subject='{SafeText(message.Subject, 80)}' ElapsedMs={swGraph.ElapsedMilliseconds}");

                var mailRead = ConvertToMailRead(message);
                LogInfo(corr, nameof(GetMessage), "END", $"OK totalElapsedMs={sw.ElapsedMilliseconds}");
                return Ok(mailRead);
            }
            catch (ServiceException ex)
            {
                LogError(corr, nameof(GetMessage), "GRAPH_ERR",
                    $"ServiceException {DescribeGraphServiceException(ex)} totalElapsedMs={sw.ElapsedMilliseconds} {DescribeMessageForLog(messageId)}", ex);

                return StatusCode((int)ex.ResponseStatusCode, ex.Message);
            }
            catch (Exception ex)
            {
                LogError(corr, nameof(GetMessage), "ERR",
                    $"Unexpected error totalElapsedMs={sw.ElapsedMilliseconds} {DescribeMessageForLog(messageId)}", ex);

                return StatusCode(500, "Internal server error");
            }
        }

        [HttpPost("SaveMultipleToSharePoint")]
        public async Task<IActionResult> SaveMultipleToSharePoint([FromBody] List<SaveToSharePointRequest> requests)
        {
            var batchCorr = GetCorrelationId("SaveMultiple");
            LogInfo(batchCorr, nameof(SaveMultipleToSharePoint), "START", $"requests={requests?.Count ?? 0}");

            var responses = new List<SaveToSharePointResponse>();
            var list = requests ?? new List<SaveToSharePointRequest>();

            for (var i = 0; i < list.Count; i++)
            {
                var req = list[i];

                // Per-item correlation so you can trace one message cleanly
                var itemCorr = $"{batchCorr}-{i + 1:000}";

                try
                {
                    var response = await SaveToSharePointInternal(req, itemCorr);

                    // Ensure correlation always comes back to client even on success paths
                    response.CorrelationId = string.IsNullOrWhiteSpace(response.CorrelationId) ? itemCorr : response.CorrelationId;
                    responses.Add(response);
                }
                catch (Exception ex)
                {
                    LogError(itemCorr, nameof(SaveMultipleToSharePoint), "ERR",
                        $"Error processing request {DescribeMessageForLog(req?.MessageId)}", ex);

                    responses.Add(new SaveToSharePointResponse
                    {
                        Status = "Failed",
                        FullUrl = string.Empty,
                        CorrelationId = itemCorr,
                        Stage = "Controller",
                        ErrorCode = "UnhandledException",
                        ErrorMessage = ex.Message
                    });
                }
            }

            LogInfo(batchCorr, nameof(SaveMultipleToSharePoint), "END", $"responses={responses.Count}");
            return Ok(responses);
        }

        [HttpPost("SaveToSharePoint")]
        public async Task<IActionResult> SaveToSharePoint([FromBody] SaveToSharePointRequest request)
        {
            var corr = GetCorrelationId("SaveToSP");
            LogInfo(corr, nameof(SaveToSharePoint), "START",
                $"{DescribeMessageForLog(request?.MessageId)} site='{SafeText(request?.SharePointSiteId, 80)}' folder='{SafeText(request?.SharePointFolderId, 80)}'");

            try
            {
                var result = await SaveToSharePointInternal(request, corr);

                if (string.Equals(result.Status, "Success", StringComparison.OrdinalIgnoreCase))
                {
                    LogInfo(corr, nameof(SaveToSharePoint), "END", $"SUCCESS fullUrlLen={result.FullUrl?.Length ?? 0}");
                    return Ok(result);
                }

                LogWarn(corr, nameof(SaveToSharePoint), "END", $"FAILED status='{result.Status}' fullUrlLen={result.FullUrl?.Length ?? 0}");
                return StatusCode(500, result);
            }
            catch (ServiceException ex)
            {
                LogError(corr, nameof(SaveToSharePoint), "GRAPH_ERR", $"ServiceException {DescribeGraphServiceException(ex)}", ex);
                return BadRequest(ex.Message);
            }
            catch (Exception ex)
            {
                LogError(corr, nameof(SaveToSharePoint), "ERR", "Exception while saving to SharePoint", ex);
                return BadRequest(ex.Message);
            }
        }

        // NOTE: Signature change adds corr param for logging only (internal call sites updated above)
        private async Task<SaveToSharePointResponse> SaveToSharePointInternal(SaveToSharePointRequest request, string corr)
        {
            var sw = Stopwatch.StartNew();
            GraphServiceClient? graphClient = null;

            // Always prefer Authorization header, body authToken is ignored.
            var bearer = TryGetBearerTokenFromHeader();

            LogInfo(corr, nameof(SaveToSharePointInternal), "START",
                $"{DescribeMessageForLog(request?.MessageId, request?.Description)} " +
                $"targetGuid={request?.TargetObjectGuid} entityTypeGuid={request?.EntityTypeGuid} " +
                $"site='{SafeText(request?.SharePointSiteId, 80)}' folder='{SafeText(request?.SharePointFolderId, 80)}' subFolder='{SafeText(request?.SubFolder, 80)}' " +
                $"moveToFiled={request?.MoveToCymBuildFiled} doNotFile={request?.DoNotFile} processed={request?.ProcessedCount}/{request?.TotalCount}");

            try
            {
                // ---------------------------------------------------------------------
                // AUTH
                // ---------------------------------------------------------------------
                if (string.IsNullOrWhiteSpace(bearer) && (User?.Identity?.IsAuthenticated != true))
                {
                    LogWarn(corr, nameof(SaveToSharePointInternal), "AUTH", "Missing bearer token / unauthenticated request.");
                    return Fail(corr, "Auth", "MissingBearer", "Missing bearer token / unauthenticated request.");
                }

                var claimsPrincipal = User?.Identity?.IsAuthenticated == true
                    ? User
                    : (!string.IsNullOrWhiteSpace(bearer) ? CreateClaimsPrincipalFromToken(bearer) : new ClaimsPrincipal());

                claimsPrincipal = EnsureUserIdentityHasNameAndEmail(claimsPrincipal);

                _loggingHelper.LogInfo(
                    $"Auth: IsAuthenticated={claimsPrincipal?.Identity?.IsAuthenticated} " +
                    $"name='{SafeText(claimsPrincipal?.Identity?.Name, 80)}' " +
                    $"email='{SafeText(ResolveUserEmail(claimsPrincipal), 120)}' " +
                    $"oid={claimsPrincipal?.Claims?.FirstOrDefault(c => c.Type == "oid")?.Value} " +
                    $"tid={claimsPrincipal?.Claims?.FirstOrDefault(c => c.Type == "tid")?.Value}",
                    "GraphController.AuthDebug()");

                // Core init (needed for DataObjectGet security context)
                _ = new Core(_configuration.GetConnectionString("DefaultConnection") ?? "", claimsPrincipal);
                LogInfo(corr, nameof(SaveToSharePointInternal), "CORE", "Core initialised.");

                // Graph client (OBO)
                graphClient = _graphBaseService.GetGraphClient();
                if (graphClient == null)
                    return Fail(corr, "GraphClient", "NullGraphClient", "GraphServiceClient could not be created.");

                // ---------------------------------------------------------------------
                // USERID RESOLUTION
                // ---------------------------------------------------------------------
                if (string.IsNullOrWhiteSpace(request.UserId))
                    request.UserId = GetUserIdForGraph(request.UserId, bearer);

                if (string.IsNullOrWhiteSpace(request.UserId))
                {
                    LogWarn(corr, nameof(SaveToSharePointInternal), "USER", "Unable to resolve request.UserId.");
                    return Fail(corr, "User", "UserIdNotResolved", "Unable to resolve Graph userId from token/claims.");
                }

                LogInfo(corr, nameof(SaveToSharePointInternal), "USER", $"userId='{SafeText(request.UserId, 80)}'");

                // ---------------------------------------------------------------------
                // FETCH MESSAGE METADATA
                // ---------------------------------------------------------------------
                var swMsg = Stopwatch.StartNew();
                var message = await graphClient.Users[request.UserId].Messages[request.MessageId].GetAsync();
                swMsg.Stop();

                if (message == null)
                {
                    LogWarn(corr, nameof(SaveToSharePointInternal), "MSG", $"Message returned null. ElapsedMs={swMsg.ElapsedMilliseconds}");
                    return Fail(corr, "Message", "MessageNull", "Graph returned null message.");
                }

                LogInfo(corr, nameof(SaveToSharePointInternal), "MSG",
                    $"Fetched message OK subject='{SafeText(message.Subject, 80)}' from='{SafeText(message.From?.EmailAddress?.Address, 80)}' " +
                    $"convIdLen={(message.ConversationId?.Length ?? 0)} ElapsedMs={swMsg.ElapsedMilliseconds}");

                var mailbox = GetMailboxFromTokenOrClaims(bearer);
                LogInfo(corr, nameof(SaveToSharePointInternal), "MAILBOX", $"mailbox='{SafeText(mailbox, 120)}'");

                // ---------------------------------------------------------------------
                // PREPARE DB DTO (EmailUpsertDto)
                // ---------------------------------------------------------------------
                var emailUpsertDto = new EmailUpsertDto
                {
                    TargetObjectGuid = request.TargetObjectGuid,
                    Mailbox = mailbox,
                    MessageID = request.MessageId,
                    ConversationID = message.ConversationId ?? "",
                    FromAddress = message.From?.EmailAddress?.Address ?? "",
                    ToAddresses = string.Join(";", message.ToRecipients?.Select(r => r.EmailAddress?.Address).Where(a => !string.IsNullOrWhiteSpace(a)) ?? Array.Empty<string>()),
                    Subject = message.Subject ?? "",
                    SentDateTime = message.SentDateTime?.UtcDateTime ?? default,
                    DeliveryReceiptRequested = message.IsDeliveryReceiptRequested ?? false,
                    DeliveryReceiptReceived = false,
                    ReadReceiptRequested = message.IsReadReceiptRequested ?? false,
                    ReadReceiptReceived = false,
                    DoNotFile = request.DoNotFile,
                    IsReadyToFile = !request.DoNotFile,
                    FiledDateTime = null,
                    Description = request.Description ?? "",
                    Guid = Guid.NewGuid(),
                };

                LogInfo(corr, nameof(SaveToSharePointInternal), "DTO",
                    $"EmailUpsertDto ready. targetGuid={emailUpsertDto.TargetObjectGuid} toCount={(message.ToRecipients?.Count ?? 0)} subjectLen={(emailUpsertDto.Subject?.Length ?? 0)}");

                // ---------------------------------------------------------------------
                // CATEGORY: Filing (best effort; do NOT fail whole operation)
                // ---------------------------------------------------------------------
                try
                {
                    var swCat = Stopwatch.StartNew();
                    await _graphHelper.AddOrUpdateCategoryAsync(graphClient, request.UserId, request.MessageId, "Filing", CategoryColor.Preset16, corr);
                    swCat.Stop();
                    LogInfo(corr, nameof(SaveToSharePointInternal), "CATEGORY", $"Added/ensured 'Filing' ElapsedMs={swCat.ElapsedMilliseconds}");
                }
                catch (Exception exCat)
                {
                    LogWarn(corr, nameof(SaveToSharePointInternal), "CATEGORY",
                        $"Failed to add 'Filing' category (continuing). {SafeText(exCat.Message, 400)}");
                }

                // ---------------------------------------------------------------------
                // DB UPSERT (best effort; do NOT fail whole operation)
                // ---------------------------------------------------------------------
                string baseUrl = _configuration["ApiSettings:BaseUrl"] ?? "";
                string upsertUrl = $"{baseUrl}/api/OutlookEmail/Upsert";

                using var httpClient = new HttpClient();
                if (!string.IsNullOrWhiteSpace(bearer))
                    httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", bearer);

                httpClient.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
                httpClient.DefaultRequestHeaders.Add("Prefer", "IdType=\"ImmutableId\"");
                httpClient.DefaultRequestHeaders.TryAddWithoutValidation("X-Correlation-Id", corr);

                try
                {
                    var swUpsert = Stopwatch.StartNew();
                    LogInfo(corr, nameof(SaveToSharePointInternal), "DB_UPSERT", $"POST {SafeText(upsertUrl, 200)}");

                    var upsertResponse = await httpClient.PostAsJsonAsync(upsertUrl, emailUpsertDto);
                    var upsertContent = await SafeReadBodySnippetAsync(upsertResponse, 1400);

                    swUpsert.Stop();

                    LogInfo(corr, nameof(SaveToSharePointInternal), "DB_UPSERT",
                        $"status={(int)upsertResponse.StatusCode} reason='{upsertResponse.ReasonPhrase}' ElapsedMs={swUpsert.ElapsedMilliseconds} body='{upsertContent}'");

                    if (!upsertResponse.IsSuccessStatusCode)
                        LogWarn(corr, nameof(SaveToSharePointInternal), "DB_UPSERT", "Upsert failed (continuing - filing may still succeed).");
                }
                catch (Exception exUpsert)
                {
                    LogWarn(corr, nameof(SaveToSharePointInternal), "DB_UPSERT",
                        $"Upsert threw exception (continuing). {SafeText(exUpsert.Message, 400)}");
                }

                // ---------------------------------------------------------------------
                // MIME FETCH
                // ---------------------------------------------------------------------
                Stream? mimeContentStream = null;
                try
                {
                    var swMime = Stopwatch.StartNew();
                    LogInfo(corr, nameof(SaveToSharePointInternal), "MIME", "Fetching MIME content stream...");

                    mimeContentStream = await graphClient.Users[request.UserId].Messages[request.MessageId].Content.GetAsync();
                    swMime.Stop();

                    if (mimeContentStream == null)
                        return Fail(corr, "Mime", "MimeNull", "MIME content stream was null.");

                    LogInfo(corr, nameof(SaveToSharePointInternal), "MIME", $"MIME stream OK. ElapsedMs={swMime.ElapsedMilliseconds}");
                }
                catch (ServiceException exMime)
                {
                    LogError(corr, nameof(SaveToSharePointInternal), "MIME_GRAPH_ERR",
                        $"ServiceException while fetching MIME: {DescribeGraphServiceException(exMime)} totalElapsedMs={sw.ElapsedMilliseconds}", exMime);

                    return Fail(corr, "Mime", "MimeGraphError", exMime.Message);
                }
                catch (Exception exMime)
                {
                    LogError(corr, nameof(SaveToSharePointInternal), "MIME_ERR",
                        $"Exception while fetching MIME totalElapsedMs={sw.ElapsedMilliseconds}", exMime);

                    return Fail(corr, "Mime", "MimeError", exMime.Message);
                }

                // ---------------------------------------------------------------------
                // RESOLVE SHAREPOINT LOCATION (DataObjectGet)
                // ---------------------------------------------------------------------
                DataObject? dataObject = null;
                try
                {
                    var swDo = Stopwatch.StartNew();

                    var dataObjectGetRequest = new DataObjectGetRequest
                    {
                        Guid = request.TargetObjectGuid.ToString(),
                        EntityTypeGuid = request.EntityTypeGuid.ToString(),
                        EntityQueryGuid = "00000000-0000-0000-0000-000000000000",
                        ForInformationView = false
                    };

                    LogInfo(corr, nameof(SaveToSharePointInternal), "DATAOBJ",
                        $"DataObjectGet START targetGuid={request.TargetObjectGuid} entityTypeGuid={request.EntityTypeGuid} " +
                        $"Claims Name='{SafeText(claimsPrincipal.Identity?.Name, 80)}' Email='{SafeText(ResolveUserEmail(claimsPrincipal), 120)}' Auth={claimsPrincipal.Identity?.IsAuthenticated}");

                    var dataObjectGetResponse = await _coreServicesAPI.DataObjectGet(
                        dataObjectGetRequest,
                        _configuration,
                        serviceBase: null,
                        claimsPrincipal);

                    swDo.Stop();

                    dataObject = dataObjectGetResponse?.DataObject;

                    LogInfo(corr, nameof(SaveToSharePointInternal), "DATAOBJ",
                        $"DataObjectGet END ElapsedMs={swDo.ElapsedMilliseconds} " +
                        $"error='{SafeText(dataObject?.ErrorReturned, 220)}' " +
                        $"hasDocs={(dataObject?.HasDocuments ?? false)} " +
                        $"spSiteId='{SafeText(dataObject?.SharePointSiteIdentifier, 120)}' " +
                        $"spFolderPath='{SafeText(dataObject?.SharePointFolderPath, 220)}' " +
                        $"spUrl='{SafeText(dataObject?.SharePointUrl, 220)}'");

                    if (dataObject == null)
                    {
                        await UpdateEmailCategoryToErrorAsync(graphClient, request, corr);
                        return Fail(corr, "DataObjectGet", "DataObjectNull", "DataObjectGet returned null.");
                    }

                    if (!string.IsNullOrWhiteSpace(dataObject.ErrorReturned))
                    {
                        await UpdateEmailCategoryToErrorAsync(graphClient, request, corr);
                        return Fail(corr, "DataObjectGet", "DataObjectError", dataObject.ErrorReturned);
                    }

                    if (string.IsNullOrWhiteSpace(dataObject.SharePointSiteIdentifier) ||
                        string.IsNullOrWhiteSpace(dataObject.SharePointFolderPath))
                    {
                        await UpdateEmailCategoryToErrorAsync(graphClient, request, corr);
                        return Fail(corr, "SharePointPath", "MissingSharePointPath",
                            $"DataObject did not provide SharePointSiteIdentifier/SharePointFolderPath. site='{dataObject.SharePointSiteIdentifier}' folder='{dataObject.SharePointFolderPath}'");
                    }
                }
                catch (Exception exDo)
                {
                    await UpdateEmailCategoryToErrorAsync(graphClient, request, corr);
                    LogError(corr, nameof(SaveToSharePointInternal), "DATAOBJ_ERR",
                        $"Exception during DataObjectGet totalElapsedMs={sw.ElapsedMilliseconds}", exDo);

                    return Fail(corr, "DataObjectGet", "DataObjectException", exDo.Message);
                }

                // ---------------------------------------------------------------------
                // UPLOAD EMAIL (this is Fix #2 focus)
                // ---------------------------------------------------------------------
                var siteId = dataObject!.SharePointSiteIdentifier;
                var folderPath = dataObject.SharePointFolderPath;
                var subFolderPath = request.SubFolder;

                LogInfo(corr, nameof(SaveToSharePointInternal), "SP_PATH",
                    $"Resolved SP path for upload. siteId='{SafeText(siteId, 120)}' folderPath='{SafeText(folderPath, 220)}' subFolder='{SafeText(subFolderPath, 120)}' " +
                    $"browserUrl='{SafeText(dataObject.SharePointUrl, 220)}'");

                SaveToSharePointResponse uploadResult;
                try
                {
                    var swUpload = Stopwatch.StartNew();

                    uploadResult = await _graphHelper.UploadEmailToSharePoint(
                        graphClient,
                        siteId,
                        folderPath,
                        subFolderPath,
                        mimeContentStream!,
                        message.Subject ?? "",
                        request,
                        message.From?.EmailAddress?.Name ?? "",
                        DateTime.UtcNow,
                        corr);

                    swUpload.Stop();

                    // Always stamp correlation
                    uploadResult.CorrelationId = string.IsNullOrWhiteSpace(uploadResult.CorrelationId) ? corr : uploadResult.CorrelationId;

                    LogInfo(corr, nameof(SaveToSharePointInternal), "UPLOAD",
                        $"Upload END ElapsedMs={swUpload.ElapsedMilliseconds} status='{uploadResult.Status}' stage='{SafeText(uploadResult.Stage, 60)}' " +
                        $"fullUrlLen={(uploadResult.FullUrl?.Length ?? 0)} errCode='{SafeText(uploadResult.ErrorCode, 80)}' errMsg='{SafeText(uploadResult.ErrorMessage, 220)}'");
                }
                catch (Exception exUpload)
                {
                    await UpdateEmailCategoryToErrorAsync(graphClient, request, corr);
                    LogError(corr, nameof(SaveToSharePointInternal), "UPLOAD_ERR",
                        $"Exception during upload totalElapsedMs={sw.ElapsedMilliseconds}", exUpload);

                    return Fail(corr, "Upload", "UploadException", exUpload.Message);
                }

                if (uploadResult.Status.Contains("Failed", StringComparison.OrdinalIgnoreCase))
                {
                    await UpdateEmailCategoryToErrorAsync(graphClient, request, corr);

                    LogInfo(corr, nameof(SaveToSharePointInternal), "END",
                        $"FAILED (Upload) totalElapsedMs={sw.ElapsedMilliseconds}");

                    // Return diagnostics to the UI
                    return uploadResult;
                }

                // -----------------------------
                // PERMISSIONS (best-effort)
                // -----------------------------
                try
                {
                    if (!string.IsNullOrWhiteSpace(uploadResult.DriveId) &&
                        !string.IsNullOrWhiteSpace(uploadResult.ItemId))
                    {
                        LogInfo(corr, nameof(SaveToSharePointInternal), "PERMS",
                            $"Setting SharePoint permissions driveIdLen={uploadResult.DriveId.Length} itemIdLen={uploadResult.ItemId.Length}");

                        await _sharePointHelper.SetSharePointPermissionAsync(
                            siteId,
                            dataObject!,
                            uploadResult.DriveId,
                            uploadResult.ItemId
                        ).ConfigureAwait(false);

                        LogInfo(corr, nameof(SaveToSharePointInternal), "PERMS", "Permissions applied (best-effort).");
                    }
                    else
                    {
                        LogWarn(corr, nameof(SaveToSharePointInternal), "PERMS",
                            "Skipping permission assignment: DriveId/ItemId not present on uploadResult (ensure UploadEmailToSharePoint returns them).");
                    }
                }
                catch (Exception exPerm)
                {
                    // IMPORTANT: do NOT fail filing because perms failed
                    LogWarn(corr, nameof(SaveToSharePointInternal), "PERMS",
                        $"Permission assignment failed (continuing). {SafeText(exPerm.Message, 400)}");

                    // Mark warnings, but keep success semantics
                    if (uploadResult.Status.Equals("Success", StringComparison.OrdinalIgnoreCase))
                    {
                        uploadResult.Status = "UploadedWithWarnings";
                        uploadResult.Stage = "SetPermissions";
                        uploadResult.ErrorCode = "PermissionAssignmentFailed";
                        uploadResult.ErrorMessage = exPerm.Message;
                    }
                }

                // ---------------------------------------------------------------------
                // DB UPDATE (filing URL) - best effort
                // ---------------------------------------------------------------------
                try
                {
                    emailUpsertDto.IsReadyToFile = false;
                    emailUpsertDto.FiledDateTime = DateTime.UtcNow;
                    emailUpsertDto.FilingLocationUrl = Converters.GetModifiedUrl(uploadResult.FullUrl);

                    var swUpdate = Stopwatch.StartNew();
                    var updateResponse = await httpClient.PostAsJsonAsync(upsertUrl, emailUpsertDto);
                    var updateContent = await SafeReadBodySnippetAsync(updateResponse, 1400);
                    swUpdate.Stop();

                    LogInfo(corr, nameof(SaveToSharePointInternal), "DB_UPDATE",
                        $"status={(int)updateResponse.StatusCode} reason='{updateResponse.ReasonPhrase}' ElapsedMs={swUpdate.ElapsedMilliseconds} body='{updateContent}'");

                    if (!updateResponse.IsSuccessStatusCode)
                        LogWarn(corr, nameof(SaveToSharePointInternal), "DB_UPDATE", "DB update failed (FilingLocationUrl).");
                }
                catch (Exception exDbUpdate)
                {
                    LogWarn(corr, nameof(SaveToSharePointInternal), "DB_UPDATE",
                        $"DB update threw exception (continuing). {SafeText(exDbUpdate.Message, 400)}");
                }

                // ---------------------------------------------------------------------
                // POST-FILE ACTIONS
                // ---------------------------------------------------------------------
                try
                {
                    if (request.ProcessedCount == request.TotalCount)
                    {
                        LogInfo(corr, nameof(SaveToSharePointInternal), "POST_FILE",
                            "ProcessedCount==TotalCount => Update categories/move/sync.");

                        await UpdateEmailCategoriesAndMoveAsync(graphClient, request, corr);
                    }
                }
                catch (Exception exPost)
                {
                    LogWarn(corr, nameof(SaveToSharePointInternal), "POST_FILE",
                        $"Post-file actions failed (continuing). {SafeText(exPost.Message, 400)}");

                    // If we were otherwise success, mark warnings (don’t fail)
                    if (uploadResult.Status.Equals("Success", StringComparison.OrdinalIgnoreCase))
                    {
                        uploadResult.Status = "UploadedWithWarnings";
                        uploadResult.Stage = "PostFileActions";
                        uploadResult.ErrorCode = "PostFileFailed";
                        uploadResult.ErrorMessage = exPost.Message;
                    }
                }

                LogInfo(corr, nameof(SaveToSharePointInternal), "END",
                    $"{uploadResult.Status} totalElapsedMs={sw.ElapsedMilliseconds} fullUrlLen={(uploadResult.FullUrl?.Length ?? 0)}");

                // Return the upload result so diagnostics flow to UI
                uploadResult.CorrelationId = string.IsNullOrWhiteSpace(uploadResult.CorrelationId) ? corr : uploadResult.CorrelationId;
                if (string.IsNullOrWhiteSpace(uploadResult.Stage))
                    uploadResult.Stage = uploadResult.Status.Equals("Success", StringComparison.OrdinalIgnoreCase) ? "Complete" : uploadResult.Stage;

                return uploadResult;
            }
            catch (ServiceException ex)
            {
                LogError(corr, nameof(SaveToSharePointInternal), "GRAPH_ERR",
                    $"ServiceException {DescribeGraphServiceException(ex)} totalElapsedMs={sw.ElapsedMilliseconds}", ex);

                return Fail(corr, "Graph", "GraphServiceException", ex.Message);
            }
            catch (Exception ex)
            {
                LogError(corr, nameof(SaveToSharePointInternal), "ERR",
                    $"Exception while saving to SharePoint totalElapsedMs={sw.ElapsedMilliseconds}", ex);

                return Fail(corr, "Unhandled", "Exception", ex.Message);
            }
        }


        private async Task UpdateEmailCategoriesAndMoveAsync(GraphServiceClient graphClient, SaveToSharePointRequest request, string corr)
        {
            var sw = Stopwatch.StartNew();
            try
            {
                LogInfo(corr, nameof(UpdateEmailCategoriesAndMoveAsync), "START", DescribeMessageForLog(request?.MessageId));

                await _graphHelper.RemoveCategoryFromEmailAsync(graphClient, request.UserId, request.MessageId, "Filing", corr);
                await _graphHelper.RemoveCategoryFromEmailAsync(graphClient, request.UserId, request.MessageId, "Filing Error", corr);
                await _graphHelper.AddOrUpdateCategoryAsync(graphClient, request.UserId, request.MessageId, "Filed", CategoryColor.Preset19, corr);

                if (request.MoveToCymBuildFiled)
                {
                    await _graphHelper.MoveEmailToFolderAsync(
                        graphClient,
                        request.UserId,
                        request.MessageId,
                        "CymBuild Filed",
                        (List<RecordSearchResult>)request.RecordSearchResults,
                        corr);
                }

                LogInfo(corr, nameof(UpdateEmailCategoriesAndMoveAsync), "SYNC", "Resolve folder id + delta sync...");
                var folderId = await ResolveMailFolderIdByDisplayNameAsync(graphClient, request.UserId, "CymBuild Filed");
                if (folderId != null)
                    await SyncFolderAsync(graphClient, request.UserId, folderId);

                LogInfo(corr, nameof(UpdateEmailCategoriesAndMoveAsync), "END", $"OK ElapsedMs={sw.ElapsedMilliseconds}");
            }
            catch (Exception ex)
            {
                LogError(corr, nameof(UpdateEmailCategoriesAndMoveAsync), "ERR",
                    $"Error updating categories/moving/sync. ElapsedMs={sw.ElapsedMilliseconds} {DescribeMessageForLog(request?.MessageId)}", ex);
            }
        }

        private static async Task<string?> ResolveMailFolderIdByDisplayNameAsync(GraphServiceClient graphClient, string userId, string displayName)
        {
            if (graphClient == null) throw new ArgumentNullException(nameof(graphClient));
            if (string.IsNullOrWhiteSpace(userId)) throw new ArgumentException("userId is required");
            if (string.IsNullOrWhiteSpace(displayName)) throw new ArgumentException("displayName is required");

            var folders = await graphClient.Users[userId].MailFolders.GetAsync(rc =>
            {
                rc.QueryParameters.Top = 200;
                rc.QueryParameters.Select = new[] { "id", "displayName" };
            });

            var match = folders?.Value?.FirstOrDefault(f =>
                string.Equals(f.DisplayName, displayName, StringComparison.OrdinalIgnoreCase));

            if (match?.Id != null)
                return match.Id;

            if (folders?.Value != null)
            {
                foreach (var f in folders.Value.Where(x => x.Id != null))
                {
                    var child = await graphClient.Users[userId].MailFolders[f.Id!].ChildFolders.GetAsync(rc =>
                    {
                        rc.QueryParameters.Top = 200;
                        rc.QueryParameters.Select = new[] { "id", "displayName" };
                    });

                    var childMatch = child?.Value?.FirstOrDefault(cf =>
                        string.Equals(cf.DisplayName, displayName, StringComparison.OrdinalIgnoreCase));

                    if (childMatch?.Id != null)
                        return childMatch.Id;
                }
            }

            return null;
        }

        private async Task UpdateEmailCategoryToErrorAsync(GraphServiceClient graphClient, SaveToSharePointRequest request, string corr)
        {
            try
            {
                LogInfo(corr, nameof(UpdateEmailCategoryToErrorAsync), "START", DescribeMessageForLog(request?.MessageId));
                await _graphHelper.RemoveCategoryFromEmailAsync(graphClient, request.UserId, request.MessageId, "Filing", corr);
                await _graphHelper.AddOrUpdateCategoryAsync(graphClient, request.UserId, request.MessageId, "Filing Error", CategoryColor.Preset23, corr);
                LogInfo(corr, nameof(UpdateEmailCategoryToErrorAsync), "END", "OK");
            }
            catch (Exception ex)
            {
                LogError(corr, nameof(UpdateEmailCategoryToErrorAsync), "ERR",
                    $"Failed to set Filing Error category. {DescribeMessageForLog(request?.MessageId)}", ex);
            }
        }

        // ---------------------------------------------------------------------
        // User Settings (unchanged)
        // ---------------------------------------------------------------------

        [HttpGet("GetUserSettings")]
        public async Task<ActionResult<Dictionary<string, object>>> GetUserSettings()
        {
            var corr = GetCorrelationId("GetUserSettings");
            _loggingHelper.LogInfo(
                $"Auth: IsAuthenticated={User?.Identity?.IsAuthenticated} " +
                $"oid={User?.Claims?.FirstOrDefault(c => c.Type == "oid")?.Value} " +
                $"tid={User?.Claims?.FirstOrDefault(c => c.Type == "tid")?.Value} " +
                $"preferred_username={User?.Claims?.FirstOrDefault(c => c.Type == "preferred_username")?.Value}",
                "GraphController.AuthDebug()");
            try
            {
                LogInfo(corr, nameof(GetUserSettings), "START", "Fetching user settings...");
                var settings = await GetUserSettingsFromGraphAsync();
                LogInfo(corr, nameof(GetUserSettings), "END", $"OK keys={settings?.Count ?? 0}");
                return Ok(settings);
            }
            catch (ServiceException ex)
            {
                LogError(corr, nameof(GetUserSettings), "GRAPH_ERR", DescribeGraphServiceException(ex), ex);
                return StatusCode(500, ex.Message);
            }
        }

        [HttpPost("SaveUserSettings")]
        public async Task<IActionResult> SaveUserSettings([FromBody] Dictionary<string, object> settings)
        {
            var corr = GetCorrelationId("SaveUserSettings");
            try
            {
                LogInfo(corr, nameof(SaveUserSettings), "START", $"keys={settings?.Count ?? 0}");
                await SaveUserSettingsToGraphAsync(settings);
                LogInfo(corr, nameof(SaveUserSettings), "END", "OK");
                return Ok();
            }
            catch (ServiceException ex)
            {
                LogError(corr, nameof(SaveUserSettings), "GRAPH_ERR", DescribeGraphServiceException(ex), ex);
                return StatusCode(500, ex.Message);
            }
        }

        private string GetFiledRecordPropertyValue()
        {
            var tokenRequestConfig = _configuration.GetSection("FiledRecords");
            var values = tokenRequestConfig.GetValue<string[]>("PropertyValue");

            var v = values?.FirstOrDefault();
            return string.IsNullOrWhiteSpace(v) ? string.Empty : v;
        }

        private async Task<Dictionary<string, object>> GetUserSettingsFromGraphAsync()
        {
            var graphClient = _graphBaseService.GetGraphClient();
            var user = await graphClient.Me.GetAsync();

            var key = GetFiledRecordPropertyValue();
            if (string.IsNullOrWhiteSpace(key) || user?.AdditionalData == null)
            {
                return new Dictionary<string, object>
                {
                    { "moveToCymBuildFiled", false },
                    { "extractAttachments", false }
                };
            }

            if (user.AdditionalData.TryGetValue(key, out var settingsObj) && settingsObj != null)
            {
                var json = settingsObj.ToString();
                if (!string.IsNullOrWhiteSpace(json))
                {
                    var settings = JsonConvert.DeserializeObject<Dictionary<string, object>>(json);
                    if (settings != null)
                        return settings;
                }
            }

            return new Dictionary<string, object>
            {
                { "moveToCymBuildFiled", false },
                { "extractAttachments", false }
            };
        }

        private async Task SaveUserSettingsToGraphAsync(Dictionary<string, object> settings)
        {
            var graphClient = _graphBaseService.GetGraphClient();
            var key = GetFiledRecordPropertyValue();

            if (string.IsNullOrWhiteSpace(key))
                throw new InvalidOperationException("FiledRecords:PropertyValue is not configured.");

            var json = JsonConvert.SerializeObject(settings);

            await graphClient.Me.PatchAsync(new Microsoft.Graph.Models.User
            {
                AdditionalData = new Dictionary<string, object>
                {
                    { key, json }
                }
            });
        }

        // ---------------------------------------------------------------------
        // Folder Delta Sync (logging slightly improved only)
        // ---------------------------------------------------------------------

        private async Task SyncFolderAsync(GraphServiceClient graphClient, string userId, string folderId, string? deltaLink = null)
        {
            var corr = GetCorrelationId("SyncFolder");
            var sw = Stopwatch.StartNew();

            try
            {
                LogInfo(corr, nameof(SyncFolderAsync), "START", $"folderId='{SafeText(folderId, 80)}' userIdLen={(userId?.Length ?? 0)}");

                DeltaGetResponse? deltaResponse;

                if (!string.IsNullOrEmpty(deltaLink))
                {
                    LogInfo(corr, nameof(SyncFolderAsync), "DELTA", "Using existing deltaLink for incremental sync.");
                    deltaResponse = await graphClient.Users[userId]
                        .MailFolders[folderId]
                        .Messages
                        .Delta
                        .WithUrl(deltaLink)
                        .GetAsDeltaGetResponseAsync();
                }
                else
                {
                    LogInfo(corr, nameof(SyncFolderAsync), "DELTA", "No deltaLink. Initial sync.");
                    deltaResponse = await graphClient.Users[userId]
                        .MailFolders[folderId]
                        .Messages
                        .Delta
                        .GetAsDeltaGetResponseAsync(requestConfiguration =>
                        {
                            requestConfiguration.QueryParameters.Select = new[] { "id", "subject", "from", "toRecipients", "receivedDateTime" };
                        });
                }

                int page = 0;
                while (deltaResponse != null)
                {
                    page++;

                    var count = deltaResponse.Value?.Count ?? 0;
                    LogInfo(corr, nameof(SyncFolderAsync), "PAGE", $"page={page} items={count}");

                    if (!string.IsNullOrEmpty(deltaResponse.OdataNextLink))
                    {
                        deltaResponse = await graphClient.Users[userId]
                            .MailFolders[folderId]
                            .Messages
                            .Delta
                            .WithUrl(deltaResponse.OdataNextLink)
                            .GetAsDeltaGetResponseAsync();
                    }
                    else
                    {
                        LogInfo(corr, nameof(SyncFolderAsync), "END", $"Completed. totalElapsedMs={sw.ElapsedMilliseconds}");
                        break;
                    }
                }
            }
            catch (ServiceException ex)
            {
                LogError(corr, nameof(SyncFolderAsync), "GRAPH_ERR", DescribeGraphServiceException(ex), ex);
            }
            catch (Exception ex)
            {
                LogError(corr, nameof(SyncFolderAsync), "ERR", $"Unexpected error totalElapsedMs={sw.ElapsedMilliseconds}", ex);
            }
        }

        private static async Task<string> SafeReadBodySnippetAsync(HttpResponseMessage response, int maxChars)
        {
            try
            {
                var s = await response.Content.ReadAsStringAsync();
                return SafeText(s, maxChars);
            }
            catch
            {
                return "(unreadable body)";
            }
        }

        private static string? ResolveUserEmail(ClaimsPrincipal? user)
        {
            if (user == null) return null;

            static string? First(ClaimsPrincipal u, params string[] types)
            {
                foreach (var t in types)
                {
                    var v = u.FindFirst(t)?.Value;
                    if (!string.IsNullOrWhiteSpace(v)) return v;
                }
                return null;
            }

            return First(user,
                "preferred_username",
                "upn",
                "email",
                System.Security.Claims.ClaimTypes.Upn,
                System.Security.Claims.ClaimTypes.Email,
                "unique_name");
        }

        private static ClaimsPrincipal EnsureUserIdentityHasNameAndEmail(ClaimsPrincipal principal)
        {
            var email = ResolveUserEmail(principal);
            if (string.IsNullOrWhiteSpace(email))
                return principal;

            var identity = principal.Identity as ClaimsIdentity;
            if (identity == null)
                return principal;

            // Ensure we have common email/upn claims (Core/session code often expects these)
            if (principal.FindFirst("upn") == null)
                identity.AddClaim(new Claim("upn", email));

            if (principal.FindFirst("preferred_username") == null)
                identity.AddClaim(new Claim("preferred_username", email));

            if (principal.FindFirst(ClaimTypes.Email) == null)
                identity.AddClaim(new Claim(ClaimTypes.Email, email));

            // Ensure Identity.Name works too (in case any downstream code uses it)
            // NameClaimType could be something else; safest is to add a claim of that type.
            if (string.IsNullOrWhiteSpace(identity.Name))
                identity.AddClaim(new Claim(identity.NameClaimType, email));

            return principal;
        }

        private SaveToSharePointResponse Fail(
    string corr,
    string stage,
    string errorCode,
    string errorMessage,
    string fullUrl = "",
    string? graphRequestId = null,
    string? graphClientRequestId = null)
        {
            return new SaveToSharePointResponse
            {
                Status = "Failed",
                FullUrl = fullUrl ?? "",
                CorrelationId = corr,
                Stage = stage,
                ErrorCode = errorCode,
                ErrorMessage = errorMessage ?? "",
                GraphRequestId = graphRequestId ?? "",
                GraphClientRequestId = graphClientRequestId ?? ""
            };
        }

        private SaveToSharePointResponse Success(string corr, string fullUrl)
        {
            return new SaveToSharePointResponse
            {
                Status = "Success",
                FullUrl = fullUrl ?? "",
                CorrelationId = corr,
                Stage = "Complete"
            };
        }

        private SaveToSharePointResponse SuccessWithWarning(string corr, string fullUrl, string stage, string errorCode, string message)
        {
            return new SaveToSharePointResponse
            {
                Status = "UploadedWithWarnings",
                FullUrl = fullUrl ?? "",
                CorrelationId = corr,
                Stage = stage,
                ErrorCode = errorCode,
                ErrorMessage = message ?? ""
            };
        }
    }

    // Extension method (unchanged)
    public static class ClaimsPrincipalExtensions
    {
        public static string? GetPreferredUsername(this ClaimsPrincipal principal)
        {
            if (principal == null) return null;
            return principal.Claims.FirstOrDefault(c =>
                c.Type == "preferred_username" ||
                c.Type == "upn" ||
                c.Type == "email")?.Value;
        }
    }


}
