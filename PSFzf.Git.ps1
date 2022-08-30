
$script:GitKeyHandlers = @()

$script:foundGit = $false
$script:bashPath = $null
$script:grepPath = $null

if ($PSVersionTable.PSEdition -eq 'Core') {
    $script:pwshExec = "pwsh"
}
else {
    $script:pwshExec = "powershell"
}

function Get-GitFzfArguments() {
    # take from https://github.com/junegunn/fzf-git.sh/blob/f72ebd823152fa1e9b000b96b71dd28717bc0293/fzf-git.sh#L89
    return @{
        Ansi          = $true
        Layout        = "reverse"
        Multi         = $true
        Height        = '50%'
        MinHeight     = 20
        Border        = $true
        Color         = 'header:italic:underline'
        PreviewWindow = 'right,50%,border-left'
        Bind          = @('ctrl-/:change-preview-window(down,50%,border-top|hidden|)')
    }
}

function SetupGitPaths() {
    if (-not $script:foundGit) {
        if ($IsLinux -or $IsMacOS) {
            # TODO: not tested on Mac
            $script:foundGit = $null -ne $(Get-Command git -ErrorAction SilentlyContinue)
            $script:bashPath = 'bash'
            $script:grepPath = 'grep'
        }
        else {
            $gitInfo = Get-Command git.exe -ErrorAction SilentlyContinue
            $script:foundGit = $null -ne $gitInfo
            if ($script:foundGit) {
                $gitPathLong = Split-Path (Split-Path $gitInfo.Source -Parent) -Parent
                # hack to get short path:
                $a = New-Object -ComObject Scripting.FileSystemObject
                $f = $a.GetFolder($gitPathLong)
                $script:bashPath = Join-Path $f.ShortPath "bin\bash.exe"
                $script:bashPath = Resolve-Path $script:bashPath
                $script:grepPath = Join-Path ${gitPathLong} "usr\bin\grep.exe"
            }
        }
    }
    return $script:foundGit
}
function SetGitKeyBindings($enable) {
    if ($enable) {
        if (-not $(SetupGitPaths)) {
            Write-Error "Failed to register git key bindings - git executable not found"
            return
        }

        if (Get-Command Set-PSReadLineKeyHandler -ErrorAction SilentlyContinue) {
            @('ctrl+g,ctrl+f', 'Select Git files via fzf', { Invoke-PsFzfGitFiles }), `
            @('ctrl+g,ctrl+h', 'Select Git hashes via fzf', { Invoke-PsFzfGitHashes }), `
            @('ctrl+g,ctrl+b', 'Select Git branches via fzf', { Invoke-PsFzfGitBranches }), `
            @('ctrl+g,ctrl+t', 'Select Git tags via fzf', { Invoke-PsFzfGitTags }), `
            @('ctrl+g,ctrl+s', 'Select Git stashes via fzf', { Invoke-PsFzfGitStashes }) `
            | ForEach-Object {
                $script:GitKeyHandlers += $_[0]
                Set-PSReadLineKeyHandler -Chord $_[0] -Description $_[1] -ScriptBlock $_[2]
            }
        }
        else {
            Write-Error "Failed to register git key bindings - PSReadLine module not loaded"
            return
        }
    }
}

function RemoveGitKeyBindings() {
    $script:GitKeyHandlers | ForEach-Object {
        Remove-PSReadLineKeyHandler -Chord $_
    }
}

function IsInGitRepo() {
    git rev-parse HEAD 2>&1 | Out-Null
    return $?
}

function Get-ColorAlways($setting = ' --color=always') {
    if ($RunningInWindowsTerminal -or -not $IsWindowsCheck) {
        return $setting
    }
    else {
        return ''
    }
}

function Get-HeaderStrings() {
    $header = "CTRL-A (Select all) / CTRL-D (Deselect all) / CTRL-T (Toggle all)"
    $keyBinds = 'ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all'
    return $Header, $keyBinds
}
function Invoke-PsFzfGitFiles() {
    if (-not (IsInGitRepo)) {
        return
    }

    if (-not $(SetupGitPaths)) {
        Write-Error "git executable could not be found"
        return
    }

    $previewCmd = "${script:bashPath} \""" + $(Join-Path $PsScriptRoot 'helpers/PsFzfGitFiles-Preview.sh') + "\"" {-1}" + $(Get-ColorAlways) + " \""$($pwd.ProviderPath)\"""
    $result = @()

    $headerStrings = Get-HeaderStrings
    $gitCmdsHeader = "`nALT-S (Git add) / ALT-R (Git reset)"
    $headerStr = $headerStrings[0] + $gitCmdsHeader + "`n`n"
    $statusCmd = "git $(Get-ColorAlways '-c color.status=always') status --short"

    $reloadBindCmd = "reload($statusCmd)"
    $stageScriptPath = Join-Path $PsScriptRoot 'helpers/PsFzfGitFiles-GitAdd.sh'
    $gitStageBind = "alt-s:execute-silent(" + """${script:bashPath}"" '${stageScriptPath}' {+2..})+down+${reloadBindCmd}"
    $resetScriptPath = Join-Path $PsScriptRoot 'helpers/PsFzfGitFiles-GitReset.sh'
    $gitResetBind = "alt-r:execute-silent(" + """${script:bashPath}"" '${resetScriptPath}' {+2..})+down+${reloadBindCmd}"

    $fzfArguments = Get-GitFzfArguments
    $fzfArguments['Bind'] += $headerStrings[1], $gitStageBind, $gitResetBind
    Invoke-Expression "& $statusCmd" | `
        Invoke-Fzf @fzfArguments `
        -Prompt '📁 Files> ' `
        -Preview "$previewCmd" -Header $headerStr | `
        foreach-object {
        $result += $_.Substring('?? '.Length)
    }
    InvokePromptHack
    if ($result.Length -gt 0) {
        $result = $result -join " "
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($result)
    }
}
function Invoke-PsFzfGitHashes() {
    if (-not (IsInGitRepo)) {
        return
    }

    if (-not $(SetupGitPaths)) {
        Write-Error "git executable could not be found"
        return
    }

    $previewCmd = "${script:bashPath} \""" + $(Join-Path $PsScriptRoot 'helpers/PsFzfGitHashes-Preview.sh') + "\"" {}" + $(Get-ColorAlways) + " \""$pwd\"""
    $result = @()

    $fzfArguments = Get-GitFzfArguments
    & git log --date=short --format="%C(green)%C(bold)%cd %C(auto)%h%d %s (%an)" $(Get-ColorAlways).Trim() --graph | `
        Invoke-Fzf @fzfArguments -NoSort  `
        -Prompt '🍡 Hashes> ' `
        -Preview "$previewCmd" | ForEach-Object {
        if ($_ -match '\d\d-\d\d-\d\d\s+([a-f0-9]+)\s+') {
            $result += $Matches.1
        }
    }

    InvokePromptHack
    if ($result.Length -gt 0) {
        $result = $result -join " "
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($result)
    }
}

function Invoke-PsFzfGitBranches() {
    if (-not (IsInGitRepo)) {
        return
    }

    if (-not $(SetupGitPaths)) {
        Write-Error "git executable could not be found"
        return
    }

    $fzfArguments = Get-GitFzfArguments
    $fzfArguments['PreviewWindow'] = 'down,border-top,40%'
    $fzfArguments['Bind'] += 'ctrl-/:change-preview-window(down,70%|hidden|)'
    $previewCmd = "${script:bashPath} \""" + $(Join-Path $PsScriptRoot 'helpers/PsFzfGitBranches-Preview.sh') + "\"" {}"
    $result = @()
    # use pwsh to prevent bash from trying to write to host output:
    $branches = & $script:pwshExec -NoProfile -NonInteractive -Command "&  ${script:bashPath} '$(Join-Path $PsScriptRoot 'helpers/PsFzfGitBranches.sh')' branches"
    $branches |
    Invoke-Fzf @fzfArguments -Preview "$previewCmd" -Prompt '🌲 Branches> ' -HeaderLines 2 -Tiebreak begin -ReverseInput | `
        ForEach-Object {
        $result += $($_.Substring('* '.Length) -split ' ')[0]
    }

    InvokePromptHack
    if ($result.Length -gt 0) {
        $result = $result -join " "
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($result)
    }
}

function Invoke-PsFzfGitTags() {
    if (-not (IsInGitRepo)) {
        return
    }

    if (-not $(SetupGitPaths)) {
        Write-Error "git executable could not be found"
        return
    }

    $fzfArguments = Get-GitFzfArguments
    $fzfArguments['PreviewWindow'] = 'right,70%'
    $previewCmd = "git show --color=always {}"
    $result = @()
    git tag --sort -version:refname |
    Invoke-Fzf @fzfArguments -Preview "$previewCmd" -Prompt '📛 Tags> ' | `
        ForEach-Object {
        $result += $_
    }

    InvokePromptHack
    if ($result.Length -gt 0) {
        $result = $result -join " "
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($result)
    }
}

function Invoke-PsFzfGitStashes() {
    if (-not (IsInGitRepo)) {
        return
    }

    if (-not $(SetupGitPaths)) {
        Write-Error "git executable could not be found"
        return
    }

    $fzfArguments = Get-GitFzfArguments
    $fzfArguments['Bind'] += 'ctrl-x:execute-silent(git stash drop {1})+reload(git stash list)'
    $header = "CTRL-X (drop stash)`n`n"
    $previewCmd = 'git show --color=always {1}'

    $result = @()
    git stash list --color=always |
    Invoke-Fzf @fzfArguments -Header $header -Delimiter ':' -Preview "$previewCmd" -Prompt '🥡 Stashes> ' | `
        ForEach-Object {
        $result += $_.Split(':')[0]
    }

    InvokePromptHack
    if ($result.Length -gt 0) {
        $result = $result -join " "
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("""$result""")
    }
}
