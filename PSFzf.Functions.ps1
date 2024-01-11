#.ExternalHelp PSFzf.psm1-help.xml

$addedAliases = @()

function script:SetPsFzfAlias {
    param($Name, $Function)

    New-Alias -Name $Name -Scope Global -Value $Function -ErrorAction Ignore
    $addedAliases += $Name
}
function script:SetPsFzfAliasCheck {
    param($Name, $Function)

    # prevent Get-Command from loading PSFzf
    $script:PSModuleAutoLoadingPreferencePrev = $PSModuleAutoLoadingPreference
    $PSModuleAutoLoadingPreference = 'None'

    if (-not (Get-Command -Name $Name -ErrorAction Ignore)) {
        SetPsFzfAlias $Name $Function
    }

    # restore module auto loading
    $PSModuleAutoLoadingPreference = $script:PSModuleAutoLoadingPreferencePrev
}

function script:RemovePsFzfAliases {
    $addedAliases | ForEach-Object {
        Remove-Item -Path Alias:$_
    }
}

function Get-EditorLaunch() {
    param($FileList, $LineNum = 0)
    # HACK to check to see if we're running under Visual Studio Code.
    # If so, reuse Visual Studio Code currently open windows:
    $editorOptions = ''
    if (-not [string]::IsNullOrEmpty($env:PSFZF_EDITOR_OPTIONS)) {
        $editorOptions += ' ' + $env:PSFZF_EDITOR_OPTIONS
    }
    if ($null -ne $env:VSCODE_PID) {
        $editor = 'code'
        $editorOptions += ' --reuse-window'
    }
    else {
        $editor = if ($ENV:VISUAL) { $ENV:VISUAL }elseif ($ENV:EDITOR) { $ENV:EDITOR }
        if ($null -eq $editor) {
            if (!$IsWindows) {
                $editor = 'vim'
            }
            else {
                $editor = 'code'
            }
        }
    }

    if ($editor -eq 'code') {
        if ($FileList -is [array] -and $FileList.length -gt 1) {
            for ($i = 0; $i -lt $FileList.Count; $i++) {
                $FileList[$i] = '"{0}"' -f $((Resolve-Path $FileList[$i].Trim('"')).ProviderPath)
            }
            "$editor$editorOptions {0}" -f ($FileList -join ' ')
        }
        else {
            "$editor$editorOptions --goto ""{0}:{1}""" -f $((Resolve-Path $FileList.Trim('"')).ProviderPath), $LineNum
        }
    }
    elseif ($editor -match '[gn]?vi[m]?') {
        if ($FileList -is [array] -and $FileList.length -gt 1) {
            for ($i = 0; $i -lt $FileList.Count; $i++) {
                $FileList[$i] = '"{0}"' -f $((Resolve-Path $FileList[$i].Trim('"')).ProviderPath)
            }
            "$editor$editorOptions {0}" -f ($FileList -join ' ')
        }
        else {
            "$editor$editorOptions ""{0}"" +{1}" -f $((Resolve-Path $FileList.Trim('"')).ProviderPath), $LineNum
        }
    }
    elseif ($editor -eq 'nano') {
        if ($FileList -is [array] -and $FileList.length -gt 1) {
            for ($i = 0; $i -lt $FileList.Count; $i++) {
                $FileList[$i] = '"{0}"' -f $((Resolve-Path $FileList[$i].Trim('"')).ProviderPath)
            }
            "$editor$editorOptions {0}" -f ($FileList -join ' ')
        }
        else {
            "$editor$editorOptions  +{1} {0}" -f $((Resolve-Path $FileList.Trim('"')).ProviderPath), $LineNum
        }
    }
}
function Invoke-FuzzyEdit() {
    param($Directory = ".", [switch]$Wait)

    $files = @()
    try {
        if ( Test-Path $Directory) {
            if ( (Get-Item $Directory).PsIsContainer ) {
                $prevDir = $PWD.ProviderPath
                cd $Directory
                Invoke-Expression (Get-FileSystemCmd .) | Invoke-Fzf -Multi | ForEach-Object { $files += "$_" }
            }
            else {
                $files += $Directory
                $Directory = Split-Path -Parent $Directory
            }
        }
    }
    catch {
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
            $cmd = Get-EditorLaunch -FileList $files
            Write-Host "Executing '$cmd'..."
            ($Editor, $Arguments) = $cmd.Split(' ')
            # Avoids code.cmd "error" message by not calling cmd.exe from a UNC $PWD
            if( ([uri]$PWD.ProviderPath).IsUnc ) {             
                cd $HOME
            }
            Start-Process $Editor -ArgumentList $Arguments -Wait:$Wait -NoNewWindow
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
        }
        elseif (Get-Command fasd -ErrorAction Ignore) {
            fasd -l | Invoke-Fzf -ReverseInput -NoSort | ForEach-Object { $result = $_ }
        }
    }
    catch {

    }
    if ($null -ne $result) {
        # use cd in case it's aliased to something else:
        cd $result
    }
}


