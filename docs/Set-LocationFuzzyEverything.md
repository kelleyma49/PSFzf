---
external help file: PSFzf.psm1-help.xml
schema: 2.0.0
---

# Set-LocationFuzzyEverything
## SYNOPSIS
Sets the current location based on the Everything database.
## SYNTAX

```PowerShell
Set-LocationFuzzyEverything [-Directory <string>]
```

## DESCRIPTION
Allows the user to select a directory from the Everything database and sets the current location.
## EXAMPLES

### Launch Set-LocationFuzzyEverything
	
Launches fzf and sets the current location based on the user selection.


```PowerShell
Set-LocationFuzzyEverything
```

### Launch Set-LocationFuzzyEverything specifying a path filter
  
Launches fzf for all subdirectories of c:\Windows and sets the current location based on the user selection.


```PowerShell
Set-LocationFuzzyEverything c:\Windows
```

## PARAMETERS
### -Directory
The path to a directory that contains the subdirectories that the user will choose from.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet does not support common parameters.
## INPUTS

### None 
This cmdlet does not accept any input.
## OUTPUTS

### None
This cmdlet does not generate any output.
## NOTES
This function will be created if [PSEverything](https://github.com/powercode/PSEverything) can be found by PowerShell.
## RELATED LINKS

