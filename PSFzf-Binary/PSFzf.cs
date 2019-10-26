using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Management.Automation;
using System.Text;
using System.Threading.Tasks;

namespace PSFzf
{
    [Cmdlet(VerbsLifecycle.Invoke, "Fzf")]
    public class PSFzfCommand : Cmdlet
    {
        #region Parameters
        [Parameter(ValueFromPipeline = true)]
        public string[] Input { get; set; }

        // Search
        [Parameter()]
        [Alias("x")]
        public SwitchParameter Extended { get; set; } = true;

        [Parameter()]
        [Alias("e")]
        public SwitchParameter Exact { get; set; }

        [Parameter()]
        [Alias("i")]
        public SwitchParameter CaseInsensitive { get; set; }

        [Parameter()]
        public SwitchParameter CaseSensitive { get; set; }

        [Parameter()]
        [Alias("d")]
        public string Delimiter { get; set; }

        [Parameter()]
        [Alias("s")]
        public SwitchParameter NoSort { get; set; }

        [Parameter()]
        [Alias("tac")]
        public SwitchParameter ReverseInput { get; set; }

        [Parameter()]
        public string[] Tiebreak { get; set; } = new string[0] { };

        //Interface
        [Parameter()]
        [Alias("m")]
        public SwitchParameter Multi { get; set; }

        [Parameter()]
        public SwitchParameter NoMouse { get; set; }

        [Parameter()]
        public string Bind { get; set; }

        [Parameter()]
        public SwitchParameter Cycle { get; set; }

        [Parameter()]
        public SwitchParameter NoHScroll { get; set; }

        [Parameter()]
        public uint HScrollOff { get; set; } = 10;

        [Parameter()]
        public SwitchParameter FilePathWord { get; set; }

        /* TODO [Parameter()]
        public ?? JumpLabels
        */

        // Layout
        /* TODO 
        [Parameter()]
        public Height;

        [Parameter()]
        public MinHeight;
        */

        [Parameter()]
        [ValidateSet("", "default", "reverse", "reverse-list")]
        public string Layout { get; set; }

        [Parameter()]
        public SwitchParameter Border { get; set; }

        [Parameter()]
        [ValidateSet("", "TRBL", "TB,RL", "T,RL,B", "T,RL,B,L")]
        public string Margin { get; set; }

        [Parameter()]
        public SwitchParameter InlineInfo { get; set; }

        [Parameter()]
        public string Prompt { get; set; }

        [Parameter()]
        public string Header { get; set; }

        [Parameter()]
        public uint HeaderLines { get; set; }

        // Display 
        [Parameter()]
        public SwitchParameter Ansi { get; set; }

        [Parameter()]
        public uint Tabstop { get; set; } = 8;

        /* TODO 
        public ?? Color
        */

        [Parameter()]
        public SwitchParameter NoBold { get; set; }

        // History 
        [Parameter()]
        public string History { get; set; }

        [Parameter()]
        public uint HistorySize { get; set; } = 1000;

        // Preview 
        [Parameter()]
        public string Preview { get; set; }
        
        [Parameter()]
        public string PreviewWindow { get; set; }

        // Scripting
        [Parameter()]
        [Alias("q")]
        public string Query { get; set; }

        [Parameter()]
        [Alias("s1")]
        public SwitchParameter Select1 { get; set; }

        [Parameter()]
        [Alias("e0")]
        public SwitchParameter Exit0 { get; set; }

        [Parameter()]
        [Alias("f")]
        public string Filter { get; set; }
        
        [Parameter()]
        public SwitchParameter PrintQuery { get; set; }

        [Parameter()]
        public SwitchParameter Read0 { get; set; }

        [Parameter()]
        public SwitchParameter Print0 { get; set; }

        [Parameter()]
        public SwitchParameter Sync { get; set; }

        /*[Parameter()]
        public bool Version { get; set; }*/

        [Parameter()]
        public SwitchParameter ThrowCustomException { get; set; }
        #endregion

        private Process Process;
        private List<string> OutputStr = new List<string>();
        private string FileSystemDirectory =>  @"c:\";
            //this.SessionState.Path.CurrentFileSystemLocation.ProviderPath;

        private bool IsFileSystem => true;
            //SessionState.Path.CurrentFileSystemLocation.Provider.Name == "FileSystem";