#.ExternalHelp PSFzf.psm1-help.xml
function Invoke-FuzzyHistory() {
    if (Get-Command Get-PSReadLineOption -ErrorAction Ignore) {
        $result = Get-Content (Get-PSReadLineOption).HistorySavePath | Invoke-Fzf -Reverse -NoSort -Scheme history
    }
    else {
        $result = Get-History | ForEach-Object { $_.CommandLine } | Invoke-Fzf -Reverse -NoSort -Scheme history
    }
    if ($null -ne $result) {
        Write-Output "Invoking '$result'`n"
        Invoke-Expression "$result" -Verbose
    }
}


# needs to match helpers/GetProcessesList.ps1
function GetProcessesList() {
    Get-Process | `
        Where-Object { ![string]::IsNullOrEmpty($_.ProcessName) } | `
        ForEach-Object {
        $pmSize = $_.PM / 1MB
        $cpu = $_.CPU
        # make sure we display a value so we can correctly parse selections:
        if ($null -eq $cpu) {
            $cpu = 0.0
        }
        "{0,-8:n2} {1,-8:n2} {2,-8} {3}" -f $pmSize, $cpu, $_.Id, $_.ProcessName }
}

function GetProcessSelection() {
    param(
        [scriptblock]
        $ResultAction
    )

    $previewScript = $(Join-Path $PsScriptRoot 'helpers/GetProcessesList.ps1')
    $cmd = $($script:PowershellCmd + " -NoProfile -NonInteractive -File \""$previewScript\""")

    $header = "`n" + `
        "`nCTRL+R-Reload`tCTRL+A-Select All`tCTRL+D-Deselect All`tCTRL+T-Toggle All`n`n" + `
    $("{0,-8} {1,-8} {2,-8} PROCESS NAME" -f "PM(M)", "CPU", "ID") + "`n" + `
        "{0,-8} {1,-8} {2,-8} {3,-12}" -f "-----", "---", "--", "------------"

    $result = GetProcessesList | `
        Invoke-Fzf -Multi -Header $header `
        -Bind "ctrl-r:reload($cmd)", "ctrl-a:select-all", "ctrl-d:deselect-all", "ctrl-t:toggle-all" `
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
        $resultSplit = $result.split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
        $processIdIdx = 2
        $id = $resultSplit[$processIdIdx]
        Stop-Process -Id $id -Verbose
    }
}

#.ExternalHelp PSFzf.psm1-help.xml
function Invoke-FuzzySetLocation() {
    param($Directory = $null)

    if ($null -eq $Directory) { $Directory = $PWD.ProviderPath }
    $result = $null
    try {
        Get-ChildItem $Directory -Recurse -ErrorAction Ignore | Where-Object { $_.PSIsContainer } | Invoke-Fzf | ForEach-Object { $result = $_ }
    }
    catch {

    }

    if ($null -ne $result) {
        Set-Location $result
    }
}

if ((-not $IsLinux) -and (-not $IsMacOS)) {
    #.ExternalHelp PSFzf.psm1-help.xml
    function Set-LocationFuzzyEverything() {
        param($Directory = $null)
        if ($null -eq $Directory) {
            $Directory = $PWD.ProviderPath
            $Global = $False
        }
        else {
            $Global = $True
        }
        $result = $null
        try {
            Search-Everything -Global:$Global -PathInclude $Directory -FolderInclude @('') | Invoke-Fzf | ForEach-Object { $result = $_ }
        }
        catch {

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
        (Get-ZLocation).GetEnumerator() | Sort-Object { $_.Value } -Descending | ForEach-Object { $_.Key } | Invoke-Fzf -NoSort | ForEach-Object { $result = $_ }
    }
    catch {

    }
    if ($null -ne $result) {
        # use cd in case it's aliased to something else:
        cd $result
    }
}


#.ExternalHelp PSFzf.psm1-help.xml
function Invoke-FuzzyScoop() {
    param(
        [string]$subcommand = "install",
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

function Invoke-PsFzfRipgrep() {
    # this function is adapted from https://github.com/junegunn/fzf/blob/master/ADVANCED.md#switching-between-ripgrep-mode-and-fzf-mode
    param([Parameter(Mandatory)]$SearchString, [switch]$NoEditor)

    $RG_PREFIX = "rg --column --line-number --no-heading --color=always --smart-case "
    $INITIAL_QUERY = $SearchString

    $script:OverrideFzfDefaultCommand = [FzfDefaultCmd]::new('')
    try {
        if ($script:IsWindows) {
            $sleepCmd = ''
            $trueCmd = 'cd .'
            $env:FZF_DEFAULT_COMMAND = "$RG_PREFIX ""$INITIAL_QUERY"""
        }
        else {
            $sleepCmd = 'sleep 0.1;'
            $trueCmd = 'true'
            $env:FZF_DEFAULT_COMMAND = '{0} $(printf %q "{1}")' -f $RG_PREFIX, $INITIAL_QUERY
        }

        & $script:FzfLocation --ansi `
            --color "hl:-1:underline,hl+:-1:underline:reverse" `
            --disabled --query "$INITIAL_QUERY" `
            --bind "change:reload:$sleepCmd $RG_PREFIX {q} || $trueCmd" `
            --bind "ctrl-f:unbind(change,ctrl-f)+change-prompt(2. fzf> )+enable-search+clear-query+rebind(ctrl-r)" `
            --bind "ctrl-r:unbind(ctrl-r)+change-prompt(1. ripgrep> )+disable-search+reload($RG_PREFIX {q} || $trueCmd)+rebind(change,ctrl-f)" `
            --prompt '1. Ripgrep> ' `
            --delimiter : `
            --header '╱ CTRL-R (Ripgrep mode) ╱ CTRL-F (fzf mode) ╱' `
            --preview 'bat --color=always {1} --highlight-line {2}' `
            --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' | `
            ForEach-Object { $results += $_ }

        if (-not [string]::IsNullOrEmpty($results)) {
            $split = $results.Split(':')
            $fileList = $split[0]
            $lineNum = $split[1]
            if ($NoEditor) {
                Resolve-Path $fileList
            }
            else {
                $cmd = Get-EditorLaunch -FileList $fileList -LineNum $lineNum
                Write-Host "Executing '$cmd'..."
                Invoke-Expression -Command $cmd
            }
        }
    }
    catch {
        Write-Error "Error occurred: $_"
    }
    finally {
        if ($script:OverrideFzfDefaultCommand) {
            $script:OverrideFzfDefaultCommand.Restore()
            $script:OverrideFzfDefaultCommand = $null
        }
    }
}

function Enable-PsFzfAliases() {
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
