using System;
using System.Collections.Generic;
using System.Management.Automation;
using System.Text;

namespace PSFzf
{
    class FzfOptions 
    {
        public string ShellCmd { get; set; }
        public string DefaultFileSystemCmd { get; set; }
        public string FzfExeLocation { get; set; }

        string _ChordProvider;
        public string ChordProvider {
            get => _ChordProvider;
            set
            {
                _ChordProvider = value;
                ChordProviderScriptBlock?.Invoke(value);
            }
        }
        public ScriptBlock ChordProviderScriptBlock { get; set; }

        string _ChordReverseHistory;
        public string ChordReverseHistory 
        {
            get => _ChordReverseHistory; 
            set
            {
                _ChordReverseHistory = value;
                ChordReverseHistoryScriptBlock?.Invoke(value);
            }
        }
        ScriptBlock ChordReverseHistoryScriptBlock { get; set; }

        string _ChordSetLocation;
        public string ChordSetLocation 
        {
            get => _ChordSetLocation; 
            set
            {
                _ChordSetLocation = value;
                ChordSetLocationScriptBlock?.Invoke(value);
            }
        }

        ScriptBlock ChordSetLocationScriptBlock { get; set; }

        string _ChordReverseHistoryArgs;
        public string ChordReverseHistoryArgs
        {
            get => _ChordReverseHistoryArgs;
            set
            {
                _ChordReverseHistoryArgs = value;
                ChordReverseHistoryArgsScriptBlock?.Invoke(value);
            }
        }

        public ScriptBlock ChordReverseHistoryArgsScriptBlock { get; set; }

        string FileSystemCmd
        {
            get
            {
                var envCmd = System.Environment.GetEnvironmentVariable("FZF_DEFAULT_COMMAND");
                if (string.IsNullOrWhiteSpace(envCmd))
                {
                    return DefaultFileSystemCmd;
                }
                else
                {
                    return envCmd;
                }
            }
        }

        internal string GetFormattedShellCmd(string dir) =>
            string.Format(ShellCmd, GetFormattedFileSystemCmd(dir));

        internal string GetFormattedFileSystemCmd(string dir) => 
            string.Format(FileSystemCmd, dir);

        public static FzfOptions Options { get; set; } = new FzfOptions();
    }

    [Cmdlet("Get", "FzfOption")]
    [OutputType(typeof(FzfOptions))]
    public class GetPSReadLineOption : Cmdlet
    {
        protected override void EndProcessing()
        {
            WriteObject(FzfOptions.Options);
        }
    }
}
