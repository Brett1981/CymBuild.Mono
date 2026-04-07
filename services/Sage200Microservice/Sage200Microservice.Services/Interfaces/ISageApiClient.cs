namespace Sage200Microservice.Services.Interfaces
{
    public interface ISageApiClient
    {
        /// <summary>
        /// Sends an authenticated GET request to the Sage 200 API
        /// </summary>
        /// <typeparam name="T"> The type to deserialize the response to </typeparam>
        /// <param name="endpoint"> The API endpoint (relative to base URL) </param>
        /// <returns> The deserialized response </returns>
        Task<T> GetAsync<T>(string endpoint);

        /// <summary>
        /// Sends an authenticated POST request to the Sage 200 API
        /// </summary>
        /// <typeparam name="TRequest"> The type of the request body </typeparam>
        /// <typeparam name="TResponse"> The type to deserialize the response to </typeparam>
        /// <param name="endpoint">    The API endpoint (relative to base URL) </param>
        /// <param name="requestBody"> The request body </param>
        /// <returns> The deserialized response </returns>
        Task<TResponse> PostAsync<TRequest, TResponse>(string endpoint, TRequest requestBody);

        /// <summary>
        /// Sends an authenticated PUT request to the Sage 200 API
        /// </summary>
        /// <typeparam name="TRequest"> The type of the request body </typeparam>
        /// <typeparam name="TResponse"> The type to deserialize the response to </typeparam>
        /// <param name="endpoint">    The API endpoint (relative to base URL) </param>
        /// <param name="requestBody"> The request body </param>
        /// <returns> The deserialized response </returns>
        Task<TResponse> PutAsync<TRequest, TResponse>(string endpoint, TRequest requestBody);

        /// <summary>
        /// Sends an authenticated DELETE request to the Sage 200 API
        /// </summary>
        /// <param name="endpoint"> The API endpoint (relative to base URL) </param>
        /// <returns> True if the request was successful </returns>
        Task<bool> DeleteAsync(string endpoint);
    }
}