using Concursus.API.DMS;
using Google.Protobuf.WellKnownTypes;
using FileInfo = Concursus.Common.Shared.Data.FileInfo;

namespace Concursus.API;

public class TypeHelpers
{
    #region Public Methods

    public static DMS.FileManagerEntry GetFileManagerEntryFromFileInfo(FileInfo fileInfo)
    {
        return new FileManagerEntry
        {
            Name = fileInfo.Name,
            Size = fileInfo.Size,
            Path = fileInfo.VirtualPath,
            Extension = fileInfo.Extension,
            IsDirectory = fileInfo.IsDirectory,
            HasDirectories = fileInfo.HasDirectories,
            Created = Timestamp.FromDateTime(fileInfo.Created.ToUniversalTime()),
            CreatedUtc = Timestamp.FromDateTime(new DateTime(fileInfo.CreatedUtc.Ticks, DateTimeKind.Utc)),
            Modified = Timestamp.FromDateTime(fileInfo.Modified.ToUniversalTime()),
            ModifiedUtc = Timestamp.FromDateTime(new DateTime(fileInfo.ModifiedUtc.Ticks, DateTimeKind.Utc))
        };
    }

    #endregion Public Methods
}