---
external help file: PsFzf.psm1-help.xml
online version: 
schema: 2.0.0
---

# Invoke-Fzf

## SYNOPSIS
Starts the fuzzy file finder based on input from the pipeline.
## SYNTAX

```PowerShell
Invoke-Fzf [-Extended] [-ExtendedExact] [-CaseInsensitive] [-CaseSensitive] [[-Delimiter] <String>] [-NoSort]
 [-ReverseInput] [[-Tiebreak] <String>] [-Multi] [-NoMouse] [-Cycle] [-NoHScroll] [-Reverse] [-InlineInfo]
 [[-Prompt] <String>] [[-Header] <String>] [[-HeaderLines] <Int32>] [[-History] <String>]
 [[-HistorySize] <Int32>] [[-Preview] <String>] [[-PreviewWindow] <String>] [[-Query] <String>] [-Select1]
 [-Exit0] [[-Filter] <String>] [[-Input] <Object[]>]
```

## DESCRIPTION
The Add-Frecent function adds a path to the Fasdr database for the passed in provider.

## EXAMPLES

### Example 1
```PowerShell
PS C:\> Set-Location (Invoke-Fzf)
```

Sets the current location based on the user selection in fzf. 

## PARAMETERS

### -CaseInsensitive
Case-insensitive match (default: smart-case match)

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: i

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CaseSensitive
Case-sensitive match

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

### -Cycle
Enable cyclic scroll

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

### -Delimiter
Field delimiter regex (default: AWK-style)

```yaml
Type: String
Parameter Sets: (All)
Aliases: d

Required: False
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Exit0
Exit immediately when there's no match

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: e0

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Extended
 Extended-search mode (enabled by default; +x or --no-extended to disable)

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: x

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Exact
Enable Exact-match

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: e

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Filter
Filter mode. Do not start interactive finder.

```yaml
Type: String
Parameter Sets: (All)
Aliases: f

Required: False
Position: 10
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Header
String to print as header

```yaml
Type: String
Parameter Sets: (All)
Aliases: 

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -HeaderLines
The first N lines of the input are treated as header

```yaml
Type: Int32
Parameter Sets: (All)
Aliases: 

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -History
History file

```yaml
Type: String
Parameter Sets: (All)
Aliases: 

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -HistorySize
Maximum number of history entries (default: 1000)

```yaml
Type: Int32
Parameter Sets: (All)
Aliases: 

Required: False
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -InlineInfo
Display finder info inline with the query

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

### -Input
The input to display in the interactive finder

```yaml
Type: Object[]
Parameter Sets: (All)
Aliases: 

Required: False
Position: 11
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Multi
Enable multi-select with tab/shift-tab

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: m

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -NoHScroll
Disable horizontal scroll

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

### -NoMouse
Disable mouse

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

### -NoSort
Do not sort the result

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

### -Preview
Command to preview highlighted line ({})

```yaml
Type: String
Parameter Sets: (All)
Aliases: 

Required: False
Position: 7
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PreviewWindow
Preview window layout (default: right:50%) [up|down|left|right][:SIZE[%]][:hidden]

```yaml
Type: String
Parameter Sets: (All)
Aliases: 

Required: False
Position: 8
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Prompt
Input prompt (default: '> ')

```yaml
Type: String
Parameter Sets: (All)
Aliases: 

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Query
Start the finder with the given query

```yaml
Type: String
Parameter Sets: (All)
Aliases: q

Required: False
Position: 9
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Reverse
Reverse orientation

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

### -ReverseInput
Reverse the order of the input

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: tac

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Select1
Automatically select the only match

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: s1

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Tiebreak
Comma-separated list of sort criteria to apply when the scores are tied [length|begin|end|index] (default: length)

```yaml
Type: String
Parameter Sets: (All)
Aliases: 
Accepted values: length, begin, end, index

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

## INPUTS

### System.Object[]

Objects to display in the interactive finder


## OUTPUTS

### System.Object[]

Objects selected by the user

## NOTES

## RELATED LINKS

