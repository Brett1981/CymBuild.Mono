namespace Concursus.API.Classes
{
    public static class StreamExtensions
    {
        public static async Task<byte[]> ToArrayAsync(this Stream stream)
        {
            using var memoryStream = new MemoryStream();
            await stream.CopyToAsync(memoryStream);
            return memoryStream.ToArray();
        }
    }
}