
$script:GitKeyHandlers = @()

$script:gitPath = $null
function SetGitKeyBindings($enable)
{
    if ($enable)
    {
        if ($null -eq $gitPath) {
            $gitInfo = Get-Command git.exe -ErrorAction SilentlyContinue
            if ($null -ne $gitInfo) {
                $script:gitPath = Split-Path (Split-Path $gitInfo.Source -Parent) -Parent  

                $a = New-Object -ComObject Scripting.FileSystemObject 
                $f = $a.GetFolder($script:gitPath) 
                $script:gitPath = $f.ShortPath
            } else {
                Write-Error "Failed to register git key bindings - git executable not found"
                return
            }
        }
        if (Get-Command Set-PSReadLineKeyHandler -ErrorAction SilentlyContinue) {
            @('ctrl+g,ctrl+f','Select Git Files', {Invoke-PsFzfGitFiles}), `
            @('ctrl+g,ctrl+s','Select Git Hashes', {Invoke-PsFzfGitHashes}) | ForEach-Object {
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
function Invoke-PsFzfGitFiles() {
    if (-not (IsInGitRepo)) {
        return
    }

    $previewCmd = $(Join-Path $PsScriptRoot 'PsFzfGitFiles-Preview.bat') + " ${script:gitPath}" + ' {-1}'
    $result = @()
    git -c color.status=always status --short | `
        Invoke-Fzf -Border -Multi -Ansi `
            -Preview "$previewCmd" | foreach-object { $result += $_.Substring('?? '.Length) } 
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

    $previewCmd = $(Join-Path $PsScriptRoot 'PsFzfGitHashes-Preview.bat') + " ${script:gitPath}" + ' {}'
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