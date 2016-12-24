---
external help file: PSFzf.psm1-help.xml
schema: 2.0.0
---

# Invoke-FuzzyGitStatus
## SYNOPSIS
Starts fzf with input from output of the `git status` function.
## SYNTAX

```
Invoke-FuzzyGitStatus
```

## DESCRIPTION
Allows the user to select files listed from the output of the `git status` function executed in the current directory.

These keyboard shortcuts are supported:

- <kbd>CTRL+A</kbd> selects all items
- <kbd>CTRL+D</kbd> deselects all items 
- <kbd>CTRL+T</kbd> toggles the selection state of all items 
 
## EXAMPLES

### Launch Invoke-FuzzyGitStatus
	
Launches fzf with input from a `git status` command executed in the current directory.


```
Invoke-FuzzyGitStatus
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
