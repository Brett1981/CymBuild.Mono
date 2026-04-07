using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using Newtonsoft.Json.Serialization;
using System.Net;
using System.Net.Http.Headers;
using System.Text;

namespace Concursus.Common.Shared.DataServices;

public class RequestProvider : IRequestProvider
{
    #region Private Fields

    private readonly JsonSerializerSettings _serializerSettings;

    #endregion Private Fields

    #region Public Constructors

    public RequestProvider()
    {
        _serializerSettings = new JsonSerializerSettings
        {
            ContractResolver = new CamelCasePropertyNamesContractResolver(),
            DateTimeZoneHandling = DateTimeZoneHandling.Utc,
            NullValueHandling = NullValueHandling.Ignore
        };

        _serializerSettings.Converters.Add(new StringEnumConverter());
    }

    #endregion Public Constructors

    #region Public Methods

    public async Task<bool> CheckConnection(string uri)
    {
        var httpClient = CreateHttpClient();
        var response = await httpClient.GetAsync(uri);
        return response.IsSuccessStatusCode;
    }

    public async Task<TResult> GetAsync<TResult>(string uri)
    {
        try
        {
            var httpClient = CreateHttpClient();
            var response = await httpClient.GetAsync(uri);

            if (response.IsSuccessStatusCode)
            {
                await HandleResponse(response);

                var serialized = await response.Content.ReadAsStringAsync();
                var result =
                    await Task.Run(() => JsonConvert.DeserializeObject<TResult>(serialized, _serializerSettings));

                return result;
            }
            else if (response.StatusCode == HttpStatusCode.NotFound)
            {
                throw new KeyNotFoundException();
            }
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine("---> " + ex.Message);
        }

        throw new Exception();
    }

    public Task<TResult> PostAsync<TResult>(string uri, TResult data)
    {
        return PostAsync<TResult, TResult>(uri, data);
    }

    public async Task<TResult> PostAsync<TRequest, TResult>(string uri, TRequest data)
    {
        var httpClient = CreateHttpClient();
        var serialized = await Task.Run(() => JsonConvert.SerializeObject(data, _serializerSettings));
        var response =
            await httpClient.PostAsync(uri, new StringContent(serialized, Encoding.UTF8, "application/json"));

        await HandleResponse(response);

        var responseData = await response.Content.ReadAsStringAsync();

        return await Task.Run(() => JsonConvert.DeserializeObject<TResult>(responseData, _serializerSettings));
    }

    public Task<TResult> PutAsync<TResult>(string uri, TResult data)
    {
        return PutAsync<TResult, TResult>(uri, data);
    }

    public async Task<TResult> PutAsync<TRequest, TResult>(string uri, TRequest data)
    {
        var httpClient = CreateHttpClient();
        var serialized = await Task.Run(() => JsonConvert.SerializeObject(data, _serializerSettings));
        var response = await httpClient.PutAsync(uri, new StringContent(serialized, Encoding.UTF8, "application/json"));

        await HandleResponse(response);

        var responseData = await response.Content.ReadAsStringAsync();

        return await Task.Run(() => JsonConvert.DeserializeObject<TResult>(responseData, _serializerSettings));
    }

    #endregion Public Methods

    #region Private Methods

    private HttpClient CreateHttpClient()
    {
        // Add Authorization Key
        var httpClient = new HttpClient();

        var auth =
            "AAAAuhYqob0:APA91bEK5ZlqYOPoe6YXTMH48EO9On9gi4i1GLrs5nBvx70bkhqZcoL4UDEKlYlhkWXJyWcrhYygSOplfKqdYbdhdukNXaUODCFeKeH_yQNtSS1MeKysn-U2Q7Z_aMAPdbSyYOp2EtLe";
        httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("key", "=" + auth);
        httpClient.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

        return httpClient;
    }

    private async Task HandleResponse(HttpResponseMessage response)
    {
        if (!response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();

            if (response.StatusCode == HttpStatusCode.Forbidden || response.StatusCode == HttpStatusCode.Unauthorized)
            {
                //throw new ServiceAuthenticationException(content);
            }

            throw new HttpRequestException(content);
        }
    }

    #endregion Private Methods
}