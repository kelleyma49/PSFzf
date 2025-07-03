---
external help file: PSFzf.psm1-help.xml
schema: 2.0.0
---

# Invoke-PsFzfRipgrep
## SYNOPSIS
Uses fzf as an interactive Ripgrep launcher 
## SYNTAX

```PowerShell
Invoke-PsFzfRipgrep -SearchString <string> [-NoEditor]
```

## DESCRIPTION
Uses Ripgrep and Fzf to interactively search files.
## EXAMPLES

### Launch Invoke-PsFzfRipgrep with search string

```PowerShell
Invoke-PsFzfRipgrep -SearchString 'Key' # Starts search with initial ripgrep query of the string 'Key'
```

## PARAMETERS
### -SearchString
Initial string to start ripgrep query

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```
### -NoEditor
Returns result instead of launching editor

```yaml
Type: Switch
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: False
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
This function is adapted from [Fzf's advanced document](https://github.com/junegunn/fzf/blob/master/ADVANCED.md#switching-between-ripgrep-mode-and-fzf-mode).
This function requires the installation of [ripgrep](https://github.com/BurntSushi/ripgrep) and [bat](https://github.com/sharkdp/bat).

You can customize the `rg` command used by `Invoke-PsFzfRipgrep` by setting the `PSFZF_RG_PREFIX` environment variable. This allows you to add default arguments to `rg`, such as enabling hidden file search or excluding specific directories.

For example, to make `rg` search hidden files and exclude the `node_modules` directory, you can set the environment variable as follows:

```powershell
$env:PSFZF_RG_PREFIX = "rg --hidden --glob '!node_modules'"
```
The default `rg` command is `"rg --column --line-number --no-heading --color=always --smart-case "`.

## RELATED LINKS

