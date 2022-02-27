#.ExternalHelp PSFzf.psm1-help.xml

$addedAliases = @()

function script:SetPsFzfAlias {
    param($Name,$Function)

    New-Alias -Name $Name -Scope Global -Value $Function -ErrorAction Ignore
    $addedAliases += $Name
}
function script:SetPsFzfAliasCheck {
    param($Name,$Function)

    # prevent Get-Command from loading PSFzf
    $script:PSModuleAutoLoadingPreferencePrev=$PSModuleAutoLoadingPreference
    $PSModuleAutoLoadingPreference='None'

    if (-not (Get-Command -Name $Name -ErrorAction Ignore)) {
        SetPsFzfAlias $Name $Function
    }

    # restore module auto loading
    $PSModuleAutoLoadingPreference=$script:PSModuleAutoLoadingPreferencePrev
}

function script:RemovePsFzfAliases {
    $addedAliases | ForEach-Object {
        Remove-Item -Path Alias:$_
    }
}
function Invoke-FuzzyEdit()
{
    param($Directory=$null)

    $files = @()
    try {
		if( Test-Path $Directory){
			if( (Get-Item $Directory).PsIsContainer ) {
				if ($Directory) {
					$prevDir = $PWD.ProviderPath
					cd $Directory
				}
				Invoke-Expression (Get-FileSystemCmd .) | Invoke-Fzf -Multi | ForEach-Object { $files += "$_" }
			}else {
				$files+=$Directory
				$Directory = Split-Path -Parent $Directory
			}
		}
    } catch {
    }
    finally {
        if ($prevDir) {
            cd $prevDir
        }
    }

    # HACK to check to see if we're running under Visual Studio Code.
    # If so, reuse Visual Studio Code currently open windows:
    $editorOptions = ''
    if ($null -ne $env:VSCODE_PID) {
        $editor = 'code'
        $editorOptions += '--reuse-window'
    } else {
        $editor = ($env:EDITOR && $env:VISUAL)
        if ($null -eq $editor) {
            if (!$IsWindows) {
                $editor = 'vim'
            } else {
                $editor = 'code'
            }
        }
    }

    if ($files.Count -gt 0) {
        try {
            if ($Directory) {
                $prevDir = $PWD.Path
                cd $Directory
            }
            # Not sure if being passed relative or absolute path
            $fileList = '"{0}"' -f ( (Resolve-Path $files) -join '" "' )
            Invoke-Expression -Command ("$editor $editorOptions $fileList")
        }
        catch {
        }
        finally {
            if ($prevDir) {
                cd $prevDir
            }
        }
    }
}


    #.ExternalHelp PSFzf.psm1-help.xml
function Invoke-FuzzyFasd() {
    $result = $null
    try {
        if (Get-Command Get-Frecents -ErrorAction Ignore) {
            Get-Frecents | ForEach-Object { $_.FullPath } | Invoke-Fzf -ReverseInput -NoSort | ForEach-Object { $result = $_ }
        } elseif (Get-Command fasd -ErrorAction Ignore) {
            fasd -l | Invoke-Fzf -ReverseInput -NoSort | ForEach-Object { $result = $_ }
        }
    } catch {

    }
    if ($null -ne $result) {
        # use cd in case it's aliased to something else:
        cd $result
    }
}


#.ExternalHelp PSFzf.psm1-help.xml
function Invoke-FuzzyHistory() {
    if (Get-Command Get-PSReadLineOption -ErrorAction SilentlyContinue) {
        $result = Get-Content (Get-PSReadLineOption).HistorySavePath | Invoke-Fzf -Reverse -NoSort
    } else {
        $result = Get-History | ForEach-Object { $_.CommandLine } | Invoke-Fzf -Reverse -NoSort
    }
    if ($null -ne $result) {
        Write-Output "Invoking '$result'`n"
        Invoke-Expression "$result" -Verbose
    }
}

#.ExternalHelp PSFzf.psm1-help.xml

function GetProcessSelection() {
    param(
        [scriptblock]
        $ResultAction
    )
    $header = "`n" + $("{0,-8} PROCESS NAME" -f "ID") + "`n"
    $result = Get-Process | Where-Object { ![string]::IsNullOrEmpty($_.ProcessName) } | ForEach-Object { "{0,-8} {1}" -f $_.Id,$_.ProcessName } | Invoke-Fzf -Multi -Header $header
    $result | ForEach-Object {
        &$ResultAction $_
    }
}
function Invoke-FuzzyKillProcess() {
    GetProcessSelection -ResultAction {
        param($result)
        $id = $result -replace "([0-9]+)(.*)",'$1'
        Stop-Process $id -Verbose
    }
}

