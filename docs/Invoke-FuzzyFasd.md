---
external help file: PSFzf.psm1-help.xml
schema: 2.0.0
---

# Invoke-FuzzyFasd
## SYNOPSIS
Starts fzf with input from the files saved in fasd (non-Windows) or fasdr (Windows) and sets the current location.
## SYNTAX

```PowerShell
Invoke-FuzzyFasd
```

## DESCRIPTION
Allows the user to select a file from fasd's database and set the current location.
## EXAMPLES

### Launch Invoke-FuzzyFasd
	
Launches fzf with input from fasd's database and set the location based on user selection.


```PowerShell
Invoke-FuzzyFasd
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
This function will be created if [fasdr](https://github.com/kelleyma49/fasdr) can be found by PowerShell.
## RELATED LINKS

