namespace Concursus.Common.Shared.Data;

/// <summary>
/// </summary>
public class FileInfo
{
    #region Public Constructors

    /// <summary>
    /// </summary>
    public FileInfo()
    {
    }

    /// <summary>
    /// </summary>
    /// <param name="fileInfo"> </param>
    /// <param name="filePath"> </param>
    public FileInfo(System.IO.FileInfo fileInfo, FilePath filePath)
    {
        Name = Path.GetFileNameWithoutExtension(fileInfo.Name);
        Size = fileInfo.Length;
        VirtualPath = Storage.VirtualizePath(fileInfo.FullName, filePath);
        Extension = fileInfo.Extension;
        IsDirectory = false;
        HasDirectories = false;
        Created = fileInfo.CreationTime;
        CreatedUtc = fileInfo.CreationTimeUtc;
        Modified = fileInfo.LastWriteTime;
        ModifiedUtc = fileInfo.LastWriteTimeUtc;
    }

    /// <summary>
    /// </summary>
    /// <param name="directoryInfo"> </param>
    /// <param name="filePath">      </param>
    public FileInfo(DirectoryInfo directoryInfo, FilePath filePath)
    {
        Name = directoryInfo.Name;
        Size = 0;
        VirtualPath = Storage.VirtualizePath(directoryInfo.FullName, filePath);
        Extension = directoryInfo.Extension;
        IsDirectory = true;
        HasDirectories = directoryInfo.GetDirectories().Length > 0;
        Created = directoryInfo.CreationTime;
        CreatedUtc = directoryInfo.CreationTimeUtc;
        Modified = directoryInfo.LastWriteTime;
        ModifiedUtc = directoryInfo.LastWriteTimeUtc;
    }

    #endregion Public Constructors

    #region Public Properties

    /// <summary>
    /// </summary>
    public DateTime Created { get; set; }

    /// <summary>
    /// </summary>
    public DateTime CreatedUtc { get; set; }

    /// <summary>
    /// </summary>
    public string Extension { get; set; }

    /// <summary>
    /// </summary>
    public bool HasDirectories { get; set; }

    /// <summary>
    /// </summary>
    public bool IsDirectory { get; set; }

    /// <summary>
    /// </summary>
    public DateTime Modified { get; set; }

    /// <summary>
    /// </summary>
    public DateTime ModifiedUtc { get; set; }

    /// <summary>
    /// </summary>
    public string Name { get; set; }

    /// <summary>
    /// </summary>
    public long Size { get; set; }

    /// <summary>
    /// </summary>
    public string VirtualPath { get; set; }

    #endregion Public Properties
}