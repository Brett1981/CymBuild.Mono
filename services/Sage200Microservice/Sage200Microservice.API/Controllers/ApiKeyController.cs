using Microsoft.AspNetCore.Mvc;
using Sage200Microservice.API.Models;
using Sage200Microservice.API.Services;
using Sage200Microservice.Data.Repositories;
using System.Security.Cryptography;

namespace Sage200Microservice.API.Controllers
{
    /// <summary>
    /// Controller for managing API keys
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [Produces("application/json")]
    public class ApiKeyController : ControllerBase
    {
        private readonly IApiKeyRepository _apiKeyRepository;
        private readonly ICacheInvalidationService _cacheInvalidationService;
        private readonly ICachingService _cachingService;
        private readonly ILogger<ApiKeyController> _logger;

        /// <summary>
        /// Initializes a new instance of the ApiKeyController
        /// </summary>
        /// <param name="apiKeyRepository">         The API key repository </param>
        /// <param name="cacheInvalidationService"> The cache invalidation service </param>
        /// <param name="cachingService">           The caching service </param>
        /// <param name="logger">                   The logger </param>
        public ApiKeyController(
            IApiKeyRepository apiKeyRepository,
            ICacheInvalidationService cacheInvalidationService,
            ICachingService cachingService,
            ILogger<ApiKeyController> logger)
        {
            _apiKeyRepository = apiKeyRepository;
            _cacheInvalidationService = cacheInvalidationService;
            _cachingService = cachingService;
            _logger = logger;
        }

