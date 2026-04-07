namespace Concursus.API.Models
{
    public class ImageFolderInfo
    {
        public string FolderName { get; set; }
        public List<ImageFileInfo> Images { get; set; } = new List<ImageFileInfo>();
    }

    public class ImageFileInfo
    {
        public string ImagePath { get; set; }
        public byte[] ImageBytes { get; set; }
    }
}