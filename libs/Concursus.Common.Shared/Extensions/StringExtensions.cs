using Concursus.Common.Shared.Classes;
using System.Reflection;

namespace Concursus.Common.Shared.Extensions;

public static class StringExtensions
{
    #region Public Methods

    public static T? GetAttributeOfType<T>(this Enum enumVal) where T : Attribute
    {
        var typeInfo = enumVal.GetType().GetTypeInfo();
        var v = typeInfo.DeclaredMembers.FirstOrDefault(x => x.Name == enumVal.ToString());

        if (v != null)
        {
            var attribute = v.GetCustomAttribute<T>();
            return attribute;
        }

        return null;
    }

    public static string GetDescription(this Enum enumVal)
    {
        var attr = enumVal.GetAttributeOfType<DescriptionAttribute>();
        return attr != null ? attr.Text : string.Empty;
    }

    public static string TruncateAtWord(this string input, int length)
    {
        if (input == null || input.Length < length)
            return input ?? "";
        var iNextSpace = input.LastIndexOf(" ", length, StringComparison.Ordinal);
        return string.Format("{0} ...", input[..(iNextSpace > 0 ? iNextSpace : length)].Trim());
    }

    #endregion Public Methods
}