// ==============================
// FILE: CymBuild_Outlook_Addin/Pages/Index.razor.cs
// ==============================
using CymBuild_Outlook_Addin.Model;
using CymBuild_Outlook_Addin.Services;
using CymBuild_Outlook_Common.Dto;
using CymBuild_Outlook_Common.Helpers;
using CymBuild_Outlook_Common.Models;
using CymBuild_Outlook_Common.Models.SharePoint;
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Web;
using Microsoft.JSInterop;
using System.Diagnostics;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace CymBuild_Outlook_Addin.Pages
{
    public partial class Index : IAsyncDisposable
    {
        // ---------------- UI STATE ----------------
        private string currentSection = "details";
        private bool showInformationLogs = true;

        private List<ButtonConfig> buttonConfigurations = new()
        {
            new ButtonConfig { ItemType = "message", Section = "details", Label = "Filing" },
            new ButtonConfig { ItemType = "appointment", Section = "meetingInfo", Label = "Event" }
        };

        private List<RecordSearchResult> gridData = new();
        private IEnumerable<RecordSearchResult> selectedRecords = new List<RecordSearchResult>();

        private string searchString = string.Empty;
        private string emailDescription = string.Empty;
        private string? selectedFolderPath;
        private bool isGeneratingDescription = false;

        private bool moveToCymBuildFiled = false;
        private bool extractAttachments = false;

        private static string PWAUrl = "";
        private Dictionary<string, string> imageSources = new();

        // Filed records for this email
        private List<FilingRecordSearchResult> FiledRecords = new();

        // ---------------- JS / MAIL DATA ----------------
        public IJSObjectReference? JSModule { get; set; }
        private DotNetObjectReference<Index>? _dotNetRef;

        public MailRead? MailReadData { get; set; }

        public Mailbox MailboxInfo { get; set; } = new();
        public Dictionary<string, object> SettingsInfo { get; set; } = new();

        private bool isSharedMailbox;
        private string userEmail = string.Empty;
        private string mailboxOwnerEmail = string.Empty;

        // Token cache (short lived) - API token cache
        private string _cachedApiToken = string.Empty;
        private DateTime _cachedApiTokenUtc = DateTime.MinValue;

        // Optional: avoids huge/PII dumps
        private static readonly JsonSerializerOptions _jsonOpts = new(JsonSerializerDefaults.Web)
        {
            WriteIndented = false
        };

        //Used for the dropdown.
        private List<SharePointFolderDto> FilingFolders = new();

        private string FilingDirectionLabel => GetFilingDirectionLabel();

        private string FilingDirectionBadgeCss => FilingDirectionLabel switch
        {
            "Outgoing" => "cb-v2-badge-purple",
            "Incoming" => "cb-v2-badge-success",
            _ => "cb-v2-badge-muted"
        };

        private string EffectiveFilingFolderPath =>
            !string.IsNullOrWhiteSpace(selectedFolderPath)
                ? selectedFolderPath
                : "Default: Emails folder";

        private string EffectiveFilingFolderName =>
            !string.IsNullOrWhiteSpace(selectedFolderPath)
                ? FilingFolders.FirstOrDefault(x => x.Path == selectedFolderPath)?.Name ?? selectedFolderPath
                : "Emails";

        private string GetFilingDirectionLabel()
        {
            var sender = MailReadData?.Sender?.SenderEmail;

            if (string.IsNullOrWhiteSpace(sender))
                return "Unknown";

            var mailboxCandidates = new[]
            {
                userEmail,
                mailboxOwnerEmail,
                MailboxInfo?.UserProfile?.EmailAddress
            }
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct(StringComparer.OrdinalIgnoreCase);

            return mailboxCandidates.Any(x => string.Equals(x, sender, StringComparison.OrdinalIgnoreCase))
                ? "Outgoing"
                : "Incoming";
        }

        protected override void OnInitialized()
        {
            PWAUrl = Configuration.GetValue<string>("AzureAd:PostLogoutRedirectUri") ?? "";
            BuildImageSources();
        }

        private void BuildImageSources()
        {
            imageSources = new Dictionary<string, string>
            {
                { "SearchAndSelectRecords", $"{PWAUrl}/Images/SearchAndSelectRecords.png" },
                { "FileWithPreviousButton", $"{PWAUrl}/Images/FileWithPreviousButton.png" },
                { "DontFileButton", $"{PWAUrl}/Images/DontFileButton.png" },
                { "SearchBoxExample", $"{PWAUrl}/Images/SearchBoxExample.png" },
                { "SelectedRecordsExample", $"{PWAUrl}/Images/SelectedRecordsExample.png" },
                { "SaveToSharePointButton", $"{PWAUrl}/Images/SaveToSharePointButton.png" }
            };
        }

        protected override async Task OnInitializedAsync()
        {
            var corr = NewCorrelationId("init");
            var sw = Stopwatch.StartNew();

            try
            {
                LogInfo($"[{corr}] OnInitializedAsync START", "OnInitializedAsync");

                var entityTypes = await EntityTypeService.GetEntityTypesAsync();
                LogInfo($"[{corr}] EntityTypes loaded. Count={entityTypes?.Count() ?? 0} ElapsedMs={sw.ElapsedMilliseconds}", "OnInitializedAsync");
            }
            catch (Exception ex)
            {
                LogError($"[{corr}] Error Getting EntityTypes/EmailData ElapsedMs={sw.ElapsedMilliseconds}", ex, "OnInitializedAsync");
            }
            finally
            {
                LogInfo($"[{corr}] OnInitializedAsync END ElapsedMs={sw.ElapsedMilliseconds}", "OnInitializedAsync");
            }
        }

        protected override async Task OnAfterRenderAsync(bool firstRender)
        {
            if (!firstRender) return;

            var corr = NewCorrelationId("firstRender");
            var sw = Stopwatch.StartNew();

            LogInfo($"[{corr}] First Render: OnAfterRenderAsync START", "OnAfterRenderAsync");

            try
            {
                JSModule = await JSRuntime.InvokeAsync<IJSObjectReference>("import", "./Pages/Index.razor.js");
                LogInfo($"[{corr}] Index.razor.js imported successfully.", "OnAfterRenderAsync");
            }
            catch (Exception ex)
            {
                LogError($"[{corr}] Failed importing Index.razor.js", ex, "OnAfterRenderAsync");
                return;
            }

            try
            {
                await JSRuntime.InvokeVoidAsync("authenticateUser");
                LogInfo($"[{corr}] authenticateUser invoked successfully.", "OnAfterRenderAsync");
            }
            catch (Exception ex)
            {
                LogError($"[{corr}] authenticateUser failed", ex, "OnAfterRenderAsync");
                return;
            }

            try
            {
                _dotNetRef?.Dispose();
                _dotNetRef = DotNetObjectReference.Create(this);

                await JSModule.InvokeVoidAsync("getEmailData", _dotNetRef);
                LogInfo($"[{corr}] getEmailData invoked successfully.", "OnAfterRenderAsync");
            }
            catch (Exception ex)
            {
                LogError($"[{corr}] getEmailData invoke failed", ex, "OnAfterRenderAsync");
            }

            // Load settings after first render
            await LoadUserSettingsFromApiAsync();

            LogInfo($"[{corr}] OnAfterRenderAsync END ElapsedMs={sw.ElapsedMilliseconds}", "OnAfterRenderAsync");
        }

        /// <summary>
        /// Returns the folders available (including nested folders)
        /// </summary>
        /// <returns></returns>
        private async Task GetFoldersForFilingLocation()
        {
            var corr = NewCorrelationId("folders");
            var sw = Stopwatch.StartNew();

            try
            {
                LogInfo($"[{corr}] GetFoldersForFilingLocation START",
                    nameof(GetFoldersForFilingLocation));

                FilingFolders = new();

                var apiToken = await GetApiTokenAsync();

                if (string.IsNullOrWhiteSpace(apiToken))
                {
                    LogError($"[{corr}] Missing API token",
                        new Exception("Missing token"),
                        nameof(GetFoldersForFilingLocation));

                    await InvokeAsync(StateHasChanged);
                    return;
                }

                var selected = selectedRecords.FirstOrDefault();

                if (selected == null)
                {
                    LogInfo($"[{corr}] No selected record.",
                        nameof(GetFoldersForFilingLocation));

                    await InvokeAsync(StateHasChanged);
                    return;
                }

                var target = await TargetObjectService.GetTargetObjectAsync(selected.Guid);

                if (target == null)
                {
                    LogInfo($"[{corr}] No target object found for selectedGuid={selected.Guid}.",
                        nameof(GetFoldersForFilingLocation));

                    await InvokeAsync(StateHasChanged);
                    return;
                }

                if (string.IsNullOrWhiteSpace(target.FilingLocation))
                {
                    LogInfo($"[{corr}] No filing location for targetGuid={target.Guid}.",
                        nameof(GetFoldersForFilingLocation));

                    await InvokeAsync(StateHasChanged);
                    return;
                }

                List<string> values;

                try
                {
                    values = StringHelpers.ParseFolderLocation(target.FilingLocation) ?? new List<string>();
                }
                catch (Exception exParse)
                {
                    LogError(
                        $"[{corr}] Invalid filing location format for targetGuid={target.Guid}. valueLen={target.FilingLocation.Length}",
                        exParse,
                        nameof(GetFoldersForFilingLocation));

                    await InvokeAsync(StateHasChanged);
                    return;
                }

                if (values.Count != 2 ||
                    string.IsNullOrWhiteSpace(values[0]) ||
                    string.IsNullOrWhiteSpace(values[1]))
                {
                    LogInfo(
                        $"[{corr}] Invalid filing location for targetGuid={target.Guid}. parseCount={values.Count}",
                        nameof(GetFoldersForFilingLocation));

                    await InvokeAsync(StateHasChanged);
                    return;
                }

                var request = new
                {
                    SiteId = values[0],
                    RootFolderPath = values[1]
                };

                using var req = new HttpRequestMessage(
                    HttpMethod.Post,
                    "api/Graph/GetAllFoldersForLocation")
                {
                    Content = JsonContent.Create(request)
                };

                req.Headers.Authorization =
                    new AuthenticationHeaderValue("Bearer", apiToken);

                req.Headers.TryAddWithoutValidation("X-Correlation-Id", corr);

                var response = await Http.SendAsync(req);

                if (!response.IsSuccessStatusCode)
                {
                    var body = await SafeReadBodySnippetAsync(response, 1000);

                    LogError(
                        $"[{corr}] Folder API failed status={(int)response.StatusCode} body='{body}'",
                        new Exception("Folder API failed"),
                        nameof(GetFoldersForFilingLocation));

                    await InvokeAsync(StateHasChanged);
                    return;
                }

                FilingFolders =
                    await response.Content.ReadFromJsonAsync<List<SharePointFolderDto>>()
                    ?? new List<SharePointFolderDto>();

                LogInfo(
                    $"[{corr}] Loaded folders count={FilingFolders.Count} elapsedMs={sw.ElapsedMilliseconds}",
                    nameof(GetFoldersForFilingLocation));

                foreach (var folder in FilingFolders)
                {
                    LogInfo(
                        $"Folder Name='{folder.Name}' Id='{folder.Id}' ParentId='{folder.ParentId}'",
                        nameof(GetFoldersForFilingLocation));
                }

                await InvokeAsync(StateHasChanged);
            }
            catch (Exception ex)
            {
                LogError(
                    $"[{corr}] GetFoldersForFilingLocation FAILED elapsedMs={sw.ElapsedMilliseconds}",
                    ex,
                    nameof(GetFoldersForFilingLocation));

                FilingFolders = new();
                await InvokeAsync(StateHasChanged);
            }
        }

        // ---------------- GRID ----------------

        private RecordSearchResult? GetRecordDetails(int recordId)
            => gridData.FirstOrDefault(record => record.ID == recordId);
        private async Task HandleKeyPress(KeyboardEventArgs e)
        {
            if (e.Key == "Enter" || e.Key == "NumpadEnter")
                await RefreshSearch();
        }

        private void ShowSection(string section)
        {
            if (showInformationLogs)
                LogInfo($"Change Current Section Selected - {section}", "ShowSection");

            currentSection = section;
        }

        private async Task RefreshSearch()
        {
            var corr = NewCorrelationId("refreshSearch");
            LogInfo($"[{corr}] RefreshSearch START searchString='{SafeText(searchString, 80)}'", "RefreshSearch");

            await LoadGridDataAsync(corr);

            await JSRuntime.InvokeVoidAsync("CymBuildFunctions.refreshSearchAI");
            LogInfo($"[{corr}] RefreshSearch END", "RefreshSearch");
        }

        // overload adds correlation id so the whole action ties together
        private async Task LoadGridDataAsync(string? correlationId = null)
        {
            var corr = correlationId ?? NewCorrelationId("loadGrid");
            var sw = Stopwatch.StartNew();

            try
            {
                if (MailReadData == null)
                {
                    LogInfo($"[{corr}] LoadGridDataAsync early-exit: MailReadData is null", "LoadGridDataAsync");
                    return;
                }

                var msgInfo = DescribeMessageForLog(MailReadData.ItemId, MailReadData.Subject);

                LogInfo($"[{corr}] LoadGridDataAsync START {msgInfo}", "LoadGridDataAsync");

                // 1) Build text search
                var textSearch = string.IsNullOrEmpty(searchString)
                    ? (!string.IsNullOrEmpty(MailReadData.Subject) ? MailReadData.Subject : MailReadData.Body)
                    : searchString;

                LogInfo($"[{corr}] Search input resolved. textSearchLen={textSearch?.Length ?? 0} usingCustomSearch={!string.IsNullOrEmpty(searchString)}", "LoadGridDataAsync");

                // 2) RecordSearch
                var searchRequest = new RecordSearchDto
                {
                    UserId = -1,
                    SearchString = textSearch,
                    Subject = MailReadData.Subject,
                    FromAddress = MailReadData.Sender?.SenderEmail,
                    ToAddressesCSV = string.Join(",", MailReadData.ToRecipients.Select(r => r.Email)),
                    EntityTypeGuid = Guid.Empty,
                };

                var swSearch = Stopwatch.StartNew();
                gridData = await RecordSearchService.SearchRecordsAsync(searchRequest);
                swSearch.Stop();

                LogInfo($"[{corr}] RecordSearchService.SearchRecordsAsync OK. rows={gridData?.Count ?? 0} ElapsedMs={swSearch.ElapsedMilliseconds}", "LoadGridDataAsync");

                // 3) API token
                var swToken = Stopwatch.StartNew();
                var apiToken = await GetApiTokenAsync(forceRefresh: false);
                swToken.Stop();

                if (string.IsNullOrWhiteSpace(apiToken))
                {
                    LogError($"[{corr}] API token EMPTY after ElapsedMs={swToken.ElapsedMilliseconds}. FiledRecordSearch will be skipped.", new Exception("Empty API token"), "LoadGridDataAsync");
                    await InvokeAsync(StateHasChanged);
                    return;
                }

                LogInfo($"[{corr}] API token acquired OK. tokenLen={apiToken.Length} ElapsedMs={swToken.ElapsedMilliseconds}", "LoadGridDataAsync");

                // 4) FiledRecordSearch (HTTP)
                var encodedMessageId = Uri.EscapeDataString(MailReadData.ItemId ?? string.Empty);
                var url = $"api/FiledRecordSearch?messageId={encodedMessageId}";

                using var req = new HttpRequestMessage(HttpMethod.Get, url);
                req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiToken);

                // Correlate API logs with browser logs (if server logs X-Correlation-Id)
                req.Headers.TryAddWithoutValidation("X-Correlation-Id", corr);

                LogInfo($"[{corr}] Calling FiledRecordSearch GET {TrimQueryForLog(url)}", "LoadGridDataAsync");

                var swHttp = Stopwatch.StartNew();
                HttpResponseMessage response;

                try
                {
                    response = await Http.SendAsync(req);
                }
                catch (Exception exHttp)
                {
                    swHttp.Stop();
                    LogError($"[{corr}] FiledRecordSearch HTTP SEND FAILED after ElapsedMs={swHttp.ElapsedMilliseconds}. {msgInfo}", exHttp, "LoadGridDataAsync");
                    await InvokeAsync(StateHasChanged);
                    return;
                }

                swHttp.Stop();

                var status = (int)response.StatusCode;
                LogInfo($"[{corr}] FiledRecordSearch HTTP response. status={status} reason='{response.ReasonPhrase}' ElapsedMs={swHttp.ElapsedMilliseconds}", "LoadGridDataAsync");

                if (!response.IsSuccessStatusCode)
                {
                    var bodySnippet = await SafeReadBodySnippetAsync(response, 1200);
                    LogError(
                        $"[{corr}] FiledRecordSearch FAILED status={status} reason='{response.ReasonPhrase}' body='{bodySnippet}' {msgInfo}",
                        new Exception($"HTTP {status} from FiledRecordSearch"),
                        "LoadGridDataAsync");

                    await InvokeAsync(StateHasChanged);
                    return;
                }

                // 5) Deserialize
                var swJson = Stopwatch.StartNew();
                List<FilingRecordSearchResult>? filedRecords = null;

                try
                {
                    filedRecords = await response.Content.ReadFromJsonAsync<List<FilingRecordSearchResult>>(_jsonOpts);
                }
                catch (Exception exJson)
                {
                    swJson.Stop();
                    var bodySnippet = await SafeReadBodySnippetAsync(response, 1200);
                    LogError($"[{corr}] FiledRecordSearch JSON DESERIALIZE FAILED ElapsedMs={swJson.ElapsedMilliseconds} body='{bodySnippet}'", exJson, "LoadGridDataAsync");
                    await InvokeAsync(StateHasChanged);
                    return;
                }

                swJson.Stop();

                FiledRecords = filedRecords ?? new List<FilingRecordSearchResult>();
                LogInfo($"[{corr}] FiledRecordSearch JSON OK. FiledRecords={FiledRecords.Count} ElapsedMs={swJson.ElapsedMilliseconds}", "LoadGridDataAsync");

                await InvokeAsync(StateHasChanged);
            }
            catch (Exception ex)
            {
                LogError($"[{corr}] Error Loading GridData ElapsedMs={sw.ElapsedMilliseconds}", ex, "LoadGridDataAsync");
            }
            finally
            {
                LogInfo($"[{corr}] LoadGridDataAsync END ElapsedMs={sw.ElapsedMilliseconds}", "LoadGridDataAsync");
            }
        }

        private async Task OnRecordClick(RecordSearchResult record)
        {
            if (record == null || selectedRecords.Any(r => r.ID == record.ID))
                return;

            selectedRecords = selectedRecords.Append(record).ToList();

            // Get the folders in the background after the record has been selected.
            await GetFoldersForFilingLocation();
        }
        private void RemoveSelectedItem(RecordSearchResult record)
                    => selectedRecords = selectedRecords.Where(r => r.ID != record.ID).ToList();

        private async Task SaveSelectedRecordsToLocalStorage()
        {
            var corr = NewCorrelationId("saveSelected");
            try
            {
                var json = JsonSerializer.Serialize(selectedRecords, _jsonOpts);
                await JSRuntime.InvokeVoidAsync("localStorage.setItem", "selectedRecords", json);
                LogInfo($"[{corr}] Saved selectedRecords to localStorage. Count={selectedRecords?.Count() ?? 0}", "SaveSelectedRecordsToLocalStorage");
            }
            catch (Exception ex)
            {
                LogError($"[{corr}] Error saving selected records to local storage.", ex, "SaveSelectedRecordsToLocalStorage");
            }
        }

        private async Task LoadSelectedRecordsFromLocalStorage()
        {
            var corr = NewCorrelationId("loadSelected");
            try
            {
                var json = await JSRuntime.InvokeAsync<string>("localStorage.getItem", "selectedRecords");
                if (!string.IsNullOrEmpty(json))
                {
                    selectedRecords = JsonSerializer.Deserialize<List<RecordSearchResult>>(json, _jsonOpts) ?? new List<RecordSearchResult>();
                    LogInfo($"[{corr}] Loaded selectedRecords from localStorage. Count={selectedRecords?.Count() ?? 0}", "LoadSelectedRecordsFromLocalStorage");
                }
                else
                {
                    LogInfo($"[{corr}] localStorage selectedRecords is empty.", "LoadSelectedRecordsFromLocalStorage");
                }
            }
            catch (Exception ex)
            {
                LogError($"[{corr}] Error loading selected records from local storage.", ex, "LoadSelectedRecordsFromLocalStorage");
            }
        }

        private async Task FileWithPreviousAsync()
            => await LoadSelectedRecordsFromLocalStorage();

        private async Task GenerateDescriptionAsync()
        {
            var corr = NewCorrelationId("genDesc");
            isGeneratingDescription = true;
            await InvokeAsync(StateHasChanged);

            try
            {
                LogInfo($"[{corr}] Generating AI description...", "GenerateDescription");

                var apiToken = await GetApiTokenAsync(forceRefresh: false);
                if (string.IsNullOrWhiteSpace(apiToken))
                {
                    LogError($"[{corr}] Cannot generate: no API token",
                             new Exception("Empty token"), "GenerateDescription");
                    emailDescription = "Failed to generate: authentication error";
                    return;
                }

                if (MailReadData == null)
                {
                    LogInfo($"[{corr}] Cannot generate: MailReadData is null", "GenerateDescription");
                    emailDescription = "Failed to generate: no email data";
                    return;
                }

                var description = await EmailDescriptionService.GenerateDescriptionAsync(
                    MailReadData.Subject ?? string.Empty,
                    MailReadData.Body ?? string.Empty,
                    apiToken);

                emailDescription = description;
                LogInfo($"[{corr}] AI description generated successfully. Length={description.Length}", "GenerateDescription");
            }
            catch (Exception ex)
            {
                LogError($"[{corr}] Failed to generate description", ex, "GenerateDescription");
                emailDescription = "An error occurred while generating description";
            }
            finally
            {
                isGeneratingDescription = false;
                await InvokeAsync(StateHasChanged);
            }
        }

        // ---------------- SETTINGS (API) ----------------

        private async Task LoadUserSettingsFromApiAsync()
        {
            var corr = NewCorrelationId("loadSettings");

            for (int attempt = 1; attempt <= 3; attempt++)
            {
                var sw = Stopwatch.StartNew();

                try
                {
                    LogInfo($"[{corr}] LoadUserSettings attempt {attempt} START", "LoadUserSettingsFromApiAsync");

                    var apiToken = await GetApiTokenAsync(forceRefresh: attempt > 1);
                    if (string.IsNullOrWhiteSpace(apiToken))
                    {
                        LogError($"[{corr}] attempt {attempt}: API token empty", new Exception("Empty API token"), "LoadUserSettingsFromApiAsync");
                        await Task.Delay(750);
                        continue;
                    }

                    using var req = new HttpRequestMessage(HttpMethod.Get, "api/UserSettings");
                    req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiToken);
                    req.Headers.TryAddWithoutValidation("X-Correlation-Id", corr);
                    req.Headers.Add("X-user-email", userEmail);



                    var res = await Http.SendAsync(req);

                    LogInfo($"[{corr}] attempt {attempt}: UserSettings status={(int)res.StatusCode} reason='{res.ReasonPhrase}' ElapsedMs={sw.ElapsedMilliseconds}", "LoadUserSettingsFromApiAsync");

                    if (!res.IsSuccessStatusCode)
                    {
                        var bodySnippet = await SafeReadBodySnippetAsync(res, 1200);
                        LogError($"[{corr}] attempt {attempt}: UserSettings failed. body='{bodySnippet}'", new Exception($"HTTP {(int)res.StatusCode}"), "LoadUserSettingsFromApiAsync");
                        await Task.Delay(750);
                        continue;
                    }

                    var settings = await res.Content.ReadFromJsonAsync<UserSettingsDto>(_jsonOpts);
                    if (settings == null)
                    {
                        LogError($"[{corr}] attempt {attempt}: settings JSON null", new Exception("settings==null"), "LoadUserSettingsFromApiAsync");
                        return;
                    }

                    LogInfo(
                            $"LoadUserSettingsFromApiAsync() => Settings: " +
                            JsonSerializer.Serialize(settings, new JsonSerializerOptions
                            {
                                WriteIndented = true
                            }), "LoadUserSettingsFromApiAsync");


                    Console.WriteLine("Extracting moveToCymBuildFiled & extractAttachments");

                    moveToCymBuildFiled = settings.MoveToCymBuildFiled;
                    extractAttachments = settings.ExtractAttachments;

                    Console.WriteLine($"moveToCymBuildFiled = {moveToCymBuildFiled}, extractAttachments = {extractAttachments}");


                    LogInfo($"[{corr}] Settings applied. moveToCymBuildFiled={moveToCymBuildFiled} extractAttachments={extractAttachments}", "LoadUserSettingsFromApiAsync");

                    StateHasChanged();
                    return;
                }
                catch (Exception ex)
                {
                    LogError($"[{corr}] Attempt {attempt}: Failed to retrieve user settings (API). ElapsedMs={sw.ElapsedMilliseconds}", ex, "LoadUserSettingsFromApiAsync");
                    await Task.Delay(750);
                }
            }
        }

        private async Task SaveSettings()
        {
            var corr = NewCorrelationId("saveSettings");
            var sw = Stopwatch.StartNew();

            try
            {
                var apiToken = await GetApiTokenAsync(forceRefresh: false);
                if (string.IsNullOrWhiteSpace(apiToken))
                {
                    LogError($"[{corr}] Unable to acquire API token to save settings.", new Exception("Missing API token"), "SaveSettings");
                    await JSRuntime.InvokeVoidAsync("showNotification", "Unable to acquire API token to save settings.");
                    return;
                }

                var payload = new Dictionary<string, object>
                {
                    { "moveToCymBuildFiled", moveToCymBuildFiled },
                    { "extractAttachments", extractAttachments },
                    { "UserId", userEmail }
                };

                using var req = new HttpRequestMessage(HttpMethod.Post, "api/UserSettings")
                {
                    Content = JsonContent.Create(payload)
                };
                req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiToken);
                req.Headers.TryAddWithoutValidation("X-Correlation-Id", corr);

                var res = await Http.SendAsync(req);

                if (!res.IsSuccessStatusCode)
                {
                    var bodySnippet = await SafeReadBodySnippetAsync(res, 1200);
                    LogError($"[{corr}] SaveSettings failed status={(int)res.StatusCode} reason='{res.ReasonPhrase}' body='{bodySnippet}' ElapsedMs={sw.ElapsedMilliseconds}",
                        new Exception("API save settings failed"),
                        "SaveSettings");
                    await JSRuntime.InvokeVoidAsync("showNotification", "Failed to save settings.");
                    return;
                }

                LogInfo($"[{corr}] Settings saved successfully (API). ElapsedMs={sw.ElapsedMilliseconds}", "SaveSettings");
                await JSRuntime.InvokeVoidAsync("showNotification", "Settings saved successfully.");
            }
            catch (Exception ex)
            {
                LogError($"[{corr}] Error saving settings (API). ElapsedMs={sw.ElapsedMilliseconds}", ex, "SaveSettings");
                await JSRuntime.InvokeVoidAsync("showNotification", "Error saving settings.");
            }
        }

        // ---------------- TOKEN (API audience) ----------------

        private async Task<string> GetApiTokenAsync(bool forceRefresh = false)
        {
            // short-lived cache
            if (!forceRefresh &&
                !string.IsNullOrWhiteSpace(_cachedApiToken) &&
                (DateTime.UtcNow - _cachedApiTokenUtc) < TimeSpan.FromMinutes(3))
            {
                return _cachedApiToken;
            }

            var corr = NewCorrelationId("token");
            var sw = Stopwatch.StartNew();

            try
            {
                LogInfo($"[{corr}] GetApiTokenAsync START forceRefresh={forceRefresh}", "GetApiTokenAsync");

                //// Office SSO token)
                //var token = await JSRuntime.InvokeAsync<string>("getGraphAccessToken", new { forceRefresh });
                // Office SSO token
                var token = await JSRuntime.InvokeAsync<string>("getSsoToken", new { forceRefresh });

                if (string.IsNullOrWhiteSpace(token))
                {
                    LogError($"[{corr}] GetApiTokenAsync returned EMPTY token ElapsedMs={sw.ElapsedMilliseconds}", new Exception("Empty token"), "GetApiTokenAsync");
                    return string.Empty;
                }

                CacheApiToken(token);
                LogInfo($"[{corr}] GetApiTokenAsync OK tokenLen={token.Length} ElapsedMs={sw.ElapsedMilliseconds}", "GetApiTokenAsync");
                return token;
            }
            catch (Exception ex)
            {
                LogError($"[{corr}] GetApiTokenAsync FAILED ElapsedMs={sw.ElapsedMilliseconds}", ex, "GetApiTokenAsync");
                return string.Empty;
            }
        }

        private void CacheApiToken(string token)
        {
            _cachedApiToken = token;
            _cachedApiTokenUtc = DateTime.UtcNow;
        }

        // ---------------- JS CALLBACKS ----------------

        [JSInvokable]
        public async Task ReceiveEmailData(MailRead data)
        {
            var corr = NewCorrelationId("email");
            var sw = Stopwatch.StartNew();

            if (data == null)
            {
                LogInfo($"[{corr}] ReceiveEmailData called with null data. EXIT.", "ReceiveEmailData");
                return;
            }

            MailReadData = data;
            LogInfo($"[{corr}] ReceiveEmailData START {DescribeMessageForLog(MailReadData.ItemId, MailReadData.Subject)}", "ReceiveEmailData");

            try
            {
                var apiToken = await GetApiTokenAsync(forceRefresh: false);
                if (string.IsNullOrWhiteSpace(apiToken))
                {
                    LogError($"[{corr}] Unable to acquire API token during ReceiveEmailData", new Exception("Missing API token"), "ReceiveEmailData");
                    return;
                }

                await DetectSharedMailbox();

                // Translate IDs via API (OBO server-side)
                try
                {
                    var translate = await GraphService.TranslateExchangeIdsAsync(
                        new List<string> { MailReadData.ItemId },
                        "restId",
                        "restImmutableEntryId",
                        apiToken,
                        isSharedMailbox ? mailboxOwnerEmail : null
                    );

                    var firstTargetId = translate?.FirstOrDefault(x => !string.IsNullOrEmpty(x.TargetId))?.TargetId;
                    if (!string.IsNullOrWhiteSpace(firstTargetId))
                    {
                        LogInfo($"[{corr}] TranslateExchangeIdsAsync OK. Updated ItemId. old={SafeTextHash(MailReadData.ItemId)} new={SafeTextHash(firstTargetId)}", "ReceiveEmailData");
                        MailReadData.ItemId = firstTargetId;
                    }
                    else
                    {
                        LogInfo($"[{corr}] TranslateExchangeIdsAsync returned no TargetId. Continuing.", "ReceiveEmailData");
                    }
                }
                catch (Exception exTranslate)
                {
                    LogError($"[{corr}] TranslateExchangeIdsAsync failed. Continuing without translation.", exTranslate, "ReceiveEmailData");
                }

                // Load custom properties via API
                try
                {
                    var customPropertiesData = await GraphService.GetEmailDataAsync(MailReadData.ItemId, apiToken);
                    if (customPropertiesData?.CustomProperties != null)
                    {
                        MailReadData.CustomProperties = customPropertiesData.CustomProperties;
                        LogInfo($"[{corr}] GetEmailDataAsync OK. customProps={customPropertiesData.CustomProperties.Count}", "ReceiveEmailData");
                    }
                    else
                    {
                        LogInfo($"[{corr}] GetEmailDataAsync OK but CustomProperties null/empty.", "ReceiveEmailData");
                    }
                }
                catch (Exception exProps)
                {
                    LogError($"[{corr}] GetEmailDataAsync failed.", exProps, "ReceiveEmailData");
                }
            }
            catch (Exception ex)
            {
                LogError($"[{corr}] Error during email processing", ex, "ReceiveEmailData");
            }

            SetInitialSection();

            await LoadGridDataAsync(corr);

            StateHasChanged();
            LogInfo($"[{corr}] ReceiveEmailData END ElapsedMs={sw.ElapsedMilliseconds}", "ReceiveEmailData");
        }

        [JSInvokable]
        public void ReceiveMailboxAndSettingsData(CombinedInfo combinedInfo)
        {
            MailboxInfo = combinedInfo.MailboxInfo;
            SettingsInfo = combinedInfo.SettingsInfo;

            mailboxOwnerEmail = MailboxInfo?.UserProfile?.EmailAddress ?? mailboxOwnerEmail;
            if (string.IsNullOrWhiteSpace(userEmail))
                userEmail = mailboxOwnerEmail;

            StateHasChanged();
        }

        private void SetInitialSection()
        {
            var config = buttonConfigurations.FirstOrDefault(c => MailReadData?.ItemType == c.ItemType);
            currentSection = config?.Section ?? "info";
        }

        private async Task<bool> DetectSharedMailbox()
        {
            var corr = NewCorrelationId("sharedMailbox");
            try
            {
                JSModule ??= await JSRuntime.InvokeAsync<IJSObjectReference>("import", "./Pages/Index.razor.js");

                var sharedProps = await JSModule.InvokeAsync<SharedProperties>("checkSharedMailbox");
                if (sharedProps != null && !string.IsNullOrWhiteSpace(sharedProps.Owner))
                {
                    mailboxOwnerEmail = sharedProps.Owner;

                    var primary = MailboxInfo?.UserProfile?.EmailAddress ?? userEmail;
                    isSharedMailbox = !string.IsNullOrWhiteSpace(primary) &&
                                     !mailboxOwnerEmail.Equals(primary, StringComparison.OrdinalIgnoreCase);

                    LogInfo($"[{corr}] Shared mailbox detection: owner='{SafeText(mailboxOwnerEmail, 80)}' primary='{SafeText(primary, 80)}' isShared={isSharedMailbox}", "DetectSharedMailbox");
                    return true;
                }
            }
            catch (Exception ex)
            {
                LogError($"[{corr}] Failed to detect shared mailbox", ex, "DetectSharedMailbox");
            }

            mailboxOwnerEmail = MailboxInfo?.UserProfile?.EmailAddress ?? userEmail;
            isSharedMailbox = false;
            LogInfo($"[{corr}] Shared mailbox detection fallback. owner='{SafeText(mailboxOwnerEmail, 80)}' isShared=false", "DetectSharedMailbox");
            return false;
        }

        // ---------------- SAVE TO SHAREPOINT ----------------
        // Restored + enhanced logging (correlation + timings + safe/PII-limited output)

        private async Task SaveEmailToSharePointAsync()
        {
            var corr = NewCorrelationId("saveSP");
            var sw = Stopwatch.StartNew();

            try
            {
                if (MailReadData == null || string.IsNullOrWhiteSpace(MailReadData.ItemId) || !selectedRecords.Any())
                {
                    LogError(
                        $"[{corr}] SaveEmailToSharePointAsync guard failed. mailNull={(MailReadData == null)} itemIdEmpty={string.IsNullOrWhiteSpace(MailReadData?.ItemId)} selectedCount={selectedRecords?.Count() ?? 0}",
                        new Exception("No email data or selected records."),
                        "SaveEmailToSharePointAsync");

                    return;
                }

                LogInfo(
                    $"[{corr}] SaveEmailToSharePointAsync START {DescribeMessageForLog(MailReadData.ItemId, MailReadData.Subject)} selectedCount={selectedRecords.Count()}",
                    "SaveEmailToSharePointAsync");

                try
                {
                    await JSRuntime.InvokeVoidAsync("authenticateUser");
                    LogInfo($"[{corr}] authenticateUser OK", "SaveEmailToSharePointAsync");
                }
                catch (Exception exAuth)
                {
                    LogError($"[{corr}] authenticateUser FAILED", exAuth, "SaveEmailToSharePointAsync");
                    return;
                }

                var swToken = Stopwatch.StartNew();
                var apiToken = await GetApiTokenAsync(forceRefresh: false);
                swToken.Stop();

                if (string.IsNullOrWhiteSpace(apiToken))
                {
                    LogError(
                        $"[{corr}] Unable to acquire API token during SaveEmailToSharePointAsync. ElapsedMs={swToken.ElapsedMilliseconds}",
                        new Exception("Missing API token"),
                        "SaveEmailToSharePointAsync");

                    return;
                }

                LogInfo(
                    $"[{corr}] API token OK tokenLen={apiToken.Length} ElapsedMs={swToken.ElapsedMilliseconds}",
                    "SaveEmailToSharePointAsync");

                await DetectSharedMailbox();

                var swTargets = Stopwatch.StartNew();
                var targetObjects = new List<TargetObject>();

                foreach (var record in selectedRecords.OrderBy(x => x.EntityTypeName))
                {
                    try
                    {
                        var target = await TargetObjectService.GetTargetObjectAsync(record.Guid);

                        if (target != null)
                        {
                            targetObjects.Add(target);
                        }
                        else
                        {
                            LogInfo(
                                $"[{corr}] TargetObjectService returned null for recordGuid={record.Guid}",
                                "SaveEmailToSharePointAsync");
                        }
                    }
                    catch (Exception exTarget)
                    {
                        LogError(
                            $"[{corr}] Failed fetching TargetObject for recordGuid={record.Guid}",
                            exTarget,
                            "SaveEmailToSharePointAsync");
                    }
                }

                swTargets.Stop();

                LogInfo(
                    $"[{corr}] TargetObjects loaded. Count={targetObjects.Count} ElapsedMs={swTargets.ElapsedMilliseconds}",
                    "SaveEmailToSharePointAsync");

                if (targetObjects.Count == 0)
                {
                    LogInfo($"[{corr}] No TargetObjects found. EXIT.", "SaveEmailToSharePointAsync");
                    return;
                }

                var swTypes = Stopwatch.StartNew();
                var entityTypes = await EntityTypeService.GetEntityTypesAsync();
                swTypes.Stop();

                LogInfo(
                    $"[{corr}] EntityTypes loaded for mapping. Count={entityTypes?.Count() ?? 0} ElapsedMs={swTypes.ElapsedMilliseconds}",
                    "SaveEmailToSharePointAsync");

                var requests = new List<SaveToSharePointRequest>();
                var totalCount = targetObjects.Count;

                foreach (var target in targetObjects)
                {
                    try
                    {
                        if (string.IsNullOrWhiteSpace(target.FilingLocation))
                        {
                            LogInfo(
                                $"[{corr}] Skipping targetGuid={target.Guid} - FilingLocation is null or empty.",
                                "SaveEmailToSharePointAsync");

                            continue;
                        }

                        List<string> folderLocationValues;

                        try
                        {
                            folderLocationValues = StringHelpers.ParseFolderLocation(target.FilingLocation) ?? new List<string>();
                        }
                        catch (Exception exParse)
                        {
                            LogError(
                                $"[{corr}] Skipping targetGuid={target.Guid} - FilingLocation parse failed. valueLen={target.FilingLocation.Length}",
                                exParse,
                                "SaveEmailToSharePointAsync");

                            continue;
                        }

                        if (folderLocationValues.Count != 2 ||
                            string.IsNullOrWhiteSpace(folderLocationValues[0]) ||
                            string.IsNullOrWhiteSpace(folderLocationValues[1]))
                        {
                            LogInfo(
                                $"[{corr}] Skipping targetGuid={target.Guid} - FilingLocation parse count={folderLocationValues.Count}",
                                "SaveEmailToSharePointAsync");

                            continue;
                        }

                        var selectedRecord = selectedRecords.FirstOrDefault(z => z.Guid == target.Guid);

                        if (selectedRecord == null)
                        {
                            LogInfo(
                                $"[{corr}] Skipping targetGuid={target.Guid} - selectedRecord not found.",
                                "SaveEmailToSharePointAsync");

                            continue;
                        }

                        var entityType = entityTypes?.FirstOrDefault(x => x.Name == selectedRecord.EntityTypeName);

                        requests.Add(new SaveToSharePointRequest
                        {
                            AuthToken = string.Empty,
                            MessageId = MailReadData.ItemId,
                            SharePointSiteId = folderLocationValues[0],
                            SharePointFolderId = !string.IsNullOrWhiteSpace(selectedFolderPath)
                                ? selectedFolderPath
                                : folderLocationValues[1],
                            UserId = isSharedMailbox ? mailboxOwnerEmail : userEmail,
                            TargetObjectGuid = target.Guid,
                            EntityTypeGuid = entityType?.Guid ?? Guid.Empty,
                            DoNotFile = false,
                            SubFolder = !string.IsNullOrWhiteSpace(selectedFolderPath)
                                ? string.Empty
                                : "Emails",
                            ProcessedCount = requests.Count + 1,
                            TotalCount = totalCount,
                            RecordSearchResults = selectedRecords,
                            MoveToCymBuildFiled = moveToCymBuildFiled,
                            ExtractAttachments = extractAttachments,
                            Description = emailDescription
                        });
                    }
                    catch (Exception exRequest)
                    {
                        LogError(
                            $"[{corr}] Error building SaveToSharePointRequest for targetGuid={target.Guid}",
                            exRequest,
                            "SaveEmailToSharePointAsync");
                    }
                }

                if (requests.Count == 0)
                {
                    LogInfo($"[{corr}] No requests built. All targets skipped. EXIT.", "SaveEmailToSharePointAsync");
                    return;
                }

                LogInfo(
                    $"[{corr}] Built requests. Count={requests.Count} totalCount={totalCount} " +
                    $"userId='{SafeText(isSharedMailbox ? mailboxOwnerEmail : userEmail, 80)}' isShared={isSharedMailbox} " +
                    $"moveToFiled={moveToCymBuildFiled} extractAttachments={extractAttachments} selectedFolderPath='{SafeText(selectedFolderPath, 220)}'",
                    "SaveEmailToSharePointAsync");

                var swCall = Stopwatch.StartNew();

                try
                {
                    await GraphService.SaveMultipleToSharePointAsync(requests, apiToken, corr);
                }
                catch (Exception exCall)
                {
                    swCall.Stop();

                    LogError(
                        $"[{corr}] GraphService.SaveMultipleToSharePointAsync FAILED ElapsedMs={swCall.ElapsedMilliseconds}",
                        exCall,
                        "SaveEmailToSharePointAsync");

                    return;
                }

                swCall.Stop();

                LogInfo(
                    $"[{corr}] GraphService.SaveMultipleToSharePointAsync OK ElapsedMs={swCall.ElapsedMilliseconds}",
                    "SaveEmailToSharePointAsync");

                await JSRuntime.InvokeVoidAsync(
                    "showNotification",
                    "The Emails selected are preparing to be filed. You may now continue.");

                emailDescription = string.Empty;

                _ = SaveSelectedRecordsToLocalStorage();

                LogInfo(
                    $"[{corr}] SaveEmailToSharePointAsync END ElapsedMs={sw.ElapsedMilliseconds}",
                    "SaveEmailToSharePointAsync");
            }
            catch (Exception ex)
            {
                LogError(
                    $"[{corr}] An unexpected error occurred ElapsedMs={sw.ElapsedMilliseconds}",
                    ex,
                    "SaveEmailToSharePointAsync");
            }
        }

        // ---------------- DTOs ----------------

        private class ButtonConfig
        {
            public string ItemType { get; set; } = "";
            public string Section { get; set; } = "";
            public string Label { get; set; } = "";
        }

        public class SharedProperties
        {
            public string Owner { get; set; } = "";
            public string DelegatePermissions { get; set; } = "";
        }

        public class CombinedInfo
        {
            public Mailbox MailboxInfo { get; set; } = new();
            public Dictionary<string, object> SettingsInfo { get; set; } = new();
        }

        // ---------------- DISPOSE ----------------

        public async ValueTask DisposeAsync()
        {
            try
            {
                _dotNetRef?.Dispose();
                _dotNetRef = null;

                if (JSModule != null)
                {
                    await JSModule.DisposeAsync();
                    JSModule = null;
                }
            }
            catch
            {
                // ignore dispose errors
            }
        }

        // =====================================================================
        // Logging helpers (keeps your existing LoggingHelper API)
        // =====================================================================

        private void LogInfo(string message, string member)
        {
            if (!showInformationLogs) return;
            LoggingHelper.LogInfo(message, $"{member}()");
        }

        private void LogError(string message, Exception ex, string member)
        {
            LoggingHelper.LogError(message, ex, $"{member}()");
        }

        private static string NewCorrelationId(string prefix)
            => $"{prefix}-{DateTime.UtcNow:HHmmss}-{Guid.NewGuid():N}".Substring(0, Math.Min(32, $"{prefix}-{DateTime.UtcNow:HHmmss}-{Guid.NewGuid():N}".Length));

        private static string SafeText(string? s, int max)
        {
            if (string.IsNullOrWhiteSpace(s)) return "";
            s = s.Replace("\r", " ").Replace("\n", " ").Trim();
            return s.Length <= max ? s : s.Substring(0, max) + "…";
        }

        private static string DescribeMessageForLog(string? messageId, string? subject)
        {
            return $"msgId={SafeTextHash(messageId)} msgIdLen={(messageId?.Length ?? 0)} subj='{SafeText(subject, 80)}'";
        }

        private static string SafeTextHash(string? s)
        {
            if (string.IsNullOrEmpty(s)) return "(empty)";
            using var sha = SHA256.Create();
            var bytes = sha.ComputeHash(Encoding.UTF8.GetBytes(s));
            return Convert.ToHexString(bytes).Substring(0, 10).ToLowerInvariant();
        }

        private static string TrimQueryForLog(string url)
        {
            var idx = url.IndexOf('?');
            if (idx < 0) return url;

            var path = url.Substring(0, idx);
            var qs = url.Substring(idx + 1);

            var keys = qs.Split('&', StringSplitOptions.RemoveEmptyEntries)
                         .Select(p => p.Split('=')[0])
                         .Distinct();

            return $"{path}?{string.Join("&", keys.Select(k => $"{k}=…"))}";
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
    }
}
