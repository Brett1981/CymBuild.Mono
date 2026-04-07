using CymBuild_Outlook_Common.Models.SharePoint;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;
using Microsoft.Graph;
using System.IO.Compression;
using System.Text;

namespace CymBuild_Outlook_API.Helpers
{
    public class WordDocumentService : IDisposable
    {
        #region Private Fields

        private const string SiteId = "environmentalscientifics.sharepoint.com,405ced4f-6a48-4c59-a6fc-f03f9adc3626,39e2f733-4aff-4568-a053-52dacbe1f03e";
        private readonly GraphServiceClient graphServiceClient;
        private bool disposed;

        #endregion Private Fields

        #region Constructor

        public WordDocumentService(GraphServiceClient graphServiceClient)
        {
            this.graphServiceClient = graphServiceClient;
        }

        #endregion Constructor

        #region Public Methods

        public async Task<SharepointDocumentsGetResponse> DownloadAndModifyDocument(string siteId, string driveId,
            string FilenameTemplate, string targetSharePointUrl, string itemId,
            List<Dictionary<string, string>> mergeFields)
        {
            var documentContent = await DownloadDocumentContent(driveId, itemId);
            return await PerformMailMerge(siteId, driveId, targetSharePointUrl, FilenameTemplate, itemId, documentContent, mergeFields);
        }

        public async Task<SharepointDocumentsGetResponse> DownloadDriveItem(string parentDriveId, string driveItemId)
        {
            try
            {
                var driveItemInfo = await graphServiceClient.Drives[parentDriveId].Items[driveItemId].GetAsync();
                if (driveItemInfo != null && driveItemInfo.AdditionalData.TryGetValue("@microsoft.graph.downloadUrl", out var downloadUrl))
                {
                    using var httpClient = new HttpClient();
                    var response = await httpClient.GetAsync(downloadUrl.ToString());

                    if (response.IsSuccessStatusCode)
                    {
                        return new SharepointDocumentsGetResponse
                        {
                            DriveItem = Converters.ConvertMicrosoftGraphDriveItemToCoreDriveItem(driveItemInfo, parentDriveId),
                            DownloadUrl = downloadUrl.ToString(),
                        };
                    }

                    throw new Exception($"Request failed with status code {response.StatusCode}. Reason: {response.ReasonPhrase}");
                }

                throw new Exception("Download URL not available.");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
                return new SharepointDocumentsGetResponse();
            }
        }

        public string ExtractContentFromZip(Stream zipStream)
        {
            using var archive = new ZipArchive(zipStream, ZipArchiveMode.Read);
            var entry = archive.Entries.FirstOrDefault();
            if (entry == null) return "";
            using var entryStream = entry.Open();
            using var reader = new StreamReader(entryStream, Encoding.UTF8);
            return reader.ReadToEnd();
        }

        #endregion Public Methods

        #region Private Methods

        private static string ExtractFieldName(string mergeFieldText)
        {
            int start = mergeFieldText.IndexOf("MERGEFIELD") + "MERGEFIELD".Length;
            int end = mergeFieldText.IndexOf("\\* MERGEFORMAT");
            if (start >= "MERGEFIELD".Length && end > start)
            {
                return mergeFieldText.Substring(start, end - start).Trim();
            }

            return string.Empty;
        }

        private static void ReplaceMergeFieldsInDocument(Stream documentStream, List<Dictionary<string, string>> mergeValues)
        {
            using var doc = WordprocessingDocument.Open(documentStream, true);

            if (doc.MainDocumentPart is null)
                return;

            ReplaceFieldsInPart(doc.MainDocumentPart, mergeValues);

            foreach (var headerPart in doc.MainDocumentPart.HeaderParts)
                ReplaceFieldsInPart(headerPart, mergeValues);

            foreach (var footerPart in doc.MainDocumentPart.FooterParts)
                ReplaceFieldsInPart(footerPart, mergeValues);

            doc.Save();
        }

        private static void ReplaceFieldsInPart(OpenXmlPart part, List<Dictionary<string, string>> mergeValuesList)
        {
            try
            {
                var fieldCodes = part.RootElement?.Descendants<FieldCode>() ?? Enumerable.Empty<FieldCode>();

                foreach (var textElement in fieldCodes)
                {
                    if (textElement.Text.Contains("MERGEFIELD"))
                    {
                        string fieldName = ExtractFieldName(textElement.Text).Trim();

                        foreach (var mergeField in mergeValuesList)
                        {
                            var mergeFieldKeys = mergeField.Keys.ToList();
                            for (int i = 0; i < mergeField.Count; i++)
                            {
                                if (mergeFieldKeys[i] == "Name" && mergeField[mergeFieldKeys[i]] == fieldName)
                                {
                                    string replacementText = mergeField[mergeFieldKeys[i + 1]];

                                    foreach (Run run in part.RootElement.Descendants<Run>())
                                    {
                                        foreach (Text txtFromRun in run.Descendants<Text>().Where(a => a.Text == "«" + fieldName + "»"))
                                        {
                                            txtFromRun.Text = txtFromRun.Text.Replace("«" + fieldName + "»", "");

                                            string[] lines = replacementText.Split('\r');
                                            for (int j = 0; j < lines.Length; j++)
                                            {
                                                if (j > 0)
                                                    run.AppendChild(new Break());
                                                run.AppendChild(new Text(lines[j]));
                                            }
                                        }
                                    }
                                    break;
                                }
                            }
                        }
                    }
                }
            }
            catch (Exception e)
            {
                Console.WriteLine($"Error while replacing merge fields: {e}");
            }

            if (part is MainDocumentPart mainDocPart)
            {
                mainDocPart.Document.Save();
            }
            else if (part is HeaderPart headerPart)
            {
                headerPart.Header.Save();
            }
            else if (part is FooterPart footerPart)
            {
                footerPart.Footer.Save();
            }
        }

