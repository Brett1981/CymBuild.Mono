using CymBuild_Outlook_Common.Helpers;

//using Microsoft.AspNetCore.StaticFiles;
using Microsoft.Net.Http.Headers;
using System.Text.RegularExpressions;

namespace CymBuild_Outlook_Common.Data;

/// <summary>
/// Storage - Contains Properties (Get/Set) for common Application Settings used
/// </summary>
public static class Storage
{
    #region Public Methods

    /// <summary>
    /// Copies the file described in the file path to the target sub directory.
    /// </summary>
    /// <param name="filePath"> </param>
    /// <param name="target">   </param>
    /// <returns> </returns>
    public static Data.FileInfo CopyDmsEntry(FilePath filePath, string target)
    {
        if (filePath.FilingLocation == Enums.FilingLocation.Local)
            return CopyLocalDmsEntry(filePath, target);
        else
            throw new NotImplementedException();
    }

    /// <summary>
    /// Create a new directory as described in the filePath.
    /// </summary>
    /// <param name="filePath"> </param>
    /// <returns> </returns>
    /// <exception cref="NotImplementedException"> </exception>
    public static Data.FileInfo CreateDirectory(FilePath filePath)
    {
        if (filePath.FilingLocation == Enums.FilingLocation.Local)
            return CreateLocalDirectory(filePath);
        else
            throw new NotImplementedException();
    }

    /// <summary>
    /// Delete the file specified in the filePath
    /// </summary>
    /// <param name="filePath"> </param>
    /// <returns> </returns>
    public static bool DeleteDmsEntry(FilePath filePath)
    {
        if (filePath.FilingLocation == Enums.FilingLocation.Local)
            return DeleteLocalDmsEntry(filePath);
        else
            throw new NotImplementedException();
    }

    /// <summary>
    /// </summary>
    /// <param name="filePath"> </param>
    /// <returns> </returns>
    /// <exception cref="NotImplementedException"> </exception>
    public static string GetContentType(FilePath filePath)
    {
        if (filePath.FilingLocation == Enums.FilingLocation.Local)
            return GetLocalContentType(filePath);
        else
            throw new NotImplementedException();
    }

    /// <summary>
    /// </summary>
    /// <param name="filePath"> </param>
    /// <returns> </returns>
    /// <exception cref="NotImplementedException"> </exception>
    public static Data.FileInfo GetFileInfoFor(FilePath filePath)
    {
        if (filePath.FilingLocation == Enums.FilingLocation.Local)
            return GetLocalFileInfoFor(filePath);
        else
            throw new NotImplementedException();
    }

    /// <summary>
    /// Get the contents of the location specified in the FilePath object
    /// </summary>
    /// <param name="filePath">       </param>
    /// <param name="filter">         The file extension filter to apply </param>
    /// <param name="getDirectories"> Return the directories in the path </param>
    /// <param name="getFiles">       Return the files in the paht </param>
    /// <returns> </returns>
    public static List<Data.FileInfo> GetFilePathContents(FilePath filePath, string filter)
    {
        if (filePath.FilingLocation == Enums.FilingLocation.Local)
            return GetLocalFilePathContents(filePath, filter);
        else
            throw new NotImplementedException();
    }

    /// <summary>
    /// </summary>
    /// <param name="filePath"> </param>
    /// <returns> </returns>
    /// <exception cref="NotImplementedException"> </exception>
    public static string GetFilingLocation(FilePath filePath)
    {
        if (filePath.FilingLocation == Enums.FilingLocation.Local)
            return GetLocalFilingLocation(filePath);
        else
            throw new NotImplementedException();
    }

    /// <summary>
    /// </summary>
    /// <param name="filePath"> </param>
    /// <returns> </returns>
    public static Stream OpenFileFrom(FilePath filePath)
    {
        if (filePath.FilingLocation == Enums.FilingLocation.Local)
            return OpenLocalFileFrom(filePath);
        else
            throw new NotImplementedException();
    }

    /// <summary>
    /// Rename the file described in the filePath to the specified new name.
    /// </summary>
    /// <param name="filePath"> </param>
    /// <param name="newName">  </param>
    /// <returns> </returns>
    /// <exception cref="NotImplementedException"> </exception>
    public static Data.FileInfo RenameDmsEntry(FilePath filePath, string newName)
    {
        if (filePath.FilingLocation == Enums.FilingLocation.Local)
            return RenameLocalDmsEntry(filePath, newName);
        else
            throw new NotImplementedException();
    }

    /// <summary>
    /// </summary>
    /// <param name="stream">   </param>
    /// <param name="filePath"> </param>
    public static void SaveFileTo(Stream stream, FilePath filePath)
    {
        if (filePath.FilingLocation == Enums.FilingLocation.Local) SaveToLocal(stream, filePath);
    }

