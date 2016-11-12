---
external help file: PSFzf.psm1-help.xml
schema: 2.0.0
---

# Invoke-Fzf
## SYNOPSIS
Starts the fuzzy file finder based on input from the pipeline.
## SYNTAX

```
Invoke-Fzf [-Extended] [-ExtendedExact] [-CaseInsensitive] [-CaseSensitive] [-Delimiter <string>] [-NoSort] [-ReverseInput] [-Tiebreak] 
```

## DESCRIPTION
The Add-Frecent function adds a path to the Fasdr database for the passed in provider.
## EXAMPLES

### Add Directory
	
Adds a directory to the database.



```
Add-Frecent c:\Windows\
```

## PARAMETERS

### -FullName
The full name of the path to add from the database.

```yaml
Type: String
Parameter Sets: (All)
Aliases: 

Required: True
Position: 0
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -ProviderName
The name of the provider that that hosts the path.

```yaml
Type: String
Parameter Sets: (All)
Aliases: 

Required: False
Position: 1
Default value: the name of the current working container provider
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet does not support common parameters.
## INPUTS

### System.String
You can pipe a string that contains a path to Add-Frecent.
## OUTPUTS

### None
This cmdlet does not generate any output.
## NOTES

## RELATED LINKS

