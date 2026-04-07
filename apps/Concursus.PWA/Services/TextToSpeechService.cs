using Microsoft.CognitiveServices.Speech;
namespace Concursus.PWA.Services
{
    public class TextToSpeechService
    {
        private readonly SpeechConfig _speechConfig;

        public TextToSpeechService(string subscriptionKey, string region)
        {
            _speechConfig = SpeechConfig.FromSubscription(subscriptionKey, region);
            _speechConfig.SpeechSynthesisVoiceName = "en-US-JennyNeural";
        }

        public async Task SynthesizeSpeechAsync(string text)
        {
            using var synthesizer = new SpeechSynthesizer(_speechConfig);
            await synthesizer.SpeakTextAsync(text);
        }
    }
}
