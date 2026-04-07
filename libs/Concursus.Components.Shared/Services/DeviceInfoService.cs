// Ignore Spelling: Concursus js

using Microsoft.JSInterop;

namespace Concursus.Components.Shared.Services
{
    public class DeviceInfoService
    {
        private readonly IJSRuntime _jsRuntime;

        public bool IsMobile { get; private set; }
        public string DeviceType => IsMobile ? "Mobile" : "Desktop";
        public bool IsInitialized { get; private set; }

        public DeviceInfoService(IJSRuntime jsRuntime)
        {
            _jsRuntime = jsRuntime;
        }

        public async Task InitializeAsync()
        {
            try
            {
                IsMobile = await _jsRuntime.InvokeAsync<bool>("isDevice");
            }
            catch (Exception ex)
            {
                Console.WriteLine("Device detection failed: " + ex.Message);
                IsMobile = false; // Default to Desktop
            }

            IsInitialized = true;
        }
    }
}