using Microsoft.AspNetCore.Mvc;

namespace CymBuild_AIErrorServiceAPI.Dto
{
    public class FileUploadForm
    {
        [FromForm(Name = "file")]
        public IFormFile File { get; set; }

        [FromForm(Name = "message")]
        public string Message { get; set; }
    }
}