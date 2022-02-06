# PSFzf
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/PSFzf.svg)](https://www.powershellgallery.com/packages/PSFzf)
[![Build status](https://github.com/kelleyma49/PSFzf/workflows/CI/badge.svg)](https://github.com/kelleyma49/PSFzf/actions)
[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/kelleyma49/PSFzf/blob/master/LICENSE)


PSFzf is a PowerShell module that wraps [fzf](https://github.com/junegunn/fzf), a fuzzy file finder for the command line.

![](https://raw.github.com/kelleyma49/PSFzf/master/docs/PSFzfExample.gif)

# Usage
To change to a user selected directory:

```powershell
Get-ChildItem . -Recurse -Attributes Directory | Invoke-Fzf | Set-Location
```

To edit a file:

```powershell
Get-ChildItem . -Recurse -Attributes !Directory | Invoke-Fzf | % { notepad $_ }
```

For day-to-day usage, see the [helper functions included with this module](https://github.com/kelleyma49/PSFzf#helper-functions).

## PSReadline Integration
### Select Current Provider Path (default chord: <kbd>Ctrl+t</kbd>) 
Press <kbd>Ctrl+t</kbd> to start PSFzf to select provider paths.  PSFzf will parse the current token and use that as the starting path to search from.  If current token is empty, or the token isn't a valid path, PSFzf will search below the current working directory.  

Multiple items can be selected.  If more than one is selected by the user, the results are returned as a comma separated list.  Results are properly quoted if they contain whitespace.

### Reverse Search Through PSReadline History (default chord: <kbd>Ctrl+r</kbd>)

Press <kbd>Ctrl+r</kbd> to start PSFzf to select a command in the command history saved by PSReadline.  PSFzf will insert the command into the current line, but it will not execute the command.

PSFzf does not override <kbd>Ctrl+r</kbd> by default.  To confirm that you want to override PSReadline's chord binding, use the [`Set-PsFzfOption`](docs/Set-PsFzfOption.md) command:

```powershell
# replace 'Ctrl+t' and 'Ctrl+r' with your preferred bindings:
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
```

### Set-Location Based on Selected Directory (default chord: <kbd>Alt+c</kbd>)

Press <kbd>Alt+c</kbd> to start PSFzf to select a directory.  By default, `Set-Location` will be called with the selected directory. You can override the default command with the following code in our `$PROFILE`:

```powershell
# example command - use $Location with a different command:
$commandOverride = [ScriptBlock]{ param($Location) Write-Host $Location } 
# pass your override to PSFzf:
Set-PsFzfOption -AltCCommand $commandOverride
```

### Search Through Command Line Arguments in PSReadline History (default chord: <kbd>Alt+a</kbd>)

Press <kbd>Alt+a</kbd> to start PSFzf to select command line arguments used in PSReadline history.  The picked argument will be inserted in the current line.  The line that would result from the selection is shown in the preview window.

## Tab Expansion
PSFzf can replace the standard tab completion: 
```powershell
Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
```
To activate continuous completion, press the directory separator character to complete the current selection and start tab completion for the next part of the container path.

PSFzf supports specialized tab expansion with a small set of commands. After typing the default trigger command, which defaults to "`**`", and press <kbd>Tab</kbd>, PsFzf tab expansion will provide selectable list of options.

The following commands are supported:

| Command | Notes |
|---------|-------|
| `git`   | Uses [`posh-git`](https://github.com/dahlbyk/posh-git) for providing tab completion options. Requires at least version 1.0.0 Beta 4.
| `Get-Service`, `Start-Service`, `Stop-Service` | Allows the user to select between the installed services.
| `Get-Process`, `Start-Process` | Allows the user to select between running processes.

To override the trigger command, set `FZF_COMPLETION_TRIGGER` to your preferred trigger sequence.

Use the following command to enable tab expansion:
```powershell
Set-PsFzfOption -TabExpansion
```

## Using within a Pipeline
`Invoke-Fzf` works with input from a pipeline. You can use it in the middle of a pipeline, or as part of an expression.

```powershell
Set-Location (Get-ChildItem . -Recurse | ? { $_.PSIsContainer } | Invoke-Fzf) # This works as of version 2.2.8
Get-ChildItem . -Recurse | ? { $_.PSIsContainer } | Invoke-Fzf | Set-Location
```

## Overriding Behavior
PsFzf supports overriding behavior by setting these fzf environment variables:
* `_PSFZF_FZF_DEFAULT_OPTS` - If this environment variable is set, then `FZF_DEFAULT_OPTS` is temporarily set with the contents. This allows the user to have different default options for PSFZF and fzf.
* `FZF_DEFAULT_COMMAND` - The command specified in this environment variable will override the default command when PSFZF detects that the current location is a file system provider.
* `FZF_CTRL_T_COMMAND` - The command specified in this environment variable will be used when <kbd>Ctrl+t</kbd> is pressed by the user.
* `FZF_ALT_C_COMMAND` - The command specified in this environment variable will be used when <kbd>Alt+c</kbd> is pressed by the user.

# Helper Functions
In addition to its core function [Invoke-Fzf](docs/Invoke-Fzf.md), PSFzf includes a set of useful functions and aliases. The aliases are not installed by default. To enable aliases, use [`Set-PSFzfOption`](docs/Set-PsFzfOption.md)'s  `-EnableAlias`* options.


| Function                                                             | Alias      | Description
| ---------------------------------------------------------------------| ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`Invoke-FuzzyEdit`](docs/Invoke-FuzzyEdit.md)                       | `fe`       | Starts an editor for the selected files in the fuzzy finder.
| [`Invoke-FuzzyFasd`](docs/Invoke-FuzzyFasd.md)                       | `ff`       | Starts fzf with input from the files saved in [fasd ](https://github.com/clvv/fasd)(non-Windows) or [fasdr](https://github.com/kelleyma49/fasdr) (Windows) and sets the current location.
| [`Invoke-FuzzyZLocation`](docs/Invoke-FuzzyZLocation.md)             | `fz`       | Starts fzf with input from the history of [ZLocation](https://github.com/vors/ZLocation) and sets the current location.
| [`Invoke-FuzzyGitStatus`](docs/Invoke-FuzzyGitStatus.md)             | `fgs`      |  Starts fzf with input from output of the `git status` function.
| [`Invoke-FuzzyHistory`](docs/Invoke-FuzzyHistory.md)                 | `fh`       | Rerun a previous command from history based on the user's selection in fzf.
| [`Invoke-FuzzyKillProcess`](docs/Invoke-FuzzyKillProcess.md)         | `fkill`    | Runs `Stop-Process` on processes selected by the user in fzf.
| [`Invoke-FuzzySetLocation`](docs/Invoke-FuzzySetLocation.md)         | `fd`       | Sets the current location from the user's selection in fzf.
| [`Set-LocationFuzzyEverything`](docs/Set-LocationFuzzyEverything.md) | `cde`      | Sets the current location based on the [Everything](https://www.voidtools.com/) database.

# Prerequisites
Follow the [installation instructions for fzf](https://github.com/junegunn/fzf#installation) before installing PSFzf.   PSFzf will run `Get-Command` to find `fzf` in your path.  

## Windows
The latest version of `fzf` is available via [Chocolatey](https://chocolatey.org/packages/fzf), or you can download the `fzf` binary and place it in your path.  Run `Get-Command fzf*.exe` to verify that PowerShell can find the executable.

PSFzf has been tested under PowerShell 5.0, 6.0, and 7.0.

## MacOS
Use Homebrew or download the binary and place it in your path.  Run `Get-Command fzf*` to verify that PowerShell can find the executable.

PSFzf has been tested under PowerShell 6.0 and 7.0.

## Linux
PSFzf has been tested under PowerShell 6.0 and 7.0 in the Windows Subsystem for Linux.

# Installation
PSFzf is available on the [PowerShell Gallery](https://www.powershellgallery.com/packages/PSFzf).  PSReadline should be imported before PSFzf as PSFzf registers PSReadline key handlers listed in the [PSReadline integration section](https://github.com/kelleyma49/PSFzf#psreadline-integration).

## Helper Function Requirements
* [`Invoke-FuzzyFasd`](docs/Invoke-FuzzyFasd.md) requires [Fasdr](https://github.com/kelleyma49/fasdr) to be previously installed under Windows.  Other platforms require [Fasd](https://github.com/clvv/fasd) to be installed.
* [`Invoke-FuzzyZLocation`](docs/Invoke-FuzzyZLocation.md) requires [ZLocation](https://github.com/vors/ZLocation) and works only under Windows.
* [`Set-LocationFuzzyEverything`](docs/Set-LocationFuzzyEverything.md) works only under Windows and requires [PSEverything](https://www.powershellgallery.com/packages/PSEverything) to be previously installed.
* [`Invoke-FuzzyGitStatus`](docs/Invoke-FuzzyGitStatus.md) requires [git](https://git-scm.com/) to be installed.
