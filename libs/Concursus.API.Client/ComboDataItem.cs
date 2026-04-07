using Concursus.API.Client.Classes;
using Concursus.API.Core;

namespace Concursus.API.Client;

public class ComboDataItem
{
    #region Public Constructors

    public ComboDataItem(DropDownDataListItem dropDownDataListItem)
    {
        Name = dropDownDataListItem.Name;
        Value = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(dropDownDataListItem.Value);
        Group = dropDownDataListItem.Group;
        ColourHex = dropDownDataListItem.ColourHex; //CBLD-570
    }

    #endregion Public Constructors

    #region Public Properties

    public string Group { get; set; }
    public string Name { get; set; }
    public Guid Value { get; set; }

    public string ColourHex { get; set; } //CBLD-570

    #endregion Public Properties
}