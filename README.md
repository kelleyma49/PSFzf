# PSFzf
[![Build status](https://ci.appveyor.com/api/projects/status/ikihhqqlp46tm42x?svg=true)](https://ci.appveyor.com/project/kelleyma49/psfzf)
[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/kelleyma49/PSFzf/blob/master/LICENSE)

PSFzf is a PowerShell module that wraps [fzf](https://github.com/junegunn/fzf), a fuzzy file finder for the command line.

![](https://raw.github.com/kelleyma49/PSFzf/master/docs/PSFzfExample.gif)

# Usage
To change to a user selected directory:

```powershell
Get-ChildItem . -Recurse | where { $_.PSIsContainer } | Invoke-Fzf | Set-Location
```

To edit a file:

```powershell
Get-ChildItem . -Recurse | where { -not $_.PSIsContainer } | Invoke-Fzf | % { notepad $_ }
```

For day-to-day usage, see the [helper functions included with this module](https://github.com/kelleyma49/PSFzf#helper-functions).

## PSReadline Integration
Press <kbd>CTRL+T</kbd> to start PSFzf.  PSFzf will parse the current token and use that as the starting path to search from.  If current token is empty, or the token isn't a valid path, PSFzf will search below the current working directory.  

Multiple items can be selected in PSFzf.  If more than one it is selected by the user, the results are returned as a comma separated list.  Results are properly quoted if they contain whitespace.

## Using within a Pipeline
`Invoke-Fzf` works with input from a pipeline.  However, if you make your selection before fzf has finished receiving and parsing from standard in, you might see a ```Stopped pipeline input``` error.  This is because PSFzf must throw an exception to cancel pipeline processing.  If you pipe the output of `Invoke-Fzf` to whatever action you wish to do based on your selection, the action will occur.  The following will not work if the pipeline is cancelled:

```powershell
Set-Location (Get-ChildItem . -Recurse | where { $_.PSIsContainer } | Invoke-Fzf)
```

The following will work if the pipeline is cancelled:

```powershell
Get-ChildItem . -Recurse | where { $_.PSIsContainer } | Invoke-Fzf | Set-Location
```

# Helper Functions
In addition to its core function [Invoke-Fzf](docs/Invoke-Fzf.md), PSFzf includes a set of useful functions and aliases:


| Function                                                             | Alias      |
| ---------------------------------------------------------------------| ---------- |
| [`Invoke-FuzzyEdit`](docs/Invoke-FuzzyEdit.md)                       | `fe`       |
| [`Invoke-FuzzyFasd`](docs/Invoke-FuzzyFasd.md)                       | `ff`       | 
| [`Invoke-FuzzyHistory`](docs/Invoke-FuzzyHistory.md)                 | `fh`       |
| [`Invoke-FuzzyKillProcess`](docs/Invoke-FuzzyKillProcess.md)         | `fkill`    |
| [`Invoke-FuzzySetLocation`](docs/Invoke-FuzzySetLocation.md)         | `fd`       |
| [`Set-LocationFuzzyEverything`](docs/Set-LocationFuzzyEverything.md) | `cde`      |

# Prerequisites
Follow the [installation instructions for fzf] (https://github.com/junegunn/fzf#installation) before installing PSFzf.  PSFzf will run `Get-Command` to find `fzf` in your path.  

## Windows
Download the `fzf` binary and place it in your path.  Run `Get-Command fzf*-Windows-*.exe` to verify that PowerShell can find the executable.

PSFzf has only been tested on PowerShell 5.0.

## MacOS
Use Homebrew or download the binary and place it in your path.  Run `Get-Command fzf*` to verify that PowerShell can find the executable.

PSFzf has been tested with the latest PowerShell 6.0 alpha.

## Linux
PSFzf has not been tested under Linux.

# Installation
PSFzf is available on the [PowerShell Gallery](https://www.powershellgallery.com/packages/PSFzf).  PSReadline should be imported before PSFzf as PSFzf registers <kbd>CTRL+T</kbd> as a PSReadline key handler.

[`Invoke-FuzzyFasd`](docs/Invoke-FuzzyFasd.md) requires [Fasdr] (https://github.com/kelleyma49/fasdr) to be previously installed.

[`Set-LocationFuzzyEverything`](docs/Set-LocationFuzzyEverything.md) works only under Windows and requires [PSEverything](https://www.powershellgallery.com/packages/PSEverything) to be previously installed.
