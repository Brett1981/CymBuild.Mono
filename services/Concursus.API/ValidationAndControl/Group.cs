using Concursus.API.Core;
using Microsoft.Data.SqlClient;

namespace Concursus.API.ValidationAndControl;

internal class Group : ValidationAndControlBase
{
    #region Public Constructors

    public Group(System.Security.Claims.ClaimsPrincipal user) : base(user)
    {
        mainTableSchema = "SCore";
        mainTableName = "Groups";
    }

    #endregion Public Constructors

    #region Public Methods

    public override void Process(ref DataObject dataObject, SqlConnection sqlConnection, SqlTransaction sqlTransaction)
    {
        base.Process(ref dataObject, sqlConnection, sqlTransaction);
    }

    #endregion Public Methods
}