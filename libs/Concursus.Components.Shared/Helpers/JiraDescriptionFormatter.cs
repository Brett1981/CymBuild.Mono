using System.Text;
using System.Text.Json;
using System.Web;

namespace Concursus.Components.Shared.Helpers
{
    public static class JiraDescriptionFormatter
    {
        public static string ConvertAdfToHtml(string adfJson)
        {
            if (string.IsNullOrWhiteSpace(adfJson))
                return "<p><i>No Jira description provided</i></p>";

            adfJson = adfJson.Trim();

            if (!adfJson.StartsWith("{") || !adfJson.Contains("\"type\":\"doc\""))
                return $"<p><i>⚠ Not valid ADF JSON. Raw:</i><br /><code>{System.Net.WebUtility.HtmlEncode(adfJson)}</code></p>";

            try
            {
                var doc = JsonDocument.Parse(adfJson);
                var content = doc.RootElement.GetProperty("content");

                var sb = new StringBuilder();
                foreach (var node in content.EnumerateArray())
                {
                    sb.Append(RenderNode(node));
                }

                return sb.ToString();
            }
            catch (Exception ex)
            {
                return $"<p><i>⚠ Failed to parse Jira ADF content:</i><br /><code>{System.Net.WebUtility.HtmlEncode(ex.Message)}</code></p>";
            }
        }

        private static string RenderNode(JsonElement node)
        {
            var type = node.GetProperty("type").GetString();
            return type switch
            {
                "paragraph" => $"<p>{RenderTextContent(node)}</p>",
                "heading" => RenderHeading(node),
                "bulletList" => $"<ul>{RenderListItems(node)}</ul>",
                "orderedList" => $"<ol>{RenderListItems(node)}</ol>",
                "codeBlock" => RenderCodeBlock(node),
                _ => ""
            };
        }

        private static string RenderTextContent(JsonElement node)
        {
            if (!node.TryGetProperty("content", out var content)) return "";

            var sb = new StringBuilder();
            foreach (var child in content.EnumerateArray())
            {
                if (child.TryGetProperty("type", out var typeProp))
                {
                    var type = typeProp.GetString();
                    if (type == "text")
                    {
                        var text = HttpUtility.HtmlEncode(child.GetProperty("text").GetString());

                        if (child.TryGetProperty("marks", out var marks))
                        {
                            foreach (var mark in marks.EnumerateArray())
                            {
                                var markType = mark.GetProperty("type").GetString();
                                text = markType switch
                                {
                                    "strong" => $"<strong>{text}</strong>",
                                    "em" => $"<em>{text}</em>",
                                    "underline" => $"<u>{text}</u>",
                                    "code" => $"<code>{text}</code>",
                                    "link" => $"<a href=\"{mark.GetProperty("attrs").GetProperty("href").GetString()}\" target=\"_blank\">{text}</a>",
                                    _ => text
                                };
                            }
                        }

                        sb.Append(text);
                    }
                    else if (type == "hardBreak")
                    {
                        sb.Append("<br />");
                    }
                }
            }

            return sb.ToString();
        }

        private static string RenderHeading(JsonElement node)
        {
            var level = node.GetProperty("attrs").GetProperty("level").GetInt32();
            var content = RenderTextContent(node);
            return $"<h{level}>{content}</h{level}>";
        }

        private static string RenderListItems(JsonElement node)
        {
            if (!node.TryGetProperty("content", out var items)) return "";

            var sb = new StringBuilder();
            foreach (var item in items.EnumerateArray())
            {
                // item.type = "listItem" > content[]
                if (!item.TryGetProperty("content", out var subContent)) continue;

                sb.Append("<li>");
                foreach (var subItem in subContent.EnumerateArray())
                {
                    sb.Append(RenderNode(subItem));
                }
                sb.Append("</li>");
            }

            return sb.ToString();
        }

        private static string RenderCodeBlock(JsonElement node)
        {
            var codeContent = RenderTextContent(node);
            return $"<pre><code>{codeContent}</code></pre>";
        }
    }
}