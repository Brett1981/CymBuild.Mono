using Microsoft.Extensions.Logging;
using Sage200Microservice.Services.Interfaces;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace Sage200Microservice.Services.Implementations
{
    public class SageApiClient : ISageApiClient
    {
        private readonly ILogger<SageApiClient> _logger;
        private readonly HttpClient _httpClient;
        private readonly ISageAuthenticationService _authService;

        public SageApiClient(
            ILogger<SageApiClient> logger,
            HttpClient httpClient,
            ISageAuthenticationService authService)
        {
            _logger = logger;
            _httpClient = httpClient;
            _authService = authService;
        }

        /// <summary>
        /// Sends an authenticated GET request to the Sage 200 API
        /// </summary>
        /// <typeparam name="T"> The type to deserialize the response to </typeparam>
        /// <param name="endpoint"> The API endpoint (relative to base URL) </param>
        /// <returns> The deserialized response </returns>
        public async Task<T> GetAsync<T>(string endpoint)
        {
            try
            {
                var token = await _authService.GetAccessTokenAsync();
                _httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

                var response = await _httpClient.GetAsync(endpoint);
                response.EnsureSuccessStatusCode();

                var content = await response.Content.ReadAsStringAsync();
                var result = JsonSerializer.Deserialize<T>(content, new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                });

                if (result == null)
                {
                    throw new Exception($"Failed to deserialize response from {endpoint}");
                }

                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in GET request to {Endpoint}", endpoint);
                throw;
            }
        }

        /// <summary>
        /// Sends an authenticated POST request to the Sage 200 API
        /// </summary>
        /// <typeparam name="TRequest"> The type of the request body </typeparam>
        /// <typeparam name="TResponse"> The type to deserialize the response to </typeparam>
        /// <param name="endpoint">    The API endpoint (relative to base URL) </param>
        /// <param name="requestBody"> The request body </param>
        /// <returns> The deserialized response </returns>
        public async Task<TResponse> PostAsync<TRequest, TResponse>(string endpoint, TRequest requestBody)
        {
            try
            {
                var token = await _authService.GetAccessTokenAsync();
                _httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

                var json = JsonSerializer.Serialize(requestBody);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                var response = await _httpClient.PostAsync(endpoint, content);
                response.EnsureSuccessStatusCode();

                var responseContent = await response.Content.ReadAsStringAsync();
                var result = JsonSerializer.Deserialize<TResponse>(responseContent, new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                });

                if (result == null)
                {
                    throw new Exception($"Failed to deserialize response from {endpoint}");
                }

                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in POST request to {Endpoint}", endpoint);
                throw;
            }
        }

        /// <summary>
        /// Sends an authenticated PUT request to the Sage 200 API
        /// </summary>
        /// <typeparam name="TRequest"> The type of the request body </typeparam>
        /// <typeparam name="TResponse"> The type to deserialize the response to </typeparam>
        /// <param name="endpoint">    The API endpoint (relative to base URL) </param>
        /// <param name="requestBody"> The request body </param>
        /// <returns> The deserialized response </returns>
        public async Task<TResponse> PutAsync<TRequest, TResponse>(string endpoint, TRequest requestBody)
        {
            try
            {
                var token = await _authService.GetAccessTokenAsync();
                _httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

                var json = JsonSerializer.Serialize(requestBody);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                var response = await _httpClient.PutAsync(endpoint, content);
                response.EnsureSuccessStatusCode();

                var responseContent = await response.Content.ReadAsStringAsync();
                var result = JsonSerializer.Deserialize<TResponse>(responseContent, new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                });

                if (result == null)
                {
                    throw new Exception($"Failed to deserialize response from {endpoint}");
                }

                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in PUT request to {Endpoint}", endpoint);
                throw;
            }
        }

        /// <summary>
        /// Sends an authenticated DELETE request to the Sage 200 API
        /// </summary>
        /// <param name="endpoint"> The API endpoint (relative to base URL) </param>
        /// <returns> True if the request was successful </returns>
        public async Task<bool> DeleteAsync(string endpoint)
        {
            try
            {
                var token = await _authService.GetAccessTokenAsync();
                _httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

                var response = await _httpClient.DeleteAsync(endpoint);
                response.EnsureSuccessStatusCode();

                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in DELETE request to {Endpoint}", endpoint);
                throw;
            }
        }
    }
}