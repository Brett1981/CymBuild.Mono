using CymBuild_Outlook_Common.Dto;

namespace CymBuild_Outlook_Common.Helpers
{
    /// <summary>
    /// Builds user-facing labels for SharePoint folders so that folders sharing the same name
    /// (e.g. several "Attachments" sub folders) can be told apart in the filing dropdowns.
    /// </summary>
    public static class SharePointFolderLabelHelper
    {
        #region Public Fields

        public const string PathSeparator = " / ";

        #endregion Public Fields

        #region Public Methods

        /// <summary>
        /// Returns a label per folder Path. A folder whose name is unique keeps its name; a folder
        /// whose name is shared is prefixed with just enough parent folders to make it unique.
        /// </summary>
        public static Dictionary<string, string> BuildLabels(IEnumerable<SharePointFolderDto> folders)
        {
            var list = folders?
                .Where(f => f != null && !string.IsNullOrWhiteSpace(f.Path))
                .GroupBy(f => f.Path, StringComparer.OrdinalIgnoreCase)
                .Select(g => g.First())
                .ToList() ?? new List<SharePointFolderDto>();

            var labels = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

            foreach (var group in list.GroupBy(GetName, StringComparer.OrdinalIgnoreCase))
            {
                var members = group.ToList();

                if (members.Count == 1)
                {
                    labels[members[0].Path] = group.Key;
                    continue;
                }

                var segmentsByPath = members.ToDictionary(
                    m => m.Path,
                    m => SplitPath(m.Path),
                    StringComparer.OrdinalIgnoreCase);

                foreach (var member in members)
                {
                    var segments = segmentsByPath[member.Path];
                    var depth = 2;
                    string label;

                    while (true)
                    {
                        label = JoinTail(segments, depth);

                        var clashes = segmentsByPath
                            .Where(kvp => !string.Equals(kvp.Key, member.Path, StringComparison.OrdinalIgnoreCase))
                            .Any(kvp => string.Equals(JoinTail(kvp.Value, depth), label, StringComparison.OrdinalIgnoreCase));

                        if (!clashes || depth >= segments.Length)
                            break;

                        depth++;
                    }

                    labels[member.Path] = label;
                }
            }

            return labels;
        }

        /// <summary>
        /// Returns the label for <paramref name="path"/> from <paramref name="labels"/>, falling back
        /// to the folder name taken from the path.
        /// </summary>
        public static string GetLabel(IReadOnlyDictionary<string, string> labels, string? path)
        {
            if (string.IsNullOrWhiteSpace(path))
                return string.Empty;

            return labels.TryGetValue(path, out var label)
                ? label
                : SplitPath(path).LastOrDefault() ?? path;
        }

        #endregion Public Methods

        #region Private Methods

        private static string GetName(SharePointFolderDto folder)
            => !string.IsNullOrWhiteSpace(folder.Name)
                ? folder.Name
                : SplitPath(folder.Path).LastOrDefault() ?? folder.Path;

        private static string JoinTail(string[] segments, int depth)
            => string.Join(PathSeparator, segments.Skip(Math.Max(0, segments.Length - depth)));

        private static string[] SplitPath(string path)
            => path.Split('/', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

        #endregion Private Methods
    }
}
