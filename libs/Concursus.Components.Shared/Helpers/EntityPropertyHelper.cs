using Concursus.API.Core;

namespace Concursus.Components.Shared.Helpers
{
    public static class EntityPropertyHelper
    {
        public static void Update(List<EntityProperty> props, string key, string value)
        {
            var prop = props?.FirstOrDefault(p => p.Name == key);
            if (prop != null)
            {
                prop.Value = value;
            }
        }

        public static void Update(List<EntityProperty> props, string key, bool value)
        {
            Update(props, key, value ? "true" : "false");
        }

        public static string GetValue(List<EntityProperty> props, string key)
        {
            return props?.FirstOrDefault(p => p.Name == key)?.Value ?? string.Empty;
        }

        public static bool GetValueAsBool(List<EntityProperty> props, string key)
        {
            var val = GetValue(props, key);
            return val?.ToLower() == "true";
        }
    }
}