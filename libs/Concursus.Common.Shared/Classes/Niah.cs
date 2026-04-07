namespace Concursus.Common.Shared.Classes
{
    public static class Niah
    {
        public static void WriteLine(string format, params object[] arguments)
        {
            var stackFrame = new System.Diagnostics.StackTrace(fNeedFileInfo: true).GetFrame(1);
            var filePath = stackFrame.GetFileName();
            var lineNumber = stackFrame.GetFileLineNumber();
            WriteLine(filePath, lineNumber, format, arguments);
        }

        public static void WriteLineNoFileInfo(string format, params object[] arguments)
        {
            WriteLine(null, 0, format, arguments);
        }

        // The first 4 chars are a signature that won't display in the VS output window, but the
        // Niah extension will pick them up and realize that some special info
        // following: first is the delimeter char (customizable), then the timestamp (milliseconds
        // since Jan 1 1970), then the process ID, then optionally the file path and file line.
        // Version 1.00: 1.4.1.1 & 1.4.1.2.
        private static void WriteLine(string filePath, int lineNumber, string format, params object[] arguments)
        {
            var payload = string.Format(format, arguments);
            var line = string.Empty;
            if (!string.IsNullOrEmpty(filePath))
            {
                line = string.Format("{0}{1}{2}{3}|{4}|{5}|{6}|{7}|{8}", (char)1, (char)4, (char)1, (char)2, timeNowInMs, thisProcessId, filePath, lineNumber, payload);
            }
            else
            {
                line = string.Format("{0}{1}{2}{3}|{4}|{5}|{6}", (char)1, (char)4, (char)1, (char)1, timeNowInMs, thisProcessId, payload);
            }
            System.Diagnostics.Debug.WriteLine(line);
        }

        private static long timeNowInMs => DateTime.Now.Ticks / TimeSpan.TicksPerMillisecond;
        private static int thisProcessId => System.Diagnostics.Process.GetCurrentProcess().Id;
    }
}