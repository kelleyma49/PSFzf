---
external help file: PSFzf.psm1-help.xml
schema: 2.0.0
---

# Invoke-FuzzyZLocation
## SYNOPSIS
Starts fzf with input from the history saved by ZLocation and sets the current location.
## SYNTAX

```PowerShell
Invoke-FuzzyZLocation
```

## DESCRIPTION
Allows the user to select a file from ZLocation's history database and set the current location.
## EXAMPLES

### Launch Invoke-FuzzyZLocation
	
Launches fzf with input from ZLocation's history database and set the location based on user selection.


```PowerShell
Invoke-FuzzyZLocation
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
This function will be created if [ZLocation](https://github.com/vors/ZLocation) can be found by PowerShell.
## RELATED LINKS

