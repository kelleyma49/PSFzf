
$script:GitKeyHandlers = @()

$script:gitPath = $null
$script:gitPathLong = $null

function SetGitKeyBindings($enable)
{
    if ($IsLinux -or $IsMacOS) {
        Write-Error "Failed to register git key bindings - git bindings aren't supported on non-Windows platforms"
    }

    if (-not $RunningInWindowsTerminal) {
        Write-Error "Failed to register git key bindings - git bindings are only supported in Windows Terminal"      
    }

    if ($enable)
    {
        if ($null -eq $gitPath) {
            $gitInfo = Get-Command git.exe -ErrorAction SilentlyContinue
            if ($null -ne $gitInfo) {
                $script:gitPathLong = Split-Path (Split-Path $gitInfo.Source -Parent) -Parent  

                $a = New-Object -ComObject Scripting.FileSystemObject 
                $f = $a.GetFolder($script:gitPathLong) 
                $script:gitPath = $f.ShortPath
            } else {
                Write-Error "Failed to register git key bindings - git executable not found"
                return
            }
        }
        if (Get-Command Set-PSReadLineKeyHandler -ErrorAction SilentlyContinue) {
            @('ctrl+g,ctrl+f','Select Git Files', {Invoke-PsFzfGitFiles}), `
            @('ctrl+g,ctrl+s','Select Git Hashes', {Invoke-PsFzfGitHashes}), `
            @('ctrl+g,ctrl+b','Select Git Branches', {Invoke-PsFzfGitBranches}) | ForEach-Object {
                $script:GitKeyHandlers += $_[0]
                Set-PSReadLineKeyHandler -Chord $_[0] -Description $_[1] -ScriptBlock $_[2]
            }
        } else {
            Write-Error "Failed to register git key bindings - PSReadLine module not loaded"
            return
        }
    }
}

function RemoveGitKeyBindings()
{
    $script:GitKeyHandlers | ForEach-Object {
        Remove-PSReadLineKeyHandler -Chord $_
    }
}

function IsInGitRepo()
{
    git rev-parse HEAD 2>&1 | Out-Null
    return $?
}

function Get-HeaderStrings() {
    if ($RunningInWindowsTerminal) {
        $header = "`n`e[7mCTRL+A`e[0m Select All`t`e[7mCTRL+D`e[0m Deselect All`t`e[7mCTRL+T`e[0m Toggle All"
    } else {
        $header = "`nCTRL+A-Select All`tCTRL+D-Deselect All`tCTRL+T-Toggle All"
    }

    $keyBinds = 'ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all'
    return $Header, $keyBinds
}
function Invoke-PsFzfGitFiles() {
    if (-not (IsInGitRepo)) {
        return
    }

    $previewCmd = $(Join-Path $PsScriptRoot 'bat' 'PsFzfGitFiles-Preview.bat') + " ${script:gitPath}" + ' {-1}'
    $result = @()

    $headerStrings = Get-HeaderStrings

    git -c color.status=always status --short | `
        Invoke-Fzf -Border -Multi -Ansi `
            -Preview "$previewCmd" -Header $headerStrings[0] -Bind $headerStrings[1] | foreach-object { 
                $result += $_.Substring('?? '.Length) 
            } 
    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    if ($result.Length -gt 0) {
        $result = $result -join " "
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($result)
    }
}
function Invoke-PsFzfGitHashes() {
    if (-not (IsInGitRepo)) {
        return
    }

    $previewCmd = $(Join-Path $PsScriptRoot 'bat' 'PsFzfGitHashes-Preview.bat') + " ${script:gitPath}" + ' {}'
    $result = @()
    git log --date=short --format="%C(green)%C(bold)%cd %C(auto)%h%d %s (%an)" --graph --color=always | `
        Invoke-Fzf -Ansi -NoSort -ReverseInput -Multi -Bind ctrl-s:toggle-sort `
        -Header 'Press CTRL-S to toggle sort' `
        -Preview "$previewCmd" | ForEach-Object {
            if ($_ -match '(\s+[a-f0-9]{7,7}\s+)|(\s+[a-f0-9]{40,40}\s+)') {
                $result += $Matches[0].Trim()
            }
        }

    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    if ($result.Length -gt 0) {
        $result = $result -join " "
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($result)
    }
 }

 function Invoke-PsFzfGitBranches() {
    if (-not (IsInGitRepo)) {
        return
    }

    $previewCmd = $(Join-Path $PsScriptRoot 'bat' 'PsFzfGitBranches-Preview.bat') + " ${script:gitPath}" + ' {}'
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