        private static void AddArg(StringBuilder args, SwitchParameter val, string fzfArg)
        {
            if (val!=null && val.ToBool())
                args.Append(fzfArg);
        }

        private static void AddArg(StringBuilder args, string val, string fzfArg)
        {
            if (!String.IsNullOrEmpty(val))
                args.Append(fzfArg);
        }

        private static void AddArg(StringBuilder args, string[] val, string fzfArg)
        {
            if (val!=null && val.Length>0)
                args.Append(fzfArg);
        }
        private static void AddArg(StringBuilder args, uint _, string fzfArg)
        {
            args.Append(fzfArg);
        }

        protected override void BeginProcessing()
        {
            //var arguments = "";
            // set up arguments:
            var arguments = new StringBuilder();
            AddArg(arguments, Extended, "--extended ");
            AddArg(arguments, Exact, "--exact ");
            AddArg(arguments, CaseInsensitive, "-i ");
            AddArg(arguments, CaseSensitive, "+i ");
            AddArg(arguments, Delimiter, $"--delimiter={Delimiter} ");
            AddArg(arguments, NoSort, "--no-sort ");
            AddArg(arguments, ReverseInput, "--tac ");
            AddArg(arguments, Tiebreak, $"--tiebreak={string.Join(",",Tiebreak)} ");
            AddArg(arguments, Multi, "--multi ");
            AddArg(arguments, NoMouse, "--no-mouse ");
            AddArg(arguments, Bind, $"--bind={Bind} ");
            AddArg(arguments, Cycle, $"--cycle ");
            AddArg(arguments, NoHScroll, $"--no-hscroll ");
            AddArg(arguments, HScrollOff, $"--hscroll-off={HScrollOff} ");
            AddArg(arguments, FilePathWord, "--filepath-word ");
            AddArg(arguments, Layout, $"--layout={Layout} ");   
            AddArg(arguments, Border, "--border ");
            AddArg(arguments, Margin, $"--margin={Margin} ");
            AddArg(arguments, InlineInfo, "--inline-info ");
            AddArg(arguments, Prompt, $"--prompt={Prompt} ");
            AddArg(arguments, Header, $"--header={Header} ");
            AddArg(arguments, HeaderLines, $"--header-lines={HeaderLines} ");
            AddArg(arguments, Ansi, "--ansi ");
            AddArg(arguments, Tabstop, $"--tabstop={Tabstop} ");
            AddArg(arguments, NoBold, "--no-bold ");
            AddArg(arguments, History, $"--history={History}");
            AddArg(arguments, HistorySize, $"--history-size={HistorySize} ");
            AddArg(arguments, Preview, $"--preview={Preview} ");
            AddArg(arguments, PreviewWindow, $"--preview-window={PreviewWindow} ");
            AddArg(arguments, Query, $"--query={Query} ");
            AddArg(arguments, Select1, "--select-1 ");
            AddArg(arguments, Exit0, "--exit-0 ");
            AddArg(arguments, Filter, $"--filter={Filter} ");
            AddArg(arguments, PrintQuery, "--print-query ");
            AddArg(arguments, Read0, "--read0 ");
            AddArg(arguments, Print0, "--print0");
            AddArg(arguments, Sync, "--sync ");

            Process = new System.Diagnostics.Process
            {
                StartInfo = new ProcessStartInfo()
                {
                    FileName = FzfOptions.Options.FzfExeLocation,
                    Arguments = arguments.ToString(),
                    RedirectStandardError = true,
                    RedirectStandardInput = true,
                    RedirectStandardOutput = true,
                    UseShellExecute = false,
                    WorkingDirectory = this.FileSystemDirectory
              }
            };

            Process.OutputDataReceived += (_, e) => OutputStr.Add(e.Data);
 
            Process.Start();
            Process.BeginOutputReadLine();
        }

        protected override void ProcessRecord()
        {
            // if not input, get listing from current provider:
            if (Input == null)
            {
                if (IsFileSystem)
                {
                    //RunShellCmd();
                    RunProcess();
                }
                else
                {
                    RunGetChildItem();
                }
            }
            else
            {
                foreach (var item in Input)
                {
                    if (Process.HasExited)
                    {
                        FzfCompleted();
                        break;
                    }
  
                    if (!string.IsNullOrWhiteSpace(item))
                    {
                        Process.StandardInput.WriteLine(item);
                    }
                }
            }
        }

