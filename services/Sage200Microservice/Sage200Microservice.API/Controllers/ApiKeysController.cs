using Microsoft.AspNetCore.Mvc;
using Sage200Microservice.API.DTOs;
using Sage200Microservice.Data.Models;
using Sage200Microservice.Services.Interfaces;

namespace Sage200Microservice.API.Controllers
{
    /// <summary>
    /// Controller for managing API keys
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    public class ApiKeysController : ControllerBase
    {
        private readonly ILogger<ApiKeysController> _logger;
        private readonly IApiKeyService _apiKeyService;

        /// <summary>
        /// Initializes a new instance of the ApiKeysController class
        /// </summary>
        /// <param name="logger">        The logger </param>
        /// <param name="apiKeyService"> The API key service </param>
        public ApiKeysController(
            ILogger<ApiKeysController> logger,
            IApiKeyService apiKeyService)
        {
            _logger = logger;
            _apiKeyService = apiKeyService;
        }

        /// <summary>
        /// Gets all API keys
        /// </summary>
        /// <returns> A list of API keys </returns>
        [HttpGet]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<ActionResult<List<ApiKeyResponseDto>>> GetAll()
        {
            var apiKeys = await _apiKeyService.GetAllAsync();

            return Ok(apiKeys.Select(k => MapToResponseDto(k)).ToList());
        }

        /// <summary>
        /// Gets an API key by ID
        /// </summary>
        /// <param name="id"> The API key ID </param>
        /// <returns> The API key </returns>
        [HttpGet("{id}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<ApiKeyResponseDto>> GetById(int id)
        {
            var apiKey = await _apiKeyService.GetByIdAsync(id);

            if (apiKey == null)
            {
                return NotFound();
            }

            return Ok(MapToResponseDto(apiKey));
        }

        /// <summary>
        /// Creates a new API key
        /// </summary>
        /// <param name="request"> The create API key request </param>
        /// <returns> The created API key </returns>
        [HttpPost]
        [ProducesResponseType(StatusCodes.Status201Created)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public async Task<ActionResult<ApiKeyResponseDto>> Create([FromBody] CreateApiKeyRequestDto request)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            try
            {
                var apiKey = await _apiKeyService.CreateAsync(
                    request.ClientName,
                    request.ExpiresAt,
                    request.AllowedIpAddresses);

                var response = MapToResponseDto(apiKey);

                return CreatedAtAction(nameof(GetById), new { id = apiKey.Id }, response);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating API key");
                return BadRequest(new { message = ex.Message });
            }
        }

        /// <summary>
        /// Updates an API key
        /// </summary>
        /// <param name="id">      The API key ID </param>
        /// <param name="request"> The update API key request </param>
        /// <returns> The updated API key </returns>
        [HttpPut("{id}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<ApiKeyResponseDto>> Update(int id, [FromBody] UpdateApiKeyRequestDto request)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            var apiKey = await _apiKeyService.GetByIdAsync(id);

            if (apiKey == null)
            {
                return NotFound();
            }

            try
            {
                // Update properties
                apiKey.ClientName = request.ClientName;
                apiKey.ExpiresAt = request.ExpiresAt;
                apiKey.IsActive = request.IsActive;
                apiKey.AllowedIpAddresses = request.AllowedIpAddresses;

                var updatedApiKey = await _apiKeyService.UpdateAsync(apiKey);

                return Ok(MapToResponseDto(updatedApiKey));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error updating API key {Id}", id);
                return BadRequest(new { message = ex.Message });
            }
        }

        /// <summary>
        /// Deactivates an API key
        /// </summary>
        /// <param name="id"> The API key ID </param>
        /// <returns> No content </returns>
        [HttpPost("{id}/deactivate")]
        [ProducesResponseType(StatusCodes.Status204NoContent)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> Deactivate(int id)
        {
            var success = await _apiKeyService.DeactivateAsync(id);

            if (!success)
            {
                return NotFound();
            }

            return NoContent();
        }

        /// <summary>
        /// Rotates an API key
        /// </summary>
        /// <param name="id">      The API key ID </param>
        /// <param name="request"> The rotate API key request </param>
        /// <returns> The updated API key with the new key value </returns>
        [HttpPost("{id}/rotate")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<ApiKeyResponseDto>> Rotate(int id, [FromBody] RotateApiKeyRequestDto request)
        {
            try
            {
                var apiKey = await _apiKeyService.RotateAsync(id, request.GracePeriodDays);

                if (apiKey == null)
                {
                    return NotFound();
                }

                return Ok(MapToResponseDto(apiKey));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error rotating API key {Id}", id);
                return BadRequest(new { message = ex.Message });
            }
        }

        /// <summary>
        /// Maps an API key to a response DTO
        /// </summary>
        /// <param name="apiKey"> The API key </param>
        /// <returns> The API key response DTO </returns>
        private ApiKeyResponseDto MapToResponseDto(ApiKey apiKey)
        {
            return new ApiKeyResponseDto
            {
                Id = apiKey.Id,
                Key = apiKey.Key,
                ClientName = apiKey.ClientName,
                CreatedAt = apiKey.CreatedAt,
                ExpiresAt = apiKey.ExpiresAt,
                IsActive = apiKey.IsActive,
                LastUsedAt = apiKey.LastUsedAt,
                AllowedIpAddresses = apiKey.AllowedIpAddresses,
                Version = apiKey.Version,
                HasPreviousKey = !string.IsNullOrEmpty(apiKey.PreviousKey),
                PreviousKeyExpiresAt = apiKey.PreviousKeyExpiresAt
            };
        }
    }
}