using CymBuild_Outlook_API.Data;
using CymBuild_Outlook_Common.Dto;
using CymBuild_Outlook_Common.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

namespace CymBuild_Outlook_API.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class CombinedRecordSearchController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly LoggingHelper _loggingHelper;
        private readonly IMemoryCache _cache;

        public CombinedRecordSearchController(AppDbContext context, LoggingHelper loggingHelper, IMemoryCache cache)
        {
            _context = context;
            _loggingHelper = loggingHelper;
            _cache = cache;
        }

        [HttpPost]
        public async Task<IActionResult> Search([FromBody] RecordSearchDto searchRequest)
        {
            string cacheKey = $"{searchRequest.UserId}_{searchRequest.SearchString}";

            if (!_cache.TryGetValue(cacheKey, out (List<RecordSearchResult> GridData, List<FilingRecordSearchResult> FiledRecords) cachedData))
            {
                // Data not found in cache, load from API
                try
                {
                    _loggingHelper.LogInfo($"CombinedRecordSearch called with parameters: UserId={searchRequest.UserId}, SearchString={searchRequest.SearchString}", "Search(RecordSearchDto searchRequest)");

                    var recordSearchResultsTask = _context.SearchRecords(
                        searchRequest.UserId,
                        searchRequest.SearchString,
                        searchRequest.EntityTypeGuid,
                        searchRequest.ToAddressesCSV,
                        searchRequest.FromAddress,
                        searchRequest.Subject).ToListAsync();

                    var filedRecordSearchResultsTask = _context.SearchFiledRecordsAsync(searchRequest.MessageId);

                    await Task.WhenAll(recordSearchResultsTask, filedRecordSearchResultsTask);

                    cachedData = (recordSearchResultsTask.Result, filedRecordSearchResultsTask.Result);

                    // Cache data
                    var cacheOptions = new MemoryCacheEntryOptions().SetSlidingExpiration(TimeSpan.FromMinutes(5));
                    _cache.Set(cacheKey, cachedData, cacheOptions);

                    _loggingHelper.LogInfo($"CombinedRecordSearch completed successfully. Result count: GridData={cachedData.GridData.Count}, FiledRecords={cachedData.FiledRecords.Count}", "Search(RecordSearchDto searchRequest)");
                }
                catch (Exception ex)
                {
                    _loggingHelper.LogError($"Error occurred during combined record search", ex, "Search(RecordSearchDto searchRequest)");
                    return StatusCode(500, "Internal server error");
                }
            }

            return Ok(cachedData);
        }
    }
}