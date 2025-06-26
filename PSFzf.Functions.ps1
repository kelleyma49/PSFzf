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

    if ($editor -eq 'code' -or $editor -eq 'code-insiders' -or $editor -eq 'codium') {
        if ($FileList -is [array] -and $FileList.length -gt 1) {
            for ($i = 0; $i -lt $FileList.Count; $i++) {
                $FileList[$i] = '"{0}"' -f $(Resolve-Path $FileList[$i].Trim('"'))
            }
            "$editor$editorOptions {0}" -f ($FileList -join ' ')
        }
        else {
            "$editor$editorOptions --goto ""{0}:{1}""" -f $(Resolve-Path $FileList.Trim('"')), $LineNum
        }
    }
    elseif ($editor -match '[gn]?vi[m]?') {
        if ($FileList -is [array] -and $FileList.length -gt 1) {
            for ($i = 0; $i -lt $FileList.Count; $i++) {
                $FileList[$i] = '"{0}"' -f $(Resolve-Path $FileList[$i].Trim('"'))
            }
            "$editor$editorOptions {0}" -f ($FileList -join ' ')
        }
        else {
            "$editor$editorOptions ""{0}"" +{1}" -f $(Resolve-Path $FileList.Trim('"')), $LineNum
        }
    }
    elseif ($editor -eq 'nano') {
        if ($FileList -is [array] -and $FileList.length -gt 1) {
            for ($i = 0; $i -lt $FileList.Count; $i++) {
                $FileList[$i] = '"{0}"' -f $(Resolve-Path $FileList[$i].Trim('"'))
            }
            "$editor$editorOptions {0}" -f ($FileList -join ' ')
        }
        else {
            "$editor$editorOptions  +{1} ""{0}""" -f $(Resolve-Path $FileList.Trim('"')), $LineNum
        }
    }
    else {
        # select the first file as we don't know if the editor supports opening multiple files from the cmd line
        if ($FileList -is [array] -and $FileList.length -gt 1) {
            "$editor$editorOptions ""{0}""" -f $(Resolve-Path $FileList[0].Trim('"'))
        }
        else {
            "$editor$editorOptions ""{0}""" -f $(Resolve-Path $FileList.Trim('"'))
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
    $result = Get-PickedHistory -UsePSReadLineHistory:$($null -ne $(Get-Command Get-PSReadLineOption -ErrorAction Ignore))
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

    $arguments = @{
        Bind          = @("ctrl-r:reload($cmd)", "ctrl-a:select-all", "ctrl-d:deselect-all", "ctrl-t:toggle-all")
        Header        = $header
        Multi         = $true
        Preview       = "echo {}"
        PreviewWindow = """down,3,wrap"""
        Layout        = 'reverse'
        Height        = '80%'
    }

    $result = GetProcessesList | `
        Invoke-Fzf @arguments
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
        $command = if ($env:FZF_ALT_C_COMMAND) {
            $env:FZF_ALT_C_COMMAND
        }
        else {
            "Get-ChildItem ""$Directory"" -Recurse -ErrorAction Ignore | Where-Object { `$_.PSIsContainer } | ForEach-Object { `$_.FullName }"
        }
        Invoke-Expression $command | Invoke-Fzf | ForEach-Object { $result = $_ }
    }
    catch {
        Write-Error "An error occurred: $_"
    }

    if ($null -ne $result) {
        Set-Location $result -ErrorAction SilentlyContinue # Suppress error for test if path is fake
    }
    return $result # Explicitly return the result
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
    param(
        [string]$Query = $null
    )
    $result = $null
    try {
        $fzfParameters = @{
            NoSort = $true
        }
        if ($Query) {
            $fzfParameters.Query = $Query
        }
        $zlocationOutput = (Get-ZLocation).GetEnumerator() | Sort-Object { $_.Value } -Descending | ForEach-Object { $_.Key }
        # Ensure $zlocationOutput is an array for consistent behavior if only one item is returned
        $zlocationOutputArray = @($zlocationOutput) # This captures the output of ForEach-Object { $_.Key }

        # Explicitly pipe the collected array
        $fzfResult = $zlocationOutputArray | Invoke-Fzf @fzfParameters

        $fzfResult | ForEach-Object { $result = $_ }
    }
    catch {
        Write-Error "Error in Invoke-FuzzyZLocation: $_"
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
        $fzfArguments = @{
            color            = "hl:-1:underline,hl+:-1:underline:reverse"
            query            = $INITIAL_QUERY
            prompt           = 'ripgrep> '
            delimiter        = ':'
            header           = '? CTRL-R (Ripgrep mode) ? CTRL -F (fzf mode) ?'
            preview          = 'bat --no-config --color=always {1} --highlight-line {2}'
            'preview-window' = 'up,60%,border-bottom,+{2}+3/3,~3'
        }

        $fzfArgs = ($fzfArguments.GetEnumerator() | foreach-object { "--{0}=""{1}""" -f $_.Key, $_.Value }) -join ' '

        $Bind = @(
            'ctrl-r:unbind(change,ctrl-r)+change-prompt(ripgrep> )' + "+disable-search+reload($RG_PREFIX {q} || $trueCmd)+rebind(change,ctrl-f)"
        )
        $Bind += 'ctrl-f:unbind(change,ctrl-f)+change-prompt(fzf> )+enable-search+clear-query+rebind(ctrl-r)'
        $Bind += "change:reload:$sleepCmd $RG_PREFIX {q} || $trueCmd"
        $fzfArgs += ' --ansi --disabled ' + ($Bind | foreach-object { "--bind=""{0}""" -f $_ }) -join ' '

        Invoke-Expression -Command $('{0} {1}' -f $script:FzfLocation, $fzfArgs) | ForEach-Object { $results += $_ }

        # we need this here to prevent the editor launch from inherting FZF_DEFAULT_COMMAND from being overwritten (see #267):
        if ($script:OverrideFzfDefaultCommand) {
            $script:OverrideFzfDefaultCommand.Restore()
            $script:OverrideFzfDefaultCommand = $null
        }

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
