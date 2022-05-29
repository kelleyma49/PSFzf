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

function Get-EditorLaunch() {
    param($FileList,$LineNum=0)
    # HACK to check to see if we're running under Visual Studio Code.
    # If so, reuse Visual Studio Code currently open windows:
    $editorOptions = ''
	$editorOptions += $env:PSFZF_EDITOR_OPTIONS
    if ($null -ne $env:VSCODE_PID) {
        $editor = 'code'
        $editorOptions += ' --reuse-window'
    } else {
        $editor = if($ENV:VISUAL){$ENV:VISUAL}elseif($ENV:EDITOR){$ENV:EDITOR}
        if ($null -eq $editor) {
            if (!$IsWindows) {
                $editor = 'vim'
            } else {
                $editor = 'code'
            }
        }
    }

    if ($editor -eq 'code') {
        "$editor $editorOptions --goto {0}:{1}" -f $FileList, $LineNum
    } elseif ($editor -eq 'vim') {
        "$editor $editorOptions {0} +{1}" -f $fileList, $LineNum
    }
}
function Invoke-FuzzyEdit()
{
    param($Directory=".")

    $files = @()
    try {
		if( Test-Path $Directory){
			if( (Get-Item $Directory).PsIsContainer ) {
				$prevDir = $PWD.ProviderPath
				cd $Directory
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



    if ($files.Count -gt 0) {
        try {
            if ($Directory) {
                $prevDir = $PWD.Path
                cd $Directory
            }
            # Not sure if being passed relative or absolute path
            $fileList = '"{0}"' -f ( (Resolve-Path $files) -join '" "' )
            Invoke-Expression -Command (Get-EditorLaunch -FileList $fileList)
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


# needs to match helpers/GetProcessesList.ps1
function GetProcessesList()
{
    Get-Process | `
    Where-Object { ![string]::IsNullOrEmpty($_.ProcessName) } | `
    ForEach-Object {
        $pmSize = $_.PM/1MB
        $cpu = $_.CPU
        # make sure we display a value so we can correctly parse selections:
        if ($null -eq $cpu) {
            $cpu = 0.0
        }
        "{0,-8:n2} {1,-8:n2} {2,-8} {3}" -f $pmSize, $cpu,$_.Id,$_.ProcessName }
}

function GetProcessSelection() {
    param(
        [scriptblock]
        $ResultAction
    )

    $previewScript = $(Join-Path $PsScriptRoot 'helpers/GetProcessesList.ps1')
    $cmd =$($script:PowershellCmd + " -NoProfile -NonInteractive -File \""$previewScript\""")

    $header = "`n" + `
        "`nCTRL+R-Reload`tCTRL+A-Select All`tCTRL+D-Deselect All`tCTRL+T-Toggle All`n`n" + `
        $("{0,-8} {1,-8} {2,-8} PROCESS NAME" -f "PM(M)","CPU","ID") + "`n" + `
        "{0,-8} {1,-8} {2,-8} {3,-12}" -f "-----","---","--","------------"

    $result = GetProcessesList | `
        Invoke-Fzf -Multi -Header $header `
        -Bind """ctrl-r:reload($cmd),ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all""" `
        -Preview "echo {}" -PreviewWindow """down,3,wrap""" `
        -Layout reverse -Height 80%
    $result | ForEach-Object {
        &$ResultAction $_
    }
}

#.ExternalHelp PSFzf.psm1-help.xml
function Invoke-FuzzyKillProcess() {
    GetProcessSelection -ResultAction {
        param($result)
        $resultSplit=$result.split(' ',[System.StringSplitOptions]::RemoveEmptyEntries)
        $processIdIdx = 2
        $id = $resultSplit[$processIdIdx]
        Stop-Process -Id $id -Verbose
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
    Invoke-PsFzfGitFiles
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
