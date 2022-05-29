
$script:GitKeyHandlers = @()

$script:gitPath = $null
$script:bashPath = $null
$script:gitPathLong = $null

function SetGitKeyBindings($enable) {
    if ($IsLinux -or $IsMacOS) {
        Write-Error "Failed to register git key bindings - git bindings aren't supported on non-Windows platforms"
    }

    if ($enable) {
        if ($null -eq $gitPath) {
            $gitInfo = Get-Command git.exe -ErrorAction SilentlyContinue
            if ($null -ne $gitInfo) {
                $script:gitPathLong = Split-Path (Split-Path $gitInfo.Source -Parent) -Parent

                $a = New-Object -ComObject Scripting.FileSystemObject
                $f = $a.GetFolder($script:gitPathLong)
                $script:gitPath = $f.ShortPath
                $script:bashPath = $(Join-Path $script:gitPath "bin\bash.exe")
                $script:bashPath = Resolve-Path $script:bashPath
            }
            else {
                Write-Error "Failed to register git key bindings - git executable not found"
                return
            }
        }
        if (Get-Command Set-PSReadLineKeyHandler -ErrorAction SilentlyContinue) {
            @('ctrl+g,ctrl+f', 'Select Git files via fzf', { Invoke-PsFzfGitFiles }), `
            @('ctrl+g,ctrl+s', 'Select Git hashes via fzf', { Invoke-PsFzfGitHashes }), `
            @('ctrl+g,ctrl+b', 'Select Git branches via fzf', { Invoke-PsFzfGitBranches }) | ForEach-Object {
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

function Get-ColorAlways() {
    if ($RunningInWindowsTerminal) {
        ' --color=always'
    }
    else {
        ''
    }
}

function Get-HeaderStrings() {
    if ($RunningInWindowsTerminal) {
        $header = "`n`e[7mCTRL+A`e[0m Select All`t`e[7mCTRL+D`e[0m Deselect All`t`e[7mCTRL+T`e[0m Toggle All"
    }
    else {
        $header = "`nCTRL+A-Select All`tCTRL+D-Deselect All`tCTRL+T-Toggle All"
    }

    $keyBinds = 'ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all'
    return $Header, $keyBinds
}
function Invoke-PsFzfGitFiles() {
    if (-not (IsInGitRepo)) {
        return
    }

    $previewCmd = "${script:bashPath} \""" + $(Join-Path $PsScriptRoot 'helpers/PsFzfGitFiles-Preview.sh') + "\"" {-1}" + $(Get-ColorAlways) + " \""$pwd\"""
    $result = @()

    $headerStrings = Get-HeaderStrings

    git status --short | `
        Invoke-Fzf -Multi -Ansi `
        -Preview "$previewCmd" -Header $headerStrings[0] -Bind $headerStrings[1] | foreach-object {
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

    $previewCmd = "${script:bashPath} \""" + $(Join-Path $PsScriptRoot 'helpers/PsFzfGitHashes-Preview.sh') + "\"" {}" + $(Get-ColorAlways) + " \""$pwd\"""
    $result = @()

    & git log --date=short --format="%C(green)%C(bold)%cd %C(auto)%h%d %s (%an)" $(Get-ColorAlways).Trim()  | `
        Invoke-Fzf -Ansi -NoSort -Multi -Bind ctrl-s:toggle-sort `
        -Header 'CTRL+S-toggle sort' `
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

    $previewCmd = "${script:bashPath} \""" + $(Join-Path $PsScriptRoot 'helpers/PsFzfGitBranches-Preview.sh') + "\"" {}" + $(Get-ColorAlways) + " \""$pwd\"""
    $result = @()
    git branch -a | & "${script:gitPathLong}\usr\bin\grep.exe" -v '/HEAD\s' |
    ForEach-Object { $_.Substring('* '.Length) } | Sort-Object | `
        Invoke-Fzf -Ansi -Multi -PreviewWindow "right:70%" -Preview "$previewCmd" | ForEach-Object {
        $result += $_
    }

    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    if ($result.Length -gt 0) {
        $result = $result -join " "
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($result)
    }
}

# gb() {
#    is_in_git_repo || return
#    git branch -a --color=always | grep -v '/HEAD\s' | sort |
#    fzf-down --ansi --multi --tac --preview-window right:70% \
#      --preview 'git log --oneline --graph --date=short --color=always --pretty="format:%C(auto)%cd %h%d %s" $(sed s/^..// <<< {} | cut -d" " -f1) | head -'$LINES |
#    sed 's/^..//' | cut -d' ' -f1 |
#    sed 's#^remotes/##'
#  }