#.ExternalHelp PSFzf.psm1-help.xml
function Invoke-FuzzySetLocation() {
    param($Directory=$null)

    if ($null -eq $Directory) { $Directory = $PWD.ProviderPath }
    $result = $null
    try {
        if ([string]::IsNullOrWhiteSpace($env:FZF_DEFAULT_COMMAND)) {
            Get-ChildItem $Directory -Recurse -ErrorAction Ignore | Where-Object{ $_.PSIsContainer } | Invoke-Fzf | ForEach-Object { $result = $_ }
        } else {
            Invoke-Fzf | ForEach-Object { $result = $_ }
        }
    } catch {

    }

    if ($null -ne $result) {
        Set-Location $result
    }
}

if ((-not $IsLinux) -and (-not $IsMacOS)) {
    #.ExternalHelp PSFzf.psm1-help.xml
    function Set-LocationFuzzyEverything() {
        param($Directory=$null)
        if ($null -eq $Directory) {
            $Directory = $PWD.ProviderPath
            $Global = $False
        } else {
            $Global = $True
        }
        $result = $null
        try {
            Search-Everything -Global:$Global -PathInclude $Directory -FolderInclude @('') | Invoke-Fzf | ForEach-Object { $result = $_ }
        } catch {

        }
        if ($null -ne $result) {
            # use cd in case it's aliased to something else:
            cd $result
        }
    }
}

#.ExternalHelp PSFzf.psm1-help.xml
function Invoke-FuzzyZLocation() {
    $result = $null
    try {
        (Get-ZLocation).GetEnumerator() | Sort-Object { $_.Value } -Descending | ForEach-Object{ $_.Key } | Invoke-Fzf -NoSort | ForEach-Object { $result = $_ }
    } catch {

    }
    if ($null -ne $result) {
        # use cd in case it's aliased to something else:
        cd $result
    }
}


#.ExternalHelp PSFzf.psm1-help.xml
function Invoke-FuzzyScoop() {
    param(
        [string]$subcommand      = "install",
        [string]$subcommandflags = ""
    )

    $result = $null
    $scoopexists = Get-Command scoop -ErrorAction Ignore
    if ($scoopexists) {
        $apps = New-Object System.Collections.ArrayList
        Get-ChildItem "$(Split-Path $scoopexists.Path)\..\buckets" | ForEach-Object {
          $bucket = $_.Name
          Get-ChildItem "$($_.FullName)\bucket" | ForEach-Object {
            $apps.Add($bucket + '/' + ($_.Name -replace '.json', '')) > $null
          }
        }

        $result = $apps | Invoke-Fzf -Header "Scoop Applications" -Multi -Preview "scoop info {}" -PreviewWindow wrap
    }

    if ($null -ne $result) {
        Invoke-Expression "scoop $subcommand $($result -join ' ') $subcommandflags"
    }
}


#.ExternalHelp PSFzf.psm1-help.xml
function Invoke-FuzzyGitStatus() {
    $result = @()
    try {
        $headerStrings = Get-HeaderStrings
        $gitRoot = git rev-parse --show-toplevel
        git status --porcelain |
        Invoke-Fzf -Multi -Bind $headerStrings[1] -Header $headerStrings[0] | ForEach-Object {
            $result += Join-Path $gitRoot $('{0}' -f $_.Substring('?? '.Length))
        }
    } catch {
        # do nothing
    }
    if ($null -ne $result) {
        $result
    }
}

function Enable-PsFzfAliases()
{
    # set aliases:
    if (-not $DisableAliases) {
        SetPsFzfAliasCheck "fe"      Invoke-FuzzyEdit
        SetPsFzfAliasCheck "fh"      Invoke-FuzzyHistory
        SetPsFzfAliasCheck "ff"      Invoke-FuzzyFasd
        SetPsFzfAliasCheck "fkill"   Invoke-FuzzyKillProcess
        SetPsFzfAliasCheck "fd"      Invoke-FuzzySetLocation
        if (${function:Set-LocationFuzzyEverything}) {
            SetPsFzfAliasCheck "cde" Set-LocationFuzzyEverything
        }
        SetPsFzfAliasCheck "fz"      Invoke-FuzzyZLocation
        SetPsFzfAliasCheck "fs"      Invoke-FuzzyScoop
        SetPsFzfAliasCheck "fgs"     Invoke-FuzzyGitStatus
    }
}
