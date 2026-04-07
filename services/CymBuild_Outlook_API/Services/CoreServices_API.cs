using Concursus.EF.Types;
using CymBuild_Outlook_API.Data;
using CymBuild_Outlook_Common.Helpers;
using CymBuild_Outlook_Common.Models.SharePoint;
using System.Security.Claims;

namespace CymBuild_Outlook_API.Services
{
    public class CoreServices_API
    {
        private readonly IConfiguration _configuration;
        private readonly AppDbContext _dbContext;
        private readonly Concursus.EF.Core? _entityFramework;
        private readonly IMSGraphBase _msGraphBase;
        private readonly LoggingHelper _loggingHelper;

        public CoreServices_API(
            AppDbContext dbContext,
            IConfiguration configuration,
            Concursus.EF.Core? entityFramework,
            IMSGraphBase msGraphBase,
            LoggingHelper loggingHelper)
        {
            _dbContext = dbContext;
            _configuration = configuration;
            _entityFramework = entityFramework;
            _msGraphBase = msGraphBase;
            _loggingHelper = loggingHelper;
        }

        /// <summary>
        /// If Concursus.EF.Core is registered as Scoped in DI, we use it.
        /// Otherwise we create one using the passed ClaimsPrincipal.
        /// </summary>
        private Concursus.EF.Core ResolveCore(IConfiguration config, ClaimsPrincipal user)
        {
            if (_entityFramework != null)
                return _entityFramework;

            var cs = config.GetConnectionString("DefaultConnection");
            if (string.IsNullOrWhiteSpace(cs))
                throw new InvalidOperationException("DefaultConnection string is missing.");

            return new Concursus.EF.Core(cs, user);
        }

        public async Task<DataObjectGetResponse> DataObjectGet(
            DataObjectGetRequest request,
            IConfiguration config,
            ServiceBase serviceBase,
            ClaimsPrincipal user)
        {
            try
            {
                var core = ResolveCore(config, user);

                // Normalise EntityQueryGuid
                var entityQueryGuid = CymBuild_Outlook_Common.Functions.Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityQueryGuid);
                var entityTypeGuid = CymBuild_Outlook_Common.Functions.Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityTypeGuid);

                if (entityQueryGuid == Guid.Empty)
                    request.EntityQueryGuid = Guid.Empty.ToString();

                // ------------------------------------------------------------
                // IMPORTANT: the proto only supports returning ONE DataObject.
                // If ObjectGuids is supplied with more than 1 guid, we must fail
                // explicitly rather than silently returning partial data.
                // ------------------------------------------------------------
                if (request.ObjectGuids != null && request.ObjectGuids.Count > 0)
                {
                    if (request.ObjectGuids.Count > 1)
                    {
                        var msg = "Batch DataObjectGet is not supported by DataObjectGetResponse (it can only return a single DataObject).";
                        _loggingHelper.LogError(msg, new Exception(msg), "CoreServices_API.DataObjectGet()");
                        return new DataObjectGetResponse { ErrorReturned = msg };
                    }

                    // Exactly 1 guid supplied in ObjectGuids -> treat as single-get
                    request.Guid = request.ObjectGuids[0];
                }

                // Single object (use request.Guid)
                var objectGuid = CymBuild_Outlook_Common.Functions.Functions.ParseAndReturnEmptyGuidIfInvalid(request.Guid);

                var dataObject = await core.DataObjectGet(
                    objectGuid,
                    entityQueryGuid,
                    entityTypeGuid,
                    request.ForInformationView);

                if (dataObject != null && dataObject.HasDocuments)
                {
                    // SharePointHelper should be DI-friendly now (no IDisposable / no manual dispose).
                    var sharePointHelper = new SharePointHelper(_dbContext, config, _msGraphBase, _loggingHelper);

                    var update = await sharePointHelper.GetSharePointLocation(dataObject, core);

                    if (update?.DataObject != null &&
                        update.DataObject.DataProperties != null &&
                        update.DataObject.DataProperties.Count > 0)
                    {
                        dataObject = update.DataObject;
                    }
                }

                return new DataObjectGetResponse { DataObject = dataObject };
            }
            catch (Exception ex)
            {
                var preMessage = $"Error in DataObjectGet: EntityTypeGuid-{request.EntityTypeGuid}|Guid-{request.Guid} | ";
                _loggingHelper.LogError(preMessage, ex, "CoreServices_API.DataObjectGet()");
                return new DataObjectGetResponse { ErrorReturned = preMessage + ex.Message };
            }
        }

        public async Task<User> GetUserInfo(string email)
        {
            if (_entityFramework == null)
                throw new InvalidOperationException("Concursus.EF.Core is not available to resolve user info.");

            var userInfo = await _entityFramework.GetUserInfo(Guid.Empty, email);
            return userInfo;
        }
    }
}
