using System.Text.Json;
using System.Text.Json.Serialization;

namespace Concursus.Components.Shared.Services
{
    public class UserInteractionTrackerService
    {
        private readonly Dictionary<string, List<LogEntry>> _logs = new();

        public void Log(string pageKey, string message)
        {
            if (!_logs.ContainsKey(pageKey))
                _logs[pageKey] = new List<LogEntry>();

            _logs[pageKey].Add(new LogEntry { Timestamp = DateTime.Now, Message = message });
        }

        public IEnumerable<LogEntry> GetLogsForPage(string pageKey)
        {
            return _logs.TryGetValue(pageKey, out var entries) ? entries : Enumerable.Empty<LogEntry>();
        }

        public string GetLogsAsString(string pageName)
        {
            return _logs.TryGetValue(pageName, out var logs)
                ? string.Join(Environment.NewLine, logs)
                : string.Empty;
        }

        public List<LogEntry> GetAllLogs()
        {
            return _logs.SelectMany(kvp => kvp.Value).OrderByDescending(e => e.Timestamp).ToList();
        }

        public List<string> GetAllPageKeys() => _logs.Keys.ToList();

        public void ClearAll() => _logs.Clear();

        public string GetReplicationStepsFormatted(UserInteractionTrackerService tracker)
        {
            var logsByPage = tracker
                .GetAllPageKeys()
                .Select(page => new
                {
                    Page = page,
                    Entries = tracker.GetLogsForPage(page)
                        .OrderBy(e => e.Timestamp)
                        .ToList()
                })
                .Where(group => group.Entries.Any())
                .ToList();

            // Create ADF document structure
            var doc = new AdfDoc
            {
                Version = 1,
                Type = "doc",
                Content = new List<AdfNode>()
            };

            // Add main heading
            doc.Content.Add(new AdfNode
            {
                Type = "heading",
                Attrs = new HeadingAttributes { Level = 2 },
                Content = new List<AdfNode>
        {
            new AdfNode { Type = "text", Text = "Replication Steps" }
        }
            });

            foreach (var group in logsByPage)
            {
                // Add page heading
                doc.Content.Add(new AdfNode
                {
                    Type = "heading",
                    Attrs = new HeadingAttributes { Level = 3 },
                    Content = new List<AdfNode>
            {
                new AdfNode {
                    Type = "text",
                    Text = $"Page: {SanitizeUrl(group.Page)}"
                }
            }
                });

                // Add log entries as paragraphs
                foreach (var entry in group.Entries)
                {
                    doc.Content.Add(new AdfNode
                    {
                        Type = "paragraph",
                        Content = new List<AdfNode>
                {
                    new AdfNode
                    {
                        Type = "text",
                        Text = $"{entry.Message} (at {entry.Timestamp:dd-MM-yyyy HH:mm:ss})"
                    }
                }
                    });
                }
            }

            // Serialize to JSON
            return JsonSerializer.Serialize(doc, new JsonSerializerOptions
            {
                DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            });
        }

        private string SanitizeUrl(string url)
        {
            return url.Replace("https://", "hxxps://")
                      .Replace("http://", "hxxp://");
        }
    }

    public class LogEntry
    {
        public DateTime Timestamp { get; set; }
        public string Message { get; set; } = "";
    }

    // ADF Model Classes
    public class AdfDoc
    {
        public int Version { get; set; }
        public string Type { get; set; } = "doc";
        public List<AdfNode> Content { get; set; } = new List<AdfNode>();
    }

    public class AdfNode
    {
        public string? Type { get; set; }

        [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
        public object? Attrs { get; set; }

        [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
        public string? Text { get; set; }

        [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
        public List<AdfNode>? Content { get; set; }
    }

    public class HeadingAttributes
    {
        public int Level { get; set; }
    }
}