---
external help file: PSFzf.psm1-help.xml
schema: 2.0.0
---

# Invoke-FuzzyEdit
## SYNOPSIS
Starts an editor for the selected files in the fuzzy finder.
## SYNTAX

```
Invoke-FuzzyEdit
```

## DESCRIPTION
Allows the user to pick multiple files from fzf that will be launched in the editor defined in the environment variable EDITOR.  Under Windows, Visual Studio Code is launched if EDITOR is not defined.  If not running under Windows, vim is launched.
If Invoke-FuzzyEdit is executed in the Visual Studio Code integrated terminal, the --reuse-window option is used which should cause the file to open in the currently active Visual Studio Code window. 
## EXAMPLES

### Launch Invoke-FuzzyEdit
	
Launches fzf and loads the selected files in the default editor.


```
Invoke-FuzzyEdit
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

## RELATED LINKS

