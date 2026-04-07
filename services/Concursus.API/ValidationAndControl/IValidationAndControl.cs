using Concursus.API.Core;
using Microsoft.Data.SqlClient;

namespace Concursus.API.ValidationAndControl;

public interface IValidationAndControl
{
    #region Public Properties

    public EntityType entityType { get; set; }
    public string mainTableName { get; set; }
    public string mainTableSchema { get; set; }

    #endregion Public Properties

    #region Public Methods

    public void Process(ref DataObject dataObject, SqlConnection sqlConnection, SqlTransaction sqlTransaction);

    #endregion Public Methods
}