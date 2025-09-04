---
external help file: PSFzf.psm1-help.xml
schema: 2.0.0
---

# Invoke-FuzzyHistory
## SYNOPSIS
Rerun a previous command from history based on the user's selection in fzf.
## SYNTAX

```PowerShell
Invoke-FuzzyHistory
```

## DESCRIPTION
Executes a command selected by the user in fzf.
## EXAMPLES

### Launch Invoke-FuzzyHistory
	
Launches fzf and executes the command selected by the user.

```PowerShell
Invoke-FuzzyHistory
```

## PARAMETERS

### CommonParameters
This cmdlet does not support common parameters.
## INPUTS

### None 
This cmdlet does not accept any input.
## OUTPUTS

### None
This cmdlet does not generate any output.
## NOTES

For an enhanced history search experience, it is recommended to use `Set-PsFzfOption -PSReadlineChordReverseHistory` to enable PSFzf's PSReadline integration. This allows you to use keyboard shortcuts (like Ctrl+r) to launch the fuzzy history search directly from the command line.

## RELATED LINKS