        /// <summary>
        /// Gets all API keys with pagination and filtering
        /// </summary>
        /// <param name="request"> The request parameters </param>
        /// <returns> A list of API keys </returns>
        /// <response code="200"> Returns the list of API keys </response>
        /// <response code="400"> If the request is invalid </response>
        [HttpGet]
        [ProducesResponseType(typeof(PaginatedResponse<ApiKeyResponse>), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status400BadRequest)]
        public async Task<ActionResult<PaginatedResponse<ApiKeyResponse>>> GetApiKeys([FromQuery] ApiKeyFilterRequest request)
        {
            try
            {
                var cacheKey = $"ApiKeys_{request.Page}_{request.PageSize}_{request.SortBy}_{request.SortDirection}_{request.IncludeInactive}_{request.IncludeExpired}";

                var cachedResponse = await _cachingService.GetAsync<PaginatedResponse<ApiKeyResponse>>(cacheKey);
                if (cachedResponse != null)
                {
                    _logger.LogInformation("Cache hit for {CacheKey}", cacheKey);
                    return Ok(cachedResponse);
                }
                else
                {
                    _logger.LogInformation("Cache miss for {CacheKey}, fetching API keys", cacheKey);

                    var apiKeys = await _apiKeyRepository.GetAllAsync(
                        page: request.Page,
                        pageSize: request.PageSize,
                        sortBy: request.SortBy,
                        sortDirection: request.SortDirection);

                    var response = new Sage200Microservice.API.Models.PaginatedResponse<ApiKeyResponse>(
                        apiKeys.Select(k => new ApiKeyResponse
                        {
                            Id = k.Id,
                            ClientName = k.ClientName,
                            CreatedAt = k.CreatedAt,
                            ExpiresAt = k.ExpiresAt,
                            IsActive = k.IsActive,
                            GracePeriodEnd = k.GracePeriodEnd
                        }).ToList(),
                        apiKeys.TotalCount,
                        request.Page,
                        request.PageSize
                    );

                    await _cachingService.SetAsync(cacheKey, response, TimeSpan.FromMinutes(5));

                    return Ok(response);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting API keys");
                return BadRequest(new Sage200Microservice.API.Models.ErrorResponse { Message = "Error getting API keys", Details = ex.Message });
            }
        }

        /// <summary>
        /// Gets an API key by ID
        /// </summary>
        /// <param name="id"> The API key ID </param>
        /// <returns> The API key details </returns>
        /// <response code="200"> Returns the API key details </response>
        /// <response code="404"> If the API key is not found </response>
        [HttpGet("{id}")]
        [ProducesResponseType(typeof(ApiKeyResponse), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<ApiKeyResponse>> GetApiKey(int id)
        {
            try
            {
                var cacheKey = $"ApiKey_{id}";

                var cachedResponse = await _cachingService.GetAsync<ApiKeyResponse>(cacheKey);
                if (cachedResponse != null)
                {
                    _logger.LogInformation("Cache hit for {CacheKey}", cacheKey);
                    return Ok(cachedResponse);
                }
                else
                {
                    _logger.LogInformation("Cache miss for {CacheKey}, fetching API key", cacheKey);

                    var apiKey = await _apiKeyRepository.GetByIdAsync(id);

                    if (apiKey == null)
                    {
                        return NotFound();
                    }

                    var response = new ApiKeyResponse
                    {
                        Id = apiKey.Id,
                        ClientName = apiKey.ClientName,
                        CreatedAt = apiKey.CreatedAt,
                        ExpiresAt = apiKey.ExpiresAt,
                        IsActive = apiKey.IsActive,
                        GracePeriodEnd = apiKey.GracePeriodEnd
                    };

                    await _cachingService.SetAsync(cacheKey, response, TimeSpan.FromMinutes(5));

                    return Ok(response);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting API key {ApiKeyId}", id);
                return NotFound();
            }
        }

        /// <summary>
        /// Creates a new API key
        /// </summary>
        /// <param name="request"> The API key creation request </param>
        /// <returns> The created API key details </returns>
        /// <response code="200"> Returns the created API key details </response>
        /// <response code="400"> If the request is invalid </response>
        [HttpPost]
        [ProducesResponseType(typeof(ApiKeyCreationResponse), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status400BadRequest)]
        public async Task<ActionResult<ApiKeyCreationResponse>> CreateApiKey([FromBody] ApiKeyCreationRequest request)
        {
            // Generate a new API key
            var key = GenerateApiKey();

            var apiKey = new Sage200Microservice.Data.Models.ApiKey
            {
                Key = key,
                ClientName = request.ClientName,
                CreatedAt = DateTime.UtcNow,
                ExpiresAt = request.ExpiresInDays.HasValue ? DateTime.UtcNow.AddDays(request.ExpiresInDays.Value) : null,
                IsActive = true
            };

            var createdApiKey = await _apiKeyRepository.AddAsync(apiKey);

            // Invalidate the API keys collection cache
            _cacheInvalidationService.InvalidateEntityTypeCache("ApiKey");

            var response = new ApiKeyCreationResponse
            {
                Id = createdApiKey.Id,
                ClientName = createdApiKey.ClientName,
                CreatedAt = createdApiKey.CreatedAt,
                ExpiresAt = createdApiKey.ExpiresAt,
                Key = createdApiKey.Key,
                IsActive = createdApiKey.IsActive
            };

            return Ok(response);
        }

        /// <summary>
        /// Revokes an API key
        /// </summary>
        /// <param name="id"> The API key ID </param>
        /// <returns> A success message </returns>
        /// <response code="200"> Returns success if the API key was revoked </response>
        /// <response code="404"> If the API key is not found </response>
        [HttpDelete("{id}")]
        [ProducesResponseType(typeof(ApiKeyRevocationResponse), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<ApiKeyRevocationResponse>> RevokeApiKey(int id)
        {
            var apiKey = await _apiKeyRepository.GetByIdAsync(id);

            if (apiKey == null)
            {
                return NotFound();
            }

            apiKey.IsActive = false;
            await _apiKeyRepository.UpdateAsync(apiKey);

            // Invalidate the cache for this API key and the collection
            _cacheInvalidationService.InvalidateEntityCache("ApiKey", id.ToString());
            _cacheInvalidationService.InvalidateEntityTypeCache("ApiKey");

            var response = new ApiKeyRevocationResponse
            {
                Success = true,
                Message = $"API key for {apiKey.ClientName} has been revoked"
            };

            return Ok(response);
        }

        /// <summary>
        /// Rotates an API key
        /// </summary>
        /// <param name="id">      The API key ID </param>
        /// <param name="request"> The rotation request </param>
        /// <returns> The new API key details </returns>
        /// <response code="200"> Returns the new API key details </response>
        /// <response code="404"> If the API key is not found </response>
        [HttpPut("{id}/rotate")]
        [ProducesResponseType(typeof(ApiKeyRotationResponse), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<ApiKeyRotationResponse>> RotateApiKey(int id, [FromBody] ApiKeyRotationRequest request)
        {
            var apiKey = await _apiKeyRepository.GetByIdAsync(id);

            if (apiKey == null)
            {
                return NotFound();
            }

            // Create a new API key with the same details
            var newKey = GenerateApiKey();

            var newApiKey = new Sage200Microservice.Data.Models.ApiKey
            {
                Key = newKey,
                ClientName = apiKey.ClientName,
                CreatedAt = DateTime.UtcNow,
                ExpiresAt = apiKey.ExpiresAt,
                IsActive = true
            };

            var createdApiKey = await _apiKeyRepository.AddAsync(newApiKey);

            // Set the grace period for the old key
            apiKey.GracePeriodEnd = DateTime.UtcNow.AddDays(request.GracePeriodDays);
            await _apiKeyRepository.UpdateAsync(apiKey);

            // Invalidate the cache for this API key and the collection
            _cacheInvalidationService.InvalidateEntityCache("ApiKey", id.ToString());
            _cacheInvalidationService.InvalidateEntityTypeCache("ApiKey");

            var response = new ApiKeyRotationResponse
            {
                Success = true,
                Message = $"API key for {apiKey.ClientName} has been rotated",
                NewApiKey = new ApiKeyCreationResponse
                {
                    Id = createdApiKey.Id,
                    ClientName = createdApiKey.ClientName,
                    CreatedAt = createdApiKey.CreatedAt,
                    ExpiresAt = createdApiKey.ExpiresAt,
                    Key = createdApiKey.Key,
                    IsActive = createdApiKey.IsActive
                },
                OldApiKey = new ApiKeyResponse
                {
                    Id = apiKey.Id,
                    ClientName = apiKey.ClientName,
                    CreatedAt = apiKey.CreatedAt,
                    ExpiresAt = apiKey.ExpiresAt,
                    IsActive = apiKey.IsActive,
                    GracePeriodEnd = apiKey.GracePeriodEnd
                }
            };

            return Ok(response);
        }

        /// <summary>
        /// Validates an API key
        /// </summary>
        /// <param name="key"> The API key to validate </param>
        /// <returns> Whether the API key is valid </returns>
        /// <response code="200"> Returns whether the API key is valid </response>
        [HttpGet("validate/{key}")]
        [ProducesResponseType(typeof(ApiKeyValidationResponse), StatusCodes.Status200OK)]
        public async Task<ActionResult<ApiKeyValidationResponse>> ValidateApiKey(string key)
        {
            try
            {
                var cacheKey = $"ApiKeyValidation_{key}";

                var cachedResponse = await _cachingService.GetAsync<ApiKeyValidationResponse>(cacheKey);
                if (cachedResponse != null)
                {
                    _logger.LogInformation("Cache hit for {CacheKey}", cacheKey);
                    return Ok(cachedResponse);
                }
                else
                {
                    _logger.LogInformation("Cache miss for {CacheKey}, validating API key", cacheKey);

                    var isValid = await _apiKeyRepository.IsValidKeyAsync(key);

                    var response = new ApiKeyValidationResponse
                    {
                        IsValid = isValid
                    };

                    await _cachingService.SetAsync(cacheKey, response, TimeSpan.FromMinutes(5));

                    return Ok(response);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error validating API key");
                return Ok(new ApiKeyValidationResponse { IsValid = false });
            }
        }

        private string GenerateApiKey()
        {
            var bytes = new byte[32];
            using (var rng = RandomNumberGenerator.Create())
            {
                rng.GetBytes(bytes);
            }
            return Convert.ToBase64String(bytes).Replace("+", "-").Replace("/", "_").Replace("=", "");
        }
    }

    /// <summary>
    /// Request model for filtering API keys
    /// </summary>
    public class ApiKeyFilterRequest
    {
        /// <summary>
        /// The page number (1-based)
        /// </summary>
        /// <example> 1 </example>
        public int Page { get; set; } = 1;

        /// <summary>
        /// The number of items per page
        /// </summary>
        /// <example> 10 </example>
        public int PageSize { get; set; } = 10;

        /// <summary>
        /// The field to sort by
        /// </summary>
        /// <example> CreatedAt </example>
        public string SortBy { get; set; } = "CreatedAt";

        /// <summary>
        /// The sort direction (asc or desc)
        /// </summary>
        /// <example> desc </example>
        public string SortDirection { get; set; } = "desc";

        /// <summary>
        /// Whether to include inactive API keys
        /// </summary>
        /// <example> false </example>
        public bool IncludeInactive { get; set; } = false;

        /// <summary>
        /// Whether to include expired API keys
        /// </summary>
        /// <example> false </example>
        public bool IncludeExpired { get; set; } = false;
    }

    /// <summary>
    /// Request model for creating an API key
    /// </summary>
    public class ApiKeyCreationRequest
    {
        /// <summary>
        /// The name of the client
        /// </summary>
        /// <example> Mobile App </example>
        public string ClientName { get; set; }

        /// <summary>
        /// The number of days until the API key expires (null for no expiry)
        /// </summary>
        /// <example> 365 </example>
        public int? ExpiresInDays { get; set; }
    }

    /// <summary>
    /// Request model for rotating an API key
    /// </summary>
    public class ApiKeyRotationRequest
    {
        /// <summary>
        /// The number of days for the grace period
        /// </summary>
        /// <example> 7 </example>
        public int GracePeriodDays { get; set; } = 7;
    }

    /// <summary>
    /// Response model for API key details
    /// </summary>
    public class ApiKeyResponse
    {
        /// <summary>
        /// The API key ID
        /// </summary>
        public int Id { get; set; }

        /// <summary>
        /// The name of the client
        /// </summary>
        public string ClientName { get; set; }

        /// <summary>
        /// When the API key was created
        /// </summary>
        public DateTime CreatedAt { get; set; }

        /// <summary>
        /// When the API key expires (null for no expiry)
        /// </summary>
        public DateTime? ExpiresAt { get; set; }

        /// <summary>
        /// Whether the API key is active
        /// </summary>
        public bool IsActive { get; set; }

        /// <summary>
        /// When the grace period ends (null if not in grace period)
        /// </summary>
        public DateTime? GracePeriodEnd { get; set; }
    }

    /// <summary>
    /// Response model for API key creation
    /// </summary>
    public class ApiKeyCreationResponse : ApiKeyResponse
    {
        /// <summary>
        /// The API key value
        /// </summary>
        public string Key { get; set; }
    }

    /// <summary>
    /// Response model for API key revocation
    /// </summary>
    public class ApiKeyRevocationResponse
    {
        /// <summary>
        /// Whether the operation was successful
        /// </summary>
        public bool Success { get; set; }

        /// <summary>
        /// A message describing the result of the operation
        /// </summary>
        public string Message { get; set; }
    }

    /// <summary>
    /// Response model for API key rotation
    /// </summary>
    public class ApiKeyRotationResponse
    {
        /// <summary>
        /// Whether the operation was successful
        /// </summary>
        public bool Success { get; set; }

        /// <summary>
        /// A message describing the result of the operation
        /// </summary>
        public string Message { get; set; }

        /// <summary>
        /// The new API key details
        /// </summary>
        public ApiKeyCreationResponse NewApiKey { get; set; }

        /// <summary>
        /// The old API key details
        /// </summary>
        public ApiKeyResponse OldApiKey { get; set; }
    }

    /// <summary>
    /// Response model for API key validation
    /// </summary>
    public class ApiKeyValidationResponse
    {
        /// <summary>
        /// Whether the API key is valid
        /// </summary>
        public bool IsValid { get; set; }
    }
}