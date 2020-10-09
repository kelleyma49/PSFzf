using System.Collections;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Management.Automation;

namespace PSFzf.IO
{
    /// <summary>
    /// Takes an encoding (defaulting to UTF-8) and a function which produces a seekable stream
    /// (or a filename for convenience) and yields lines from the end of the stream backwards.
    /// Only single byte encodings, and UTF-8 and Unicode, are supported. The stream
    /// returned by the function must be seekable.
    /// </summary>
    public sealed class CompletionHelpers
    {
        private static bool IsQuoted(string s)
        {
            if (s.Length >= 2)
            {
                //consider possible '& ' prefix
                var first = (s.Length > 4 && s.StartsWith("& ")) ? s[2] : s[0];
                var last = s[s.Length - 1];

                return (IsSingleQuote(first) && IsSingleQuote(last)) ||
                       (IsDoubleQuote(first) && IsDoubleQuote(last));
            }
            return false;
        }

        private static bool IsSingleQuote(char c) => c == '\'' || c == (char)8216 || c == (char)8217 || c == (char)8218 || c == (char)8219;
        private static bool IsDoubleQuote(char c) => c == '"' || c == (char)8220 || c == (char)8221 || c == (char)8222;

        // variable can be "quoted" like ${env:CommonProgramFiles(x86)}
        private static bool IsQuotedVariable(string s) => s.Length > 2 && s[1] == '{' && s[s.Length - 1] == '}';

        private static string GetUnquotedText(string s, bool consistentQuoting)
        {
            if (!consistentQuoting && IsQuoted(s))
            {
                //consider possible '& ' prefix
                int startindex = s.StartsWith("& ") ? 3 : 1;
                s = s.Substring(startindex, s.Length - startindex - 1);
            }
            return s;
        }

        private static string GetUnquotedText(CompletionResult match, bool consistentQuoting)
        {
            var s = match.CompletionText;
            if (match.ResultType == CompletionResultType.Variable)
            {
                if (IsQuotedVariable(s))
                {
                    return s[0] + s.Substring(2, s.Length - 3);
                }
                return s;
            }
            return GetUnquotedText(s, consistentQuoting);
        }

        private bool IsConsistentQuoting(Collection<CompletionResult> matches)
        {
            int quotedCompletions = matches.Count(match => IsQuoted(match.CompletionText));
            return
                quotedCompletions == 0 ||
                (quotedCompletions == matches.Count &&
                 quotedCompletions == matches.Count(
                    m => m.CompletionText[0] == matches[0].CompletionText[0]));
        }

        public string GetUnambiguousPrefix(Collection<CompletionResult> matches, out bool ambiguous)
        {
            // Find the longest unambiguous prefix.  This might be the empty
            // string, in which case we don't want to remove any of the users input,
            // instead we'll immediately show possible completions.
            // For the purposes of unambiguous prefix, we'll ignore quotes if
            // some completions aren't quoted.
            ambiguous = false;
            var firstResult = matches[0];
            bool consistentQuoting = IsConsistentQuoting(matches);

            var replacementText = GetUnquotedText(firstResult, consistentQuoting);
            foreach (var match in matches.Skip(1))
            {
                var matchText = GetUnquotedText(match, consistentQuoting);
                for (int i = 0; i < replacementText.Length; i++)
                {
                    if (i == matchText.Length
                        || char.ToLowerInvariant(replacementText[i]) != char.ToLowerInvariant(matchText[i]))
                    {
                        ambiguous = true;
                        replacementText = replacementText.Substring(0, i);
                        break;
                    }
                }
                if (replacementText.Length == 0)
                {
                    break;
                }
            }
            if (replacementText.Length == 0)
            {
                replacementText = firstResult.ListItemText;
                foreach (var match in matches.Skip(1))
                {
                    var matchText = match.ListItemText;
                    for (int i = 0; i < replacementText.Length; i++)
                    {
                        if (i == matchText.Length
                            || char.ToLowerInvariant(replacementText[i]) != char.ToLowerInvariant(matchText[i]))
                        {
                            ambiguous = true;
                            replacementText = replacementText.Substring(0, i);
                            break;
                        }
                    }
                    if (replacementText.Length == 0)
                    {
                        break;
                    }
                }
            }
            return replacementText;
        }
    }
}