        private static void ReplaceFieldText(OpenXmlPart part, string fieldName, string replacementText)
        {
            var runElements = part.RootElement.Descendants<Run>()
                .Where(run => run.InnerText.Contains($"«{fieldName}»"));

            foreach (var run in runElements)
            {
                var textElements = run.Descendants<Text>().Where(text => text.Text.Contains($"«{fieldName}»"));
                foreach (var textElement in textElements)
                {
                    textElement.Text = textElement.Text.Replace($"«{fieldName}»", "");
                    var lines = replacementText.Split('\r');
                    for (int i = 0; i < lines.Length; i++)
                    {
                        if (i > 0)
                            run.AppendChild(new Break());
                        run.AppendChild(new Text(lines[i]));
                    }
                }
            }
        }

        private async Task<Stream> DownloadDocumentContent(string driveId, string itemId)
        {
            try
            {
                var stream = await graphServiceClient?.Drives[driveId].Items[itemId].Content.GetAsync();
                return stream ?? Stream.Null;
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex);
                throw;
            }
        }

        private async Task<SharepointDocumentsGetResponse> PerformMailMerge(string siteId, string driveId,
            string targetSharePointUrl, string FilenameTemplate, string targetDocumentId, Stream documentContent,
            List<Dictionary<string, string>> mergeFields)
        {
            using var memoryStream = new MemoryStream();
            await documentContent.CopyToAsync(memoryStream);
            ReplaceMergeFieldsInDocument(memoryStream, mergeFields);
            memoryStream.Position = 0;
            return await UploadModifiedDocument(siteId, FilenameTemplate, targetSharePointUrl, targetDocumentId, memoryStream, "");
        }

        private async Task<SharepointDocumentsGetResponse> UploadModifiedDocument(string siteId, string FilenameTemplate, string targetSharePointUrl, string itemId, Stream modifiedContent, string subFolder = "")
        {
            try
            {
                if (string.IsNullOrEmpty(siteId))
                    siteId = "environmentalscientifics.sharepoint.com,405ced4f-6a48-4c59-a6fc-f03f9adc3626,39e2f733-4aff-4568-a053-52dacbe1f03e";

                var result = CymBuild_Outlook_Common.Functions.Functions.ExtractLastTwoSegmentsFromUrl(targetSharePointUrl);

                var parentFolder = result.Item1;
                var mainFolder = result.Item2;

                var drives = await graphServiceClient.Sites[siteId].Drives.GetAsync();

                var driveItem = drives.Value.FirstOrDefault(d => d.Name == parentFolder);
                if (driveItem != null)
                {
                    var rootFolder = await graphServiceClient
                                         .Drives[driveItem.Id]
                                         .Root
                                         .GetAsync()
                                     ?? throw new Exception("Failed to obtain root folder.");

                    var itemCollection = await graphServiceClient
                        .Drives[driveItem.Id]
                        .Items[rootFolder.Id]
                        .Children
                        .GetAsync(
                            requestConfig => { requestConfig.QueryParameters.Filter = $"(name eq '{mainFolder}')"; }
                        );

                    var targetFolder = itemCollection.Value.FirstOrDefault();
                    string _fileName = CymBuild_Outlook_Common.Functions.Functions.GetFileNameText(FilenameTemplate);

                    if (targetFolder != null)
                    {
                        var uploadedItem = await graphServiceClient
                            .Drives[driveItem.Id]
                            .Items[targetFolder.Id].ItemWithPath($"{_fileName}.docx")
                            .Content
                            .PutAsync(modifiedContent);

                        Console.WriteLine($"Uploaded item ID: {uploadedItem.Id}, FileName: {_fileName}.docx");

                        return await DownloadDriveItem(driveItem.Id, uploadedItem.Id);
                    }
                    else
                    {
                        Console.WriteLine($"Target folder not found: {targetSharePointUrl}. FileName: {_fileName}.docx NOT CREATED");
                    }
                }
            }
            catch (Exception ex)
            {
                throw ex;
            }
            return new SharepointDocumentsGetResponse();
        }

        #endregion Private Methods

        #region IDisposable Implementation

        protected virtual void Dispose(bool disposing)
        {
            if (!disposed)
            {
                if (disposing)
                {
                    // Dispose managed resources here
                }

                disposed = true;
            }
        }

        public void Dispose()
        {
            Dispose(disposing: true);
            GC.SuppressFinalize(this);
        }

        #endregion IDisposable Implementation
    }
}