        private void RunShellCmd()
        {
            using (PowerShell ps = PowerShell.Create())
            {
                ps.AddCommand("Invoke-Expression");
                var cmd = FzfOptions.Options.GetFormattedShellCmd(FileSystemDirectory);
                ps.AddParameter("Command", cmd);

                var output = new PSDataCollection<PSObject>();
                output.DataAdded += Output_DataAddedString;
                IAsyncResult async = ps.BeginInvoke<PSObject, PSObject>(null, output);
                while (!async.IsCompleted)
                {
                    if (Process.HasExited)
                    {
                        FzfCompleted();
                    }
                    Task.Delay(100).Wait();
                }
            }
        }

        private void RunProcess()
        {
            using (var process = new Process())
            {
                process.StartInfo = new ProcessStartInfo
                {
                    FileName = "cmd.exe",
                    Arguments = "/S /C " + FzfOptions.Options.GetFormattedFileSystemCmd(
                        FileSystemDirectory),
                    UseShellExecute = false,
                    RedirectStandardOutput = true
                };
                process.OutputDataReceived += Process_OutputDataReceived;
                process.Start();
                process.BeginOutputReadLine();
                while (!process.HasExited)
                {
                    if (Process.HasExited)
                    {
                        process.CancelOutputRead();
                        process.Kill();
                        FzfCompleted();
                        break;
                    }
                    Task.Delay(100).Wait();
                }
            }
        }

        private void Process_OutputDataReceived(object sender, DataReceivedEventArgs e)
        {
            if (!string.IsNullOrWhiteSpace(e.Data) && !Process.HasExited)
            {
                Process.StandardInput.WriteLine(e.Data);
            }
        }

        private void RunGetChildItem()
        {
            using (PowerShell ps = PowerShell.Create())
            {
                ps.AddCommand("Get-ChildItem");
                ps.AddParameter("Path", ".");
                ps.AddParameter("Recurse");
                ps.AddParameter("ErrorAction", "SilentlyContinue");

                var output = new PSDataCollection<PSObject>();
                output.DataAdded += Output_DataAdded;
                IAsyncResult async = ps.BeginInvoke<PSObject, PSObject>(null, output);
                while (!async.IsCompleted)
                {
                    if (Process.HasExited)
                    {
                        FzfCompleted();
                        break;
                    }
                    Task.Delay(100).Wait();
                }
            }
        }


        private void Output_DataAddedString(object sender, DataAddedEventArgs _)
        {
            var myp = (PSDataCollection<PSObject>)sender;

            Collection<PSObject> results = myp.ReadAll();
            foreach (PSObject result in results)
            {
                string str = result.ToString();

                if (Process.HasExited)
                {
                    FzfCompleted();
                    break;
                }

                if (!string.IsNullOrWhiteSpace(str))
                {
                    Process.StandardInput.WriteLine(str);
                }
            }
        }

        private void Output_DataAdded(object sender, DataAddedEventArgs _)
        {
            var myp = (PSDataCollection<PSObject>)sender;

            Collection<PSObject> results = myp.ReadAll();
            foreach (PSObject result in results)
            {
                var member = result.Members["FullName"];
                member = member ?? result.Members["Name"];
                string str = member?.Value?.ToString() ?? result.ToString();

                if (Process.HasExited)
                {
                    FzfCompleted();
                    break;
                }

                if (!string.IsNullOrWhiteSpace(str))
                {
                    Process.StandardInput.WriteLine(str);
                }
            }
        }

        protected override void StopProcessing()
        {
            FzfCompleted(throwException: false);
        }

        protected override void EndProcessing()
        {
            while (!Process.HasExited)
                ;
            FzfCompleted(throwException: false);
        }

        private void FzfCompleted(bool throwException=true)
        {
            foreach (var s in OutputStr)
            {
                WriteObject(s);
            }
            OutputStr.Clear();
           
            Process?.StandardInput?.Close();
            if (throwException)
            {
                if (ThrowCustomException)
                    throw new FzfPipelineException();
                else
                    throw new PipelineStoppedException();
            }
        }
    }

    /// <summary>
    /// C
    /// </summary>
    public class FzfPipelineException : System.Exception
    {

    }
}
