---
external help file: PSFzf.psm1-help.xml
schema: 2.0.0
---

# Invoke-FuzzySetLocation
## SYNOPSIS
Sets the current location from the user's selection in fzf.
## SYNTAX

```
Invoke-FuzzySetLocation [-Directory <string>]
```

## DESCRIPTION
Set the current location of a subdirectory based on the user's selection in fzf.  
## EXAMPLES

### Set-Location to a subdirectory located in the Windows directory
	
Launches fzf and allows the user to select a subdirectory from the Windows directory.

```
Invoke-FuzzySetLocation c:\Windows
```

## PARAMETERS
## -Directory
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

## RELATED LINKS

