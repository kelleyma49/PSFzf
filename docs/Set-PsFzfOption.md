---
external help file: PSFzf.psm1-help.xml
schema: 2.0.0
---

# Set-PsFzfOption
## SYNOPSIS
Sets the available PSFzf options.
## SYNTAX

```
Set-PsFzfOption
```

## DESCRIPTION
Allows the user to set various PSFzf options, such as PSReadline chords and tab expansion.
## EXAMPLES

### Set PSReadline Options
	
Set PsFzf's history and file finder keyboard shortcuts.


```
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
```

## PARAMETERS

### CommonParameters
This cmdlet does not support common parameters.

### -PSReadlineChordProvider
PSReadline keyboard chord shortcut to trigger file and directory selection

```yaml
Type: String
Parameter Sets: (All)
Aliases: 

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```
### -PSReadlineChordReverseHistory
PSReadline keyboard chord shortcut to trigger history selection

```yaml
Type: String
Parameter Sets: (All)
Aliases: 

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```
### -TabExpansion
Enables tab expansion support

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: 

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

## INPUTS
### None

## OUTPUTS

### None
This cmdlet does not generate any output.
