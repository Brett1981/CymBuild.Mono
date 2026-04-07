using System.Text.RegularExpressions;

namespace CymBuild_AIErrorServiceAPI.Helpers
{
    public static class MarkdownToAdfConverter
    {
        public static object Convert(string markdown)
        {
            var doc = new
            {
                version = 1,
                type = "doc",
                content = new List<object>()
            };

            if (string.IsNullOrWhiteSpace(markdown))
                return doc;

            var blocks = markdown.Split("\n\n", StringSplitOptions.RemoveEmptyEntries);

            foreach (var block in blocks)
            {
                var trimmed = block.Trim();

                // Handle headings
                if (trimmed.StartsWith("# "))
                {
                    doc.content.Add(CreateHeading(trimmed[2..], 1));
                }
                else if (trimmed.StartsWith("## "))
                {
                    doc.content.Add(CreateHeading(trimmed[3..], 2));
                }
                else if (trimmed.StartsWith("### "))
                {
                    doc.content.Add(CreateHeading(trimmed[4..], 3));
                }
                // Handle lists
                else if (trimmed.StartsWith("- ") || trimmed.StartsWith("* "))
                {
                    var listItems = new List<object>();
                    var items = block.Split('\n', StringSplitOptions.RemoveEmptyEntries);

                    foreach (var item in items)
                    {
                        var cleanItem = item.TrimStart('-', '*', ' ').Trim();
                        listItems.Add(new
                        {
                            type = "listItem",
                            content = new[]
                            {
                            new {
                                type = "paragraph",
                                content = new[]
                                {
                                    new { type = "text", text = cleanItem }
                                }
                            }
                        }
                        });
                    }

                    doc.content.Add(new
                    {
                        type = "bulletList",
                        content = listItems
                    });
                }
                // Handle numbered lists
                else if (char.IsDigit(trimmed[0]) && trimmed.Contains(") ") || trimmed.Contains(". "))
                {
                    var listItems = new List<object>();
                    var items = block.Split('\n', StringSplitOptions.RemoveEmptyEntries);

                    foreach (var item in items)
                    {
                        var cleanItem = Regex.Replace(item, @"^\d+[).]\s*", "").Trim();
                        listItems.Add(new
                        {
                            type = "listItem",
                            content = new[]
                            {
                            new {
                                type = "paragraph",
                                content = new[]
                                {
                                    new { type = "text", text = cleanItem }
                                }
                            }
                        }
                        });
                    }

                    doc.content.Add(new
                    {
                        type = "orderedList",
                        content = listItems
                    });
                }
                // Handle regular paragraphs
                else
                {
                    doc.content.Add(new
                    {
                        type = "paragraph",
                        content = new[]
                        {
                        new { type = "text", text = block.Trim() }
                    }
                    });
                }
            }

            return doc;
        }

        private static object CreateHeading(string text, int level)
        {
            return new
            {
                type = "heading",
                attrs = new { level },
                content = new[]
                {
                new { type = "text", text = text.Trim() }
            }
            };
        }
    }
}