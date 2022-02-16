---
external help file: PSFzf.psm1-help.xml
schema: 2.0.0
---

# Invoke-FuzzyScoop
## SYNOPSIS
Starts fzf on Scoop applications list.
## SYNTAX

```
Invoke-FuzzyScoop [-subcommand <string>] [-subcommandflags <string>]
```

## DESCRIPTION
Allows the user to select (multiple) applications from locally stored Scoop buckets and runs `subcommand` on them. Default value of `subcommand` is `install`.
## EXAMPLES

### Launch Invoke-FuzzyScoop

Launches fzf and selects some applications to install.

```
Invoke-FuzzyScoop
```

### Launch Invoke-FuzzyScoop using `uninstall` subcommand

Launches fzf for selects some applications to uninstall.


```
Invoke-FuzzyScoop -subcommand uninstall
```

## PARAMETERS
### -subcommand
The Scoop command that will be run on the selected applications.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 0
Default value: install
Accept pipeline input: False
Accept wildcard characters: False
```

### -subcommandflags
A set of flags that will be additionally passed to the Scoop subcommand.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 0
Default value:
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
This function will be effective if [Scoop](https://scoop.sh) can be found in PATH.

