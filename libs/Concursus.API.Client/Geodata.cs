using Concursus.API.Client.GeoData;
using Newtonsoft.Json;
using System.Net.Http.Headers;
using System.Text;

namespace Concursus.API.Client;

public class Geodata
{
    #region Private Fields

    private readonly HttpClient _client = new();

    #endregion Private Fields

    #region Public Constructors

    public Geodata()
    {
        // Update port # in the following line.
        _client.BaseAddress = new Uri("https://api.postcodes.io/postcodes/");
        _client.DefaultRequestHeaders.Accept.Clear();
        _client.DefaultRequestHeaders.Accept.Add(
            new MediaTypeWithQualityHeaderValue("application/json"));
    }

    #endregion Public Constructors

    #region Public Methods

    public async Task<PostcodeInfo> GetGeoDataAsync(string postcode)
    {
        PostcodeInfo? postcodeInfo = new();
        var response = await _client.GetAsync(postcode);
        if (!response.IsSuccessStatusCode) return postcodeInfo;
        var rawResponse = await response.Content.ReadAsStringAsync();

        postcodeInfo = JsonConvert.DeserializeObject<PostcodeInfo>(rawResponse);

        return postcodeInfo ?? new PostcodeInfo();
    }

    public async Task<List<PostcodeInfo>> GetGeoDataForMultiplePostcodesAsync(List<string> postcodes)
    {
        var postcodeInfos = new List<PostcodeInfo>();

        var content = new StringContent(JsonConvert.SerializeObject(new { postcodes }), Encoding.UTF8, "application/json");
        var response = await _client.PostAsync("", content);

        if (response.IsSuccessStatusCode)
        {
            var rawResponse = await response.Content.ReadAsStringAsync();
            var postcodeResponse = JsonConvert.DeserializeObject<PostcodeInfo>(rawResponse);
            var postcodeResult = new List<PostcodeResult>();
            if (postcodeResponse != null && postcodeResponse.Result != null)
            {
                foreach (var result in postcodeResponse.Result)
                {
                    postcodeResult.Add(result);
                }
                postcodeInfos.Add(new PostcodeInfo(postcodeResult));
            }
        }

        return postcodeInfos;
    }

    public async Task<PostcodeInfo> GetGeoDataByCoordinatesAsync(double longitude, double latitude)
    {
        try
        {
            using (var client = new HttpClient())
            {
                // Base URL for the Postcodes API
                client.BaseAddress = new Uri("https://api.postcodes.io/postcodes");

                // Round coordinates to two decimal places
                longitude = Math.Round(longitude, 2);
                latitude = Math.Round(latitude, 2);

                // Create a new PostcodeInfo object
                var postcodeInfo = new PostcodeInfo();

                // Construct the URL with rounded coordinates
                var url = $"?lon={longitude}&lat={latitude}";

                // Make the asynchronous GET request
                var response = await client.GetAsync(url);

                // Check if the request was successful
                if (!response.IsSuccessStatusCode)
                {
                    return postcodeInfo;
                }

                // Deserialize the response and populate postcodeInfo
                try
                {
                    var rawResponse = await response.Content.ReadAsStringAsync();
                    var dynamicObject = JsonConvert.DeserializeObject<dynamic>(rawResponse);

                    postcodeInfo = new PostcodeInfo
                    {
                        Result = dynamicObject?.result?.ToObject<List<PostcodeResult>>() ?? new List<PostcodeResult>()
                    };
                }
                catch (Exception ex)
                {
                    // Handle JSON deserialization exception
                    Console.WriteLine($"Error deserializing JSON: {ex.Message}");
                }

                return postcodeInfo;
            }
        }
        catch (Exception ex)
        {
            // Handle unexpected exceptions
            Console.WriteLine($"Unexpected error: {ex}");
            throw;
        }
    }

    #endregion Public Methods
}