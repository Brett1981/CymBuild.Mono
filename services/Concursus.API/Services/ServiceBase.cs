using Grpc.Core;

namespace Concursus.API.Services;

public class ServiceBase
{
    #region Public Fields

    public readonly IConfiguration _config;
    public IHttpContextAccessor _httpContextAccessor;
    public bool _useLegacyUserTables;
    public int _userId = -1;
    public Logging logger;

    #endregion Public Fields

    #region Internal Fields

    internal readonly EF.Core _entityFramework;

    #endregion Internal Fields

    #region Private Fields

    private readonly System.Security.Principal.IIdentity _identity;
    private readonly System.Security.Claims.ClaimsPrincipal _user;

    #endregion Private Fields

    #region Public Constructors

    public ServiceBase(IConfiguration config, IHttpContextAccessor httpContextAccessor, Logging logger)
    {
        try
        {
            _config = config;
            _httpContextAccessor = httpContextAccessor;
            this.logger = logger;

            if (httpContextAccessor.HttpContext != null)
            {
                _user = httpContextAccessor.HttpContext.User;

                if (_user.Identity != null)
                    _identity = _user.Identity;
                else
                    throw new Exception("Failed to get user identity");
            }
            else
            {
                throw new Exception("Failed to get user from Http Context.");
            }

            _useLegacyUserTables = _config.GetValue<bool>("UseLegacyUserTables", false);

            if (logger != null)
            {
                _entityFramework = new EF.Core(_config.GetConnectionString("ShoreDB") ?? "", User);

                logger.LogTrace("Service base initialised");
            }
            else
            {
                throw new Exception("The logger has not been provided.");
            }
        }
        catch (Exception ex)
        {
            if (logger != null) logger.LogException(ex);

            throw new RpcException(new Status(StatusCode.Unknown, ex.Message + " --- " + (ex.StackTrace ?? "")));
        }
    }

    #endregion Public Constructors

    #region Public Properties

    public System.Security.Principal.IIdentity Identity => _identity;

    public System.Security.Claims.ClaimsPrincipal User => _user;

    #endregion Public Properties

    #region Public Methods

    public static void CheckRowVersion(byte[] dbRowVersion, string modelRowVersion)
    {
        if (TestRowVersion(dbRowVersion, modelRowVersion) == false)
            throw new RpcException(new Status(StatusCode.FailedPrecondition,
                "RowVersion Error, another user may have changed this record."));
    }

    public static string StripPredicateFromQuery(string sqlQuery)
    {
        var predicateIndex = sqlQuery.IndexOf("WHERE");

        if (predicateIndex > 0) sqlQuery = sqlQuery[..predicateIndex];

        return sqlQuery;
    }

    public static bool TestRowVersion(byte[] dbRowVersion, string modelRowVersion)
    {
        var dbRowVersionString = Convert.ToBase64String(dbRowVersion);

        if (dbRowVersionString != modelRowVersion)
            return false;
        else
            return true;
    }

    #endregion Public Methods
}