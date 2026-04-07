using System.ComponentModel;

namespace Concursus.Common.Shared.Helpers;

/// <summary>
/// Enum Helper, Used to assist with Enums and Enum manipulation
/// </summary>
public static class EnumHelper
{
    #region Public Methods

    /// <summary>
    /// Retrive the Description of the supplied object Enum
    /// </summary>
    /// <returns> Description set on Enum </returns>
    public static string GetEnumDescription(object value)
    {
        DescriptionAttribute[] customAttributes = (DescriptionAttribute[])value.GetType().GetField(value.ToString())
            .GetCustomAttributes(typeof(DescriptionAttribute), false);
        if (customAttributes.Length > 0)
            return customAttributes[0].Description;
        return value.ToString();
    }

    /// <summary>
    /// Retrive the Tag from the Description of the supplied description Enum
    /// </summary>
    /// <returns> Tag set on Description </returns>
    public static string GetEnumTagFromDescription(string description)
    {
        return ConvertStringToTitleCase(description);
    }

    #endregion Public Methods

    #region Private Methods

    private static string ConvertStringToTitleCase(string s)
    {
        if (s == null)
            return s;
        string[] strArray = s.Split(' ');
        for (var index = 0; index < strArray.Length; ++index)
            if (strArray[index].Length != 0)
            {
                var upper = char.ToUpper(strArray[index][0]);
                var str = "";
                if (strArray[index].Length > 1)
                    str = strArray[index].Substring(1).ToLower();
                strArray[index] = ((int)upper).ToString() + str;
            }

        return string.Join("", strArray);
    }

    #endregion Private Methods
}