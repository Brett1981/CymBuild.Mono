public class ApiService
{
    private readonly HttpClient _httpClient;

    public ApiService(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    public async Task<string> GetApiDataAsync(string url)
    {
        HttpResponseMessage response = await _httpClient.GetAsync(url);
        if (response.IsSuccessStatusCode)
        {
            string data = await response.Content.ReadAsStringAsync();
            return data;
        }
        else
        {
            // Handle error or throw an exception
            throw new HttpRequestException($"Failed to fetch data: {response.StatusCode}");
        }
    }
}