using Concursus.API.Core;
using Google.Protobuf.WellKnownTypes;
using Microsoft.Data.SqlClient;

namespace Concursus.API.ValidationAndControl;

internal class UserPreferences : ValidationAndControlBase
{
    #region Public Constructors

    public UserPreferences(System.Security.Claims.ClaimsPrincipal user) : base(user)
    {
        mainTableSchema = "SCore";
        mainTableName = "UserPreferences";
    }

    #endregion Public Constructors

    #region Public Methods

    public override void Process(ref DataObject dataObject, SqlConnection sqlConnection, SqlTransaction sqlTransaction)
    {
        base.Process(ref dataObject, sqlConnection, sqlTransaction);

        // Auto file mins must be >= 0
        var int32Value = dataObject.DataProperties.Where(p => p.EntityPropertyGuid == "").First().Value
            .Unpack<Int32Value>();
        if (int32Value.Value < 0)
            dataObject.DataProperties.Where(p => p.EntityPropertyGuid == "").First()
                .SetValidation("Auto file minutes must be greater then or equal to 0.");
    }

    #endregion Public Methods
}