namespace Concursus.API;

public class DmsHelper
{
    #region Public Methods

    public static string NormalizePath(string path, string serverBaseLocation, string areaName)
    {
        if (string.IsNullOrEmpty(path))
            return Path.GetFullPath(Path.Combine(serverBaseLocation, areaName));
        else
            return Path.GetFullPath(Path.Combine(serverBaseLocation, areaName, path));
    }

    public static string VirtualizePath(string path, string serverBaseLocation, string areaName)
    {
        path = path.Replace(Path.Combine(serverBaseLocation, areaName), "").Replace(@"\", "/").TrimStart('/');
        return path;
    }

    #endregion Public Methods
}