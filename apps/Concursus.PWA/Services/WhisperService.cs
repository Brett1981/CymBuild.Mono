using System.IO;
using System.Threading.Tasks;
using Whisper.net;
using Whisper.net.LibraryLoader;
using Whisper.net.Ggml;

namespace Concursus.PWA.Services
{
    public class WhisperService
    {

        private readonly WhisperFactory _whisperFactory;
        private const string WhisperModelPath = "wwwroot/WhisperNet/ggml-base.bin";

        public async Task EnsureWhisperModelExistsAsync()
        {
            if (!File.Exists(WhisperModelPath))
            {
                Directory.CreateDirectory(Path.GetDirectoryName(WhisperModelPath) ?? string.Empty);
                using var modelStream = await WhisperGgmlDownloader.GetGgmlModelAsync(GgmlType.Base);
                using var fileWriter = File.OpenWrite(WhisperModelPath);
                await modelStream.CopyToAsync(fileWriter);
            }
        }

        public WhisperService()
        {
            // Initialize Whisper Factory
            _whisperFactory = WhisperFactory.FromPath(WhisperModelPath);
        }

        public async Task<string> ConvertSpeechToTextAsync(Stream audioStream)
        {
            using var processor = _whisperFactory.CreateBuilder()
                .WithSegmentEventHandler(OnNewSegment) // Optional: For segment-based updates
                .WithTranslate() // Enable translation to English if needed
                .WithLanguage("auto") // Detect language automatically
                .Build();

            await Task.Run(() => processor.Process(audioStream)); // Process the audio stream

            // Return the transcribed text
            return string.Join(" ", _segments);
        }

        private void OnNewSegment(SegmentData e)
        {
            _segments.Add(e.Text);
        }

        private readonly List<string> _segments = new();
   
    }
}
