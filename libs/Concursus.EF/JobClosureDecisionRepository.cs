using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using System.Data;

namespace Concursus_EF;

public sealed class JobClosureDecisionRepository
{
    private readonly string _connectionString;
    private readonly ILogger<JobClosureDecisionRepository> _logger;

    public JobClosureDecisionRepository(IConfiguration config, ILoggerFactory loggerFactory)
    {
        _connectionString = config.GetConnectionString("ShoreDB")
            ?? throw new InvalidOperationException("ShoreDB missing.");
        _logger = loggerFactory.CreateLogger<JobClosureDecisionRepository>();
    }

    public sealed record Result(bool Success, string Message, string StoredComment, DateTime DecisionDateTimeUtc);

    public async Task<Result> ApplyDecisionAsync(Guid jobGuid, int authoriserUserId, byte decision, string? comment, CancellationToken ct = default)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(ct);

        await using var cmd = conn.CreateCommand();
        cmd.CommandType = CommandType.StoredProcedure;
        cmd.CommandText = "SJob.usp_JobClosureDecision";

        cmd.Parameters.Add(new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = jobGuid });
        cmd.Parameters.Add(new SqlParameter("@AuthoriserUserId", SqlDbType.Int) { Value = authoriserUserId });
        cmd.Parameters.Add(new SqlParameter("@Decision", SqlDbType.TinyInt) { Value = decision });
        cmd.Parameters.Add(new SqlParameter("@Comment", SqlDbType.NVarChar, 2000) { Value = (object?)comment ?? DBNull.Value });

        var storedComment = new SqlParameter("@StoredComment", SqlDbType.NVarChar, 2000) { Direction = ParameterDirection.Output };
        var decisionUtc = new SqlParameter("@DecisionDateTimeUtc", SqlDbType.DateTime2) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(storedComment);
        cmd.Parameters.Add(decisionUtc);

        try
        {
            await cmd.ExecuteNonQueryAsync(ct);

            var sc = storedComment.Value?.ToString() ?? string.Empty;
            var dt = decisionUtc.Value is DateTime d ? d : DateTime.UtcNow;

            return new Result(true, "Decision applied successfully.", sc, dt);
        }
        catch (SqlException ex)
        {
            _logger.LogError(ex, "JobClosureDecision failed JobGuid={JobGuid} Decision={Decision}", jobGuid, decision);
            return new Result(false, ex.Message, "", DateTime.UtcNow);
        }
    }
}
