---
external help file: PSFzf.psm1-help.xml
schema: 2.0.0
---

# Invoke-FuzzyZLocation
## SYNOPSIS
Starts fzf with input from the history saved by ZLocation and sets the current location.
## SYNTAX

```PowerShell
Invoke-FuzzyZLocation [[-Query] <string>]
```

## DESCRIPTION
Allows the user to select a file from ZLocation's history database and set the current location.
An optional query can be passed to fzf.
## EXAMPLES

### Launch Invoke-FuzzyZLocation

Launches fzf with input from ZLocation's history database and set the location based on user selection.


```PowerShell
Invoke-FuzzyZLocation
```

### Launch Invoke-FuzzyZLocation with an initial query

Launches fzf with input from ZLocation's history database, with "project" as the initial query, and set the location based on user selection.


```PowerShell
Invoke-FuzzyZLocation -Query "project"
```

## PARAMETERS

### -Query
Specifies an initial query for fzf.

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
This function will be created if [ZLocation](https://github.com/vors/ZLocation) can be found by PowerShell.
## RELATED LINKS
