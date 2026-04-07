using Concursus.API.Core;
using Microsoft.Data.SqlClient;

namespace Concursus.API.ValidationAndControl;

internal class SecurableGroupPermission : ValidationAndControlBase
{
    #region Public Constructors

    public SecurableGroupPermission(System.Security.Claims.ClaimsPrincipal user) : base(user)
    {
        mainTableSchema = "SCore";
        mainTableName = "SecurableGroupPermissions";
    }

    #endregion Public Constructors

    #region Public Methods

    public override void Process(ref DataObject dataObject, SqlConnection sqlConnection, SqlTransaction sqlTransaction)
    {
        base.Process(ref dataObject, sqlConnection, sqlTransaction);
    }

    #endregion Public Methods
}