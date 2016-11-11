# PSFzf
[![Build status](https://ci.appveyor.com/api/projects/status/ikihhqqlp46tm42x?svg=true)](https://ci.appveyor.com/project/kelleyma49/psfzf)
[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/kelleyma49/HappyFinderWrapper/blob/master/LICENSE)

PSFzf is a PowerShell module that wraps [fzf](https://github.com/junegunn/fzf), a fuzzy file finder for the command line.

# Prerequisites
Follow the [installation instructions for fzf] (https://github.com/junegunn/fzf#installation) before installing PSFzf.

PSFzf has only been tested on PowerShell 5.0.

# Installation
PSFzf is available on the [PowerShell Gallery](https://www.powershellgallery.com/packages/PSFzf).  PSReadline should be imported before PSFzf as PSFzf registers <kbd>CTRL+T</kbd> as a PSReadline key handler.

# Usage
Press <kbd>CTRL+T</kbd> to start PSFzf.  PSFzf will parse the current token and use that as the starting path to search from.  If current token is empty, or the token isn't a valid path, PSFzf will search below the current working directory.  

Multiple items can be selected in PSFzf.  If more than one it is selected by the user, the results are returned as a comma separated list.  Results are properly quoted if they contain whitespace.

