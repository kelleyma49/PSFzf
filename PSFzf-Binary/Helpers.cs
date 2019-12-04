using System;
using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;
using System.Text;

namespace PSFzf
{
    public static class Helpers
    {
        static public IEnumerable<string> CompleteInput(string input, int cursorIndex, Hashtable options)
        {
            System.Management.Automation.PowerShell ps;
            ps = System.Management.Automation.PowerShell.Create(RunspaceMode.CurrentRunspace);
            
            var completion = CommandCompletion.CompleteInput(input, cursorIndex, options, ps);
            var matches = completion?.CompletionMatches;
            if (matches?.Count>0 && (matches[0]?.ResultType == CompletionResultType.ProviderItem || matches[0]?.ResultType == CompletionResultType.ProviderContainer))
            {
                yield return "blah";
            }
            else if (matches != null)
            {
                foreach (var item in matches)
                {
                    yield return item.CompletionText;
                }
            }
        }

    }
}
