# PSFzf
[![Build status](https://ci.appveyor.com/api/projects/status/ikihhqqlp46tm42x?svg=true)](https://ci.appveyor.com/project/kelleyma49/psfzf)
[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/kelleyma49/PSFzf/blob/master/LICENSE)

PSFzf is a PowerShell module that wraps [fzf](https://github.com/junegunn/fzf), a fuzzy file finder for the command line.

![](https://raw.github.com/kelleyma49/PSFzf/master/docs/PSFzfExample.gif)

# Usage
To change to a user selected directory:

```powershell
Get-ChildItem . -Recurse | ? { $_.PSIsContainer } | Invoke-Fzf | Set-Location
```

To edit a file:

```powershell
Get-ChildItem . -Recurse | ? { -not $_.PSIsContainer } | Invoke-Fzf | % { notepad $_ }
```

For day-to-day usage, see the [helper functions included with this module](https://github.com/kelleyma49/PSFzf#helper-functions).

## PSReadline Integration
### Select Current Provider Path (default chord: <kbd>CTRL+T</kbd>) 
Press <kbd>CTRL+T</kbd> to start PSFzf to select provider paths.  PSFzf will parse the current token and use that as the starting path to search from.  If current token is empty, or the token isn't a valid path, PSFzf will search below the current working directory.  

Multiple items can be selected.  If more than one it is selected by the user, the results are returned as a comma separated list.  Results are properly quoted if they contain whitespace.

### Reverse Search Through PSReadline History (default chord: <kbd>CTRL+R</kbd>)

Press <kbd>CTRL+R</kbd> to start PSFzf to select a command in the command history saved by PSReadline.  PSFzf will insert the command into the current line, but it will not execute the command.

PSFzf does not override <kbd>CTRL+R</kbd> by default.  To confirm that you want to override PSReadline's chord binding, you have two options.

The first option is to remove the handler from PSReadline.  For example:

```powershell
Remove-PSReadlineKeyHandler 'CTRL+R'
Import-Module PSFzf
```

The other option is to pass in the chord when you import the module.  For example:

```powershell
Import-Module PSFzf -ArgumentList 'Ctrl+T','Ctrl+R' # or replace these strings with your preferred bindings
``` 
### Set-Location Based on Selected Directory (default chord: <kbd>ALT+C</kbd>)

Press <kbd>ALT+C</kbd> to start PSFzf to select a directory.  `Set-Location` will be called with the selected directory.

### Search Through Command Line Arguments in PSReadline History (default chord: <kbd>ALT+A</kbd>)

Press <kbd>ALT+A</kbd> to start PSFzf to select command line arguments used in PSReadline history.  The picked argument will be inserted in the current line.  The line that would result from the selection is shown in the preview window.

## Using within a Pipeline
`Invoke-Fzf` works with input from a pipeline.  However, if you make your selection before fzf has finished receiving and parsing from standard in, you might see a ```Stopped pipeline input``` error.  This is because PSFzf must throw an exception to cancel pipeline processing.  If you pipe the output of `Invoke-Fzf` to whatever action you wish to do based on your selection, the action will occur.  The following *will not work* if the pipeline is cancelled:

```powershell
Set-Location (Get-ChildItem . -Recurse | ? { $_.PSIsContainer } | Invoke-Fzf)
```

The following *will work* if the pipeline is cancelled:

```powershell
Get-ChildItem . -Recurse | ? { $_.PSIsContainer } | Invoke-Fzf | Set-Location
```

# Helper Functions
In addition to its core function [Invoke-Fzf](docs/Invoke-Fzf.md), PSFzf includes a set of useful functions and aliases:


| Function                                                             | Alias      | Description
| ---------------------------------------------------------------------| ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`Invoke-FuzzyEdit`](docs/Invoke-FuzzyEdit.md)                       | `fe`       | Starts an editor for the selected files in the fuzzy finder.
| [`Invoke-FuzzyFasd`](docs/Invoke-FuzzyFasd.md)                       | `ff`       | Starts fzf with input from the files saved in [fasd ](https://github.com/clvv/fasd)(non-Windows) or [fasdr](https://github.com/kelleyma49/fasdr) (Windows) and sets the current location.
| [`Invoke-FuzzyGitStatus`](docs/Invoke-FuzzyGitStatus.md)             | `fgs`      |  Starts fzf with input from output of the `git status` function.
| [`Invoke-FuzzyHistory`](docs/Invoke-FuzzyHistory.md)                 | `fh`       | Rerun a previous command from history based on the user's selection in fzf.
| [`Invoke-FuzzyKillProcess`](docs/Invoke-FuzzyKillProcess.md)         | `fkill`    | Runs `Stop-Process` on processes selected by the user in fzf.
| [`Invoke-FuzzySetLocation`](docs/Invoke-FuzzySetLocation.md)         | `fd`       | Sets the current location from the user's selection in fzf.
| [`Set-LocationFuzzyEverything`](docs/Set-LocationFuzzyEverything.md) | `cde`      | Sets the current location based on the [Everything](https://www.voidtools.com/) database.

# Prerequisites
Follow the [installation instructions for fzf] (https://github.com/junegunn/fzf#installation) before installing PSFzf.  PSFzf will run `Get-Command` to find `fzf` in your path.  

## Windows
Download the `fzf` binary and place it in your path.  Run `Get-Command fzf*.exe` to verify that PowerShell can find the executable.

PSFzf has only been tested on PowerShell 5.0.

## MacOS
Use Homebrew or download the binary and place it in your path.  Run `Get-Command fzf*` to verify that PowerShell can find the executable.

PSFzf has been tested with the latest PowerShell 6.0 alpha.

## Linux
PSFzf has been tested under WSL with the latest PowerShell 6.0 alpha.

# Installation
PSFzf is available on the [PowerShell Gallery](https://www.powershellgallery.com/packages/PSFzf).  PSReadline should be imported before PSFzf as PSFzf registers PSReadline key handlers listed in the [PSReadline integration section](https://github.com/kelleyma49/PSFzf#psreadline-integration).

## Helper Function Requirements
* [`Invoke-FuzzyFasd`](docs/Invoke-FuzzyFasd.md) requires [Fasdr] (https://github.com/kelleyma49/fasdr) to be previously installed under Windows.  Other platforms require [Fasd](https://github.com/clvv/fasd) to be installed.
* [`Set-LocationFuzzyEverything`](docs/Set-LocationFuzzyEverything.md) works only under Windows and requires [PSEverything](https://www.powershellgallery.com/packages/PSEverything) to be previously installed.
* [`Invoke-FuzzyGitStatus`](docs/Invoke-FuzzyGitStatus.md) requires [git](https://git-scm.com/) to be installed.