    #endregion Public Methods

    #region Internal Methods

    internal static string VirtualizePath(string path, FilePath filePath)
    {
        var filingLocation = "";

        path = path.Replace(@"\", "/").TrimStart('/');

        if (filePath.FilingLocation == Enums.FilingLocation.Local)
        {
            filePath.VirtualPath = "";
            filingLocation = GetLocalFilingLocation(filePath);
            filingLocation = filingLocation.Replace(@"\", "/").TrimStart('/');
        }

        path = path.Replace(filingLocation, "").TrimStart('/');
        return path;
    }

    #endregion Internal Methods

    #region Private Methods

    private static string AreaFolderLocalName(Enums.AreaFolder areaFolder)
    {
        return areaFolder switch
        {
            Enums.AreaFolder.Admin => "Admin",
            Enums.AreaFolder.Certs => "Certs",
            Enums.AreaFolder.Designinformation => "Design information",
            Enums.AreaFolder.Designrisk => "Design Risk",
            Enums.AreaFolder.Emails => "Emails",
            Enums.AreaFolder.Finance => "Finance",
            Enums.AreaFolder.Photos => "Photos",
            Enums.AreaFolder.Quotedocuments => "Quote Documents",
            Enums.AreaFolder.Sitedocuments => "Site Documents",
            Enums.AreaFolder.Fireconsultation => "Fire Consultation",
            _ => ""
        };
    }

    private static string CategoryFolderLocalName(Enums.CategoryFolder categoryFolder)
    {
        return categoryFolder switch
        {
            Enums.CategoryFolder.Architectural => "Architectural",
            Enums.CategoryFolder.Mep => "MEP",
            Enums.CategoryFolder.Other => "Other",
            Enums.CategoryFolder.Structural => "Structural",
            _ => ""
        };
    }

    private static void CopyLocalDirectory(string sourceDir, string destinationDir, bool recursive)
    {
        // Get information about the source directory
        var dir = new DirectoryInfo(sourceDir);

        // Check if the source directory exists
        if (!dir.Exists)
            throw new DirectoryNotFoundException($"Source directory not found: {dir.FullName}");

        // Cache directories before we start copying
        DirectoryInfo[] dirs = dir.GetDirectories();

        // Create the destination directory
        Directory.CreateDirectory(destinationDir);

        // Get the files in the source directory and copy to the destination directory
        foreach (var file in dir.GetFiles())
        {
            var targetFilePath = Path.Combine(destinationDir, file.Name);
            file.CopyTo(targetFilePath);
        }

        // If recursive and copying subdirectories, recursively call this method
        if (recursive)
            foreach (var subDir in dirs)
            {
                var newDestinationDir = Path.Combine(destinationDir, subDir.Name);
                CopyLocalDirectory(subDir.FullName, newDestinationDir, true);
            }
    }

    private static Data.FileInfo CopyLocalDmsEntry(FilePath filePath, string target)
    {
        var rootpath = GetLocalFilingLocation(filePath);
        var path = GetLocalFilePath(filePath);

        if (filePath.IsDirectory)
        {
            var newPath = Path.Combine(rootpath, target);

            CopyLocalDirectory(path, newPath, true);

            DirectoryInfo newInfo = new(newPath);

            return new FileInfo(newInfo, filePath);
        }
        else
        {
            System.IO.FileInfo oldInfo = new(path);
            var newFilePath = filePath;
            newFilePath.VirtualPath = target;
            var newPath = GetLocalFilePath(newFilePath);

            oldInfo.CopyTo(newPath);

            System.IO.FileInfo newInfo = new(newPath);

            return new FileInfo(newInfo, filePath);
        }
    }

    private static Data.FileInfo CreateLocalDirectory(FilePath filePath)
    {
        var path = GetLocalFilingLocation(filePath, true);
        DirectoryInfo directoryInfo = new(path);

        Data.FileInfo newDirectory = new(directoryInfo, filePath);

        return newDirectory;
    }

    private static bool DeleteLocalDmsEntry(FilePath filePath)
    {
        var path = GetLocalFilePath(filePath);

        if (filePath.IsDirectory)
            Directory.Delete(path);
        else
            File.Delete(path);

        return false;
    }

    //private static string GetLocalContentType(FilePath filePath)
    //{
    //    var fileLocation = GetLocalFilePath(filePath);

    // new FileExtensionContentTypeProvider().TryGetContentType(fileLocation, out var contentType);
    // contentType ??= "application/octet-stream";

    //    return contentType;
    //}
    private static string GetLocalContentType(FilePath filePath)
    {
        var fileLocation = GetLocalFilePath(filePath);

        var contentType = new MediaTypeHeaderValue(fileLocation).MediaType.ToString();
        contentType ??= "application/octet-stream";

        return contentType;
    }

    private static Data.FileInfo GetLocalFileInfoFor(FilePath filePath)
    {
        var path = GetLocalFilePath(filePath);

        Data.FileInfo fileInfo = new(new System.IO.FileInfo(path), filePath);

        return fileInfo;
    }

    private static string GetLocalFilePath(FilePath filePath)
    {
        var path = GetLocalFilingLocation(filePath);
        var fileName = filePath.FileName.StartsWith(@"\") ? filePath.FileName[1..] : filePath.FileName;

        if (fileName.EndsWith(filePath.Extension ?? "") == false) fileName += filePath.Extension;

        return Path.Combine(path, fileName);
    }

    private static List<Data.FileInfo> GetLocalFilePathContents(FilePath filePath, string filter)
    {
        List<Data.FileInfo> pathContents = new();

        var serverBaseLocation = GetLocalFilingLocation(filePath);

        var path = Path.Combine(new string[] { serverBaseLocation, "" });

        if (!Directory.Exists(path)) Directory.CreateDirectory(path);

        var directory = new DirectoryInfo(path);

        var extensions = (filter ?? "*")
            .Split(new string[] { ", ", ",", "; ", ";" }, StringSplitOptions.RemoveEmptyEntries);

        IEnumerable<Data.FileInfo> getFilesResult = extensions
            .SelectMany(directory.GetFiles)
            .Select(folderContents => new Data.FileInfo(folderContents, filePath));
        pathContents.AddRange(getFilesResult.ToList());

        IEnumerable<Data.FileInfo> getDirectoriesResult = extensions
            .SelectMany(directory.GetDirectories)
            .Select(folderContents => new Data.FileInfo(folderContents, filePath));
        pathContents.AddRange(getDirectoriesResult.ToList());

        return pathContents;
    }

    private static string GetLocalFilingLocation(FilePath filePath, bool createNew = false)
    {
        string serverBaseLocation;
        if (filePath.ServerBaseLocation != "" && filePath.ServerBaseLocation is not null)
            serverBaseLocation = filePath.ServerBaseLocation;
        else
            throw new Exception("No server base location");

        string returnPath;
        if (filePath.VirtualPath != null)
        {
            filePath.VirtualPath =
                filePath.VirtualPath.StartsWith(@"\") ? filePath.VirtualPath[1..] : filePath.VirtualPath;
            returnPath = Path.Combine(new string[]
            {
                serverBaseLocation,
                RootFolderLocalName(filePath.RootFolder),
                FileHelper.RootDividerFolder(filePath.RecordId),
                filePath.RecordId.ToString(),
                filePath.VirtualPath
            }).ToString();
        }
        else
        {
            returnPath = Path.Combine(new string[]
            {
                serverBaseLocation,
                RootFolderLocalName(filePath.RootFolder),
                FileHelper.RootDividerFolder(filePath.RecordId),
                filePath.RecordId.ToString()
            }).ToString();
        }

        //returnPath = returnPath.Replace(@"\", "/").TrimStart('/');

        if (createNew)
        {
            var createPath = returnPath;
            var count = 0;

            while (Directory.Exists(createPath))
            {
                count++;
                createPath = returnPath + " (" + count + ")";
            }

            Directory.CreateDirectory(createPath);
            returnPath = createPath;
        }

        return returnPath;
    }

    private static Stream OpenLocalFileFrom(FilePath filePath)
    {
        var path = GetLocalFilePath(filePath);

        System.IO.FileInfo file = new(path);

        return file.OpenRead();
    }

    private static Data.FileInfo RenameLocalDmsEntry(FilePath filePath, string newName)
    {
        var path = GetLocalFilePath(filePath);

        if (filePath.IsDirectory)
        {
            DirectoryInfo oldInfo = new(path);
            var parentPath = oldInfo?.Parent?.FullName ?? "";
            var newPath = Path.Combine(parentPath, newName);
            Directory.Move(path, newPath);

            DirectoryInfo newInfo = new(newPath);

            return new FileInfo(newInfo, filePath);
        }
        else
        {
            System.IO.FileInfo oldInfo = new(path);
            var extension = oldInfo.Extension;
            var oldName = oldInfo.Name;
            var newFilePath = filePath;
            newFilePath.VirtualPath = newFilePath.VirtualPath.Replace(oldName, newName + extension);
            var newPath = GetLocalFilePath(newFilePath);

            File.Move(path, newPath);

            System.IO.FileInfo newInfo = new(newPath);

            return new FileInfo(newInfo, filePath);
        }
    }

    private static string RootFolderLocalName(Enums.RootFolder rootFolder)
    {
        return rootFolder switch
        {
            Enums.RootFolder.Bcfolder => "BC Folders",
            Enums.RootFolder.Shorefolder => "Shore Folders",
            Enums.RootFolder.Quotefolder => "Quote Folders",
            Enums.RootFolder.Usersfolder => "User Folders",
            Enums.RootFolder.Ticketsfolder => "Ticket Folders",
            _ => ""
        };
    }

    private static void SaveToLocal(Stream stream, FilePath filePath)
    {
        if (string.IsNullOrEmpty(filePath.FileName)) throw new Exception("A filename must be specified");

        string areaFolder;
        string categoryFolder;
        string path;
        var serverBaseLocation = "";
        string fullPath;
        var readOnly = filePath.IsReadOnly;

        if (filePath.ServerBaseLocation != "")
        {
            serverBaseLocation = filePath.ServerBaseLocation;
        }
        else
        {
            if (filePath.FilingLocation == Enums.FilingLocation.Local)
                serverBaseLocation = GetLocalFilingLocation(filePath);
        }

        path = Path.Combine(new string[]
        {
            serverBaseLocation,
            RootFolderLocalName(filePath.RootFolder),
            FileHelper.RootDividerFolder(filePath.RecordId),
            filePath.RecordId.ToString()
        });

        if (!Directory.Exists(path))
        {
            Directory.CreateDirectory(path);

            foreach (var a in (Enums.AreaFolder[])Enum.GetValues(typeof(Enums.AreaFolder)))
                Directory.CreateDirectory(Path.Combine(path, AreaFolderLocalName(a)));
        }

        if (filePath.VirtualPath is not null)
        {
            filePath.VirtualPath =
                filePath.VirtualPath.StartsWith(@"\") ? filePath.VirtualPath[1..] : filePath.VirtualPath;
            path = Path.Combine(path, filePath.VirtualPath);
        }
        else
        {
            areaFolder = AreaFolderLocalName(filePath.AreaFolder);
            categoryFolder = CategoryFolderLocalName(filePath.CategoryFolder);

            path = Path.Combine(path, areaFolder);

            if (categoryFolder != "") path = Path.Combine(path, categoryFolder);
        }

        if (!Directory.Exists(path)) Directory.CreateDirectory(path);

        string regexSearch = new(Path.GetInvalidPathChars());
        Regex r = new(string.Format("[{0}]", Regex.Escape(regexSearch)));
        path = r.Replace(path, "");

        regexSearch = new string(Path.GetInvalidFileNameChars());
        r = new Regex(string.Format("[{0}]", Regex.Escape(regexSearch)));
        var fileName = r.Replace(filePath.FileName, "");

        // replace "+" with "plus" as both Telerik file controls can't handle it.
        fileName = fileName.Replace("+", "plus");

        var maxFileNameLength = 247 - path.Length;
        var fileInstance = 0;

        fileName = ShortenFilename(fileName, maxFileNameLength, fileInstance);

        fullPath = Path.Combine(path, fileName);

        while (File.Exists(fullPath))
        {
            fileInstance++;

            fileName = ShortenFilename(fileName, maxFileNameLength, fileInstance);

            fullPath = Path.Combine(path, fileName);
        }

        if (!File.Exists(fullPath))
        {
            using FileStream fs = new(fullPath, FileMode.CreateNew);
            stream.Position = 0;
            stream.CopyTo(fs);

            fs.Close();

            System.IO.FileInfo fi = new(fullPath)
            {
                IsReadOnly = readOnly
            };
        }
        else
        {
            throw new Exception("File already exists");
        }
    }

    private static string ShortenFilename(string fileName, int targetLength, int instance)
    {
        if (fileName.Length > targetLength || instance > 0)
        {
            var instanceString = "";
            var fileExtension = "";
            if (instance > 0) instanceString = "(" + instance.ToString() + ")";

            var extStartIndex = fileName.LastIndexOf(".");

            var fileNameWithoutExtension = fileName[..extStartIndex];
            if (extStartIndex > 0 && extStartIndex > fileName.Length - 5) fileExtension = fileName[extStartIndex..];

            var substringLength = targetLength - fileExtension.Length - instanceString.Length;

            if (substringLength < fileNameWithoutExtension.Length)
                fileNameWithoutExtension = fileNameWithoutExtension[..substringLength];

            fileName = fileNameWithoutExtension + instanceString + fileExtension;
        }

        return fileName;
    }

    #endregion Private Methods
}