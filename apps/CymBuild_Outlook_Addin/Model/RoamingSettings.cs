namespace CymBuild_Outlook_Addin.Model
{
    public class RoamingSettings
    {
        public Dictionary<string, string> Settings { get; set; }

        public RoamingSettings()
        {
            Settings = new Dictionary<string, string>();
        }

        public string Get(string key)
        {
            return Settings.ContainsKey(key) ? Settings[key] : null;
        }

        public void Set(string key, string value)
        {
            Settings[key] = value;
        }

        public void Remove(string key)
        {
            if (Settings.ContainsKey(key))
            {
                Settings.Remove(key);
            }
        }
    }
}