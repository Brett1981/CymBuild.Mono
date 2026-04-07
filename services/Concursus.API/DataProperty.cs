namespace Concursus.API.Core;

public partial class DataProperty
{
    #region Public Methods

    public void SetValidation(string validationMessage)
    {
        IsInvalid = true;
        ValidationMessage = validationMessage;
    }

    #endregion Public Methods
}