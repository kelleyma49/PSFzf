---
external help file: PSFzf.psm1-help.xml
schema: 2.0.0
---

# Set-PsFzfOption
## SYNOPSIS
Sets the available PSFzf options.
## SYNTAX

```PowerShell
Set-PsFzfOption
```

## DESCRIPTION
Allows the user to set various PSFzf options, such as PSReadline chords and tab expansion.
## EXAMPLES

### Set PSReadline Options
	
Set PsFzf's history and file finder keyboard shortcuts.


```PowerShell
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
### -GitKeyBindings
Enables key bindings for git commands.

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

### -EnableAliasFuzzyEdit
Enables the `fe` aliases for the `Invoke-FuzzyEdit` function 

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

### -EnableAliasFuzzyFasd
Enables the `ff` aliases for the `Invoke-FuzzyFasd` function 
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

### -EnableAliasFuzzyHistory
Enables the `fh` aliases for the `Invoke-FuzzyHistory` function 
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

### -EnableAliasFuzzyKillProcess
Enables the `fkill` aliases for the `Invoke-FuzzyKillProcess` function 
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

### -EnableAliasFuzzySetLocation
Enables the `fd` aliases for the `Invoke-FuzzySetLocation` function 
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

### -EnableAliasFuzzySetEverything
Enables the `cde` aliases for the `Set-LocationFuzzyEverything` function 
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

### -EnableAliasFuzzyScoop
Enables the `fs` aliases for the `Invoke-FuzzyScoop` function 
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

### -EnableAliasFuzzyZLocation
Enables the `fz` aliases for the `Invoke-FuzzySetZLocation` function 
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

### -EnableAliasFuzzyGitStatus
Enables the `fgs` aliases for the `Invoke-FuzzyGitStatus` function 
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

### -EnableFd
uses the `fd` command instead of the OS specific file and directory commands
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

### -AltCCommand
Specifies a user supplied command that will be used in the command that is bound to the Alt-C command

```powershell
# example command - use $Location with a different command:
$commandOverride = [ScriptBlock]{ param($Location) Write-Host $Location } 
# pass your override to PSFzf:
Set-PsFzfOption -AltCCommand $commandOverride
```
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

### -PsReadlineHandlerProviderDelimiter
Specifies the delimiter character used to join multiple selected files when using the PSReadlineChordProvider (Ctrl+t by default). 

```powershell
# example - use space as delimiter instead of comma:
Set-PsFzfOption -PsReadlineHandlerProviderDelimiter ' '

# example - use semicolon as delimiter:
Set-PsFzfOption -PsReadlineHandlerProviderDelimiter ';'
```
```yaml
Type: String
Parameter Sets: (All)
Aliases: 

Required: False
Position: Named
Default value: ','
Accept pipeline input: False
Accept wildcard characters: False
```

### -TabCompletionPreviewWindow
Specifies the preview window behavior for tab completion. The format is 'initial_state|change_preview_window_options' where the first part sets the initial state of the preview window (e.g., 'hidden' or 'visible'), and the rest is passed to the change-preview-window command (typically bound to Ctrl+/).

```powershell
# example - start with hidden preview, toggle between up, left, and hidden:
Set-PsFzfOption -TabCompletionPreviewWindow 'hidden|up|left|hidden'

# example - start with visible preview on the right:
Set-PsFzfOption -TabCompletionPreviewWindow 'right|up|down|hidden'

# default - start hidden, toggle between down, right, and right:hidden:
Set-PsFzfOption -TabCompletionPreviewWindow 'hidden|down|right|right:hidden'
```
```yaml
Type: String
Parameter Sets: (All)
Aliases: 

Required: False
Position: Named
Default value: 'hidden|down|right|right:hidden'
Accept pipeline input: False
Accept wildcard characters: False
```
## INPUTS
### None

## OUTPUTS

### None
This cmdlet does not generate any output.
