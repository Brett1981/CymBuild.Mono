namespace Concursus.EF.Types
{
    public class ProgressData
    {
        #region Public Properties

        public bool FirstComplete { get; set; }
        public string FirstDescription { get; set; } = "";
        public int FirstValue { get; set; }
        public bool LastComplete { get; set; }
        public string LastDescription { get; set; } = "";
        public int LastValue { get; set; }
        public bool MidComplete { get; set; }
        public string MidDescription { get; set; } = "";
        public int MidValue { get; set; }
        public bool NextComplete { get; set; }
        public string NextDescription { get; set; } = "";
        public int NextValue { get; set; }
        public bool PreviousComplete { get; set; }
        public string PreviousDescription { get; set; } = "";
        public int PreviousValue { get; set; }

        #endregion Public Properties
    }
}