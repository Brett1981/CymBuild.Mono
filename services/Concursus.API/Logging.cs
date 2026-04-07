using Microsoft.Data.SqlClient;

namespace Concursus.API;

public class Logging
{
    #region Private Fields

    private readonly string _dbConnectionString;
    private readonly bool _logDebug = false;
    private readonly ILogger _logger;
    private readonly string _loggingLevel;
    private readonly bool _logInformation = false;
    private readonly bool _logTrace = false;
    private readonly bool _logWarning = false;
    private readonly Guid _processGuid;
    private long _thredId = 1;
    private int _userId = -1;

    #endregion Private Fields

    #region Public Constructors

    public Logging(ILogger logger, IConfiguration config)
    {
        _logger = logger;
        _dbConnectionString = config.GetConnectionString("ShoreDb") ?? "";
        var loggingSection = config.GetSection("Logging");

        _loggingLevel = "Warning";

        if (loggingSection != null)
        {
            var logLevelSection = loggingSection.GetSection("LogLevel");

            if (logLevelSection != null) _loggingLevel = logLevelSection.GetValue<string>("Default") ?? "";
        }

        switch (_loggingLevel)
        {
            case "Trace":
                _logTrace = true;
                _logDebug = true;
                _logInformation = true;
                _logWarning = true;
                break;

            case "Debug":
                _logDebug = true;
                _logInformation = true;
                _logWarning = true;
                break;

            case "Information":
                _logInformation = true;
                _logWarning = true;
                break;

            case "Warning":
                _logWarning = true;
                break;

            default:
                break;
        }

        // generate a new Process Guid
        _processGuid = Guid.NewGuid();
    }

    #endregion Public Constructors

    #region Public Properties

    public long ThreadId
    {
        get => _thredId;
        set => _thredId = value;
    }

    public int UserId
    {
        get => _userId;
        set => _userId = value;
    }

    public string innerException { get; private set; } = "";

    #endregion Public Properties

    #region Public Methods

    public void LogDebug(string message)
    {
        _logger.LogDebug(message);

        if (_logDebug) WriteSystemLog("Debug", message, "", "");
    }

    public void LogError(string message)
    {
        _logger.LogError(message);
        WriteSystemLog("Error", message, "", "");
    }

    public void LogException(Exception exception, string preMessage = "")
    {
        if(_logger is null)
        {
            return;
        }
        _logger.LogError(preMessage + exception.Message);
        if (exception.Data.Contains("SQL"))
        {
            innerException += "\nSQL: " + exception.Data["SQL"];
        }
        if (_logDebug)
        {
            if (exception.InnerException is not null)
            {
                _logger.LogDebug(exception.InnerException.Message);
            }
            else if (!string.IsNullOrEmpty(innerException))
            {
                _logger.LogDebug(innerException);
            }
            else
            {
                _logger.LogDebug(preMessage + exception.StackTrace);
            }
        }

        if (exception.InnerException is not null)
            WriteSystemLog("Error", preMessage + exception.Message, exception.InnerException.Message, exception.StackTrace ?? "");
        else if (!string.IsNullOrEmpty(innerException))
            WriteSystemLog("Error", preMessage + exception.Message, innerException, exception.StackTrace ?? "");
        else
            WriteSystemLog("Error", preMessage + exception.Message, "", exception.StackTrace ?? "");
    }

    public void LogHttpRequest(HttpContext httpContext)
    {
        LogDebug(httpContext.Request.Path + " request from " + httpContext.Request.Host.ToString());
    }

    public void LogInformation(string message)
    {
        _logger.LogInformation(message);

        if (_logInformation) WriteSystemLog("Information", message, "", "");
    }

    public void LogTrace(string message)
    {
        _logger.LogTrace(message);

        if (_logTrace) WriteSystemLog("Trace", message, "", "");
    }

    public void LogWarning(string message)
    {
        _logger.LogWarning(message);

        if (_logWarning) WriteSystemLog("Warning", message, "", "");
    }

    #endregion Public Methods

    #region Private Methods

    private async void WriteSystemLog(string severity, string message, string innerMessage, string stackTrace)
    {
        try
        {
            using (SqlConnection sqlConnection = new(_dbConnectionString))
            {
                await sqlConnection.OpenAsync();

                using (var sqlTransaction = sqlConnection.BeginTransaction())
                {
                    var statement = "EXECUTE SCore.SystemLogCreate " +
                                    "@DateTime = @DateTime, @Severity = @Severity, @Message = @Message, @InnerMessage = @InnerMessage, @StackTrace= @StackTrace, @ProcessGuid = @ProcessGuid, @UserId = @UserId, @ThreadId = @ThreadId";

                    using (var command = sqlConnection.CreateCommand())
                    {
                        command.Transaction = sqlTransaction;
                        command.CommandText = statement;

                        command.Parameters.Add(new SqlParameter("DateTime", DateTime.Now));
                        command.Parameters.Add(new SqlParameter("Severity", severity));
                        command.Parameters.Add(new SqlParameter("Message", message));
                        command.Parameters.Add(new SqlParameter("InnerMessage", innerMessage));
                        command.Parameters.Add(new SqlParameter("StackTrace", stackTrace));
                        command.Parameters.Add(new SqlParameter("ProcessGuid", _processGuid));
                        command.Parameters.Add(new SqlParameter("UserId", _userId));
                        command.Parameters.Add(new SqlParameter("ThreadId", _thredId));

                        await command.ExecuteNonQueryAsync();
                    }

                    await sqlTransaction.CommitAsync();
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex.Message);

            if (_logDebug) _logger.LogDebug(ex.StackTrace);
        }
    }

    #endregion Private Methods
}