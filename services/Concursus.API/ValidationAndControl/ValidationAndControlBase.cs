using Concursus.API.Classes;
using Concursus.API.Core;
using Google.Protobuf.WellKnownTypes;
using Microsoft.Data.SqlClient;

namespace Concursus.API.ValidationAndControl;

public class ValidationAndControlBase : IValidationAndControl
{
    #region Protected Fields

    protected readonly System.Security.Claims.ClaimsPrincipal _user;

    #endregion Protected Fields

    #region Public Constructors

    public ValidationAndControlBase(System.Security.Claims.ClaimsPrincipal User)
    {
        _user = User;
        mainTableSchema = "";
        mainTableName = "";
        entityType = new EntityType();
    }

    #endregion Public Constructors

    #region Public Properties

    public EntityType entityType { get; set; }
    public string mainTableName { get; set; }
    public string mainTableSchema { get; set; }

    #endregion Public Properties

    /*public void ProcessObjectForService(object obj, SqlConnection sqlConnection, SqlTransaction sqlTransaction)
    {
        bool hasValidationErrors = false;
        string validationMessage = "";

        List<Core.ValidationAndControlObject> lvc = new();

        foreach (var propertyinfo in obj.GetType()
            .GetProperties(System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance))
        {
            Core.ValidationAndControlObject vac = new();
            vac.PropertyName = propertyinfo.Name;
            var objVal = propertyinfo.GetValue(obj, null);
            if (objVal is not null)
            {
                if (objVal.GetType() == typeof(Timestamp))
                {
                    vac.PropertyValue = ((Timestamp)objVal).ToDateTime().ToString();
                }
                else
                {
                    vac.PropertyValue = objVal.ToString();
                }
            }
            else
            {
                vac.PropertyValue = "";
            }
            vac.IsEnabled = true;
            vac.IsInvalid = false;
            vac.IsReadOnly = false;
            vac.IsRestricted = false;

            lvc.Add(vac);
        }

        lvc = Process(lvc, sqlConnection, sqlTransaction);

        foreach (Core.ValidationAndControlObject vc in lvc)
        {
            if (vc.IsInvalid)
            {
                hasValidationErrors = true;

                if (validationMessage != "")
                {
                    validationMessage += " \n";
                }

                validationMessage += vc.ValidationMessage;
            }
        }

        if (hasValidationErrors)
        {
            throw new RpcException(new Status(StatusCode.FailedPrecondition, validationMessage));
        }
    }*/

    #region Public Methods

    public virtual void Process(ref DataObject dataObject, SqlConnection sqlConnection, SqlTransaction sqlTransaction)
    {
        ValidateRowVersion(ref dataObject, sqlConnection, sqlTransaction);
    }

    #endregion Public Methods

    #region Protected Methods

    protected void ValidateRowVersion(ref DataObject dataObject, SqlConnection sqlConnection,
        SqlTransaction sqlTransaction)
    {
        var RowVersionPropertyGuid =
            Guid.Parse(entityType.EntityProperties.Where(p => p.Name == "RowVersion").First().Guid);
        var modelRowVersion = dataObject.DataProperties
            .Where(x => x.EntityPropertyGuid == Functions.ParseAndReturnEmptyGuidIfInvalid(RowVersionPropertyGuid.ToString()).ToString()).First().Value.Unpack<StringValue>()
            .Value;

        byte[] currentRowVersion;

        var cmdText = "SELECT RowVersion FROM [" + mainTableSchema + "].[" + mainTableName + "] WHERE ([Guid] = '" +
                      Functions.ParseAndReturnEmptyGuidIfInvalid(dataObject.Guid).ToString() + "');";
        SqlCommand sqlCommand = new(cmdText, sqlConnection, sqlTransaction);
        currentRowVersion = (byte[])sqlCommand.ExecuteScalar();

        if (Services.ServiceBase.TestRowVersion(currentRowVersion, modelRowVersion) == false)
            foreach (var dp in dataObject.DataProperties)
                // set all properties to read only
                dp.IsReadOnly = true;
        // item.ValidationMessage = "You are not editing the most recent version of this record.
        // Please reload the record before attempting to make changes.";
    }

    #endregion Protected Methods
}