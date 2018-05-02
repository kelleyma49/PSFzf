#.ExternalHelp PSFzf.psm1-help.xml
function Invoke-FuzzyEdit()
{
    param($Directory=$null)

    $files = @()
    try {
        if ($Directory) {
            $prevDir = $PWD.Path
            cd $Directory
        }
        Invoke-Fzf -Multi | ForEach-Object { $files += """$_""" }
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
    if ($env:VSCODE_PID -ne $null) {
        $editor = 'code'
        $editorOptions += '--reuse-window'
    } else {
        $editor = $env:EDITOR
        if ($editor -eq $null) {
            if (!$IsWindows) {
                $editor = 'vim'
            } else {
                $editor = 'code'
            }
        }
    }
    
    if ($files -ne $null) {
        Invoke-Expression -Command ("$editor $editorOptions {0}" -f ($files -join ' ')) 
    }
}
New-Alias -Name fe -Value Invoke-FuzzyEdit -ErrorAction SilentlyContinue

if (Get-Command Get-Frecents -ErrorAction SilentlyContinue) {
    #.ExternalHelp PSFzf.psm1-help.xml
    function Invoke-FuzzyFasd() {
        $result = $null
        try {
            Get-Frecents | ForEach-Object { $_.FullPath } | Invoke-Fzf -ReverseInput -NoSort | ForEach-Object { $result = $_ }
        } catch {
            
        }
        if ($result -ne $null) {
            # use cd in case it's aliased to something else:
            cd $result
        }
    }
    New-Alias -Name ff -Value Invoke-FuzzyFasd -ErrorAction SilentlyContinue
} elseif (Get-Command fasd -ErrorAction SilentlyContinue) {
    #.ExternalHelp PSFzf.psm1-help.xml
    function Invoke-FuzzyFasd() {
        $result = $null
        try {
            fasd -l | Invoke-Fzf -ReverseInput -NoSort | ForEach-Object { $result = $_ }
        } catch {
            
        }
        if ($result -ne $null) {
            # use cd in case it's aliased to something else:
            cd $result
        }
    }
    New-Alias -Name ff -Value Invoke-FuzzyFasd -ErrorAction SilentlyContinue    
}

#.ExternalHelp PSFzf.psm1-help.xml
function Invoke-FuzzyHistory() {
    $result = Get-History | ForEach-Object { $_.CommandLine } | Invoke-Fzf -Reverse -NoSort
    if ($result -ne $null) {
        Write-Output "Invoking '$result'`n"
        Invoke-Expression "$result" -Verbose
    }
}
New-Alias -Name fh -Value Invoke-FuzzyHistory -ErrorAction SilentlyContinue

#.ExternalHelp PSFzf.psm1-help.xml
function Invoke-FuzzyKillProcess() {
    $result = Get-Process | Where-Object { ![string]::IsNullOrEmpty($_.ProcessName) } | ForEach-Object { "{0}: {1}" -f $_.Id,$_.ProcessName } | Invoke-Fzf -Multi
    $result | ForEach-Object {
        $id = $_ -replace "([0-9]+)(:)(.*)",'$1' 
        Stop-Process $id -Verbose
    }
}
New-Alias -Name fkill -Value Invoke-FuzzyKillProcess -ErrorAction SilentlyContinue

#.ExternalHelp PSFzf.psm1-help.xml
function Invoke-FuzzySetLocation() {
    param($Directory=$null)

    if ($Directory -eq $null) { $Directory = $PWD.Path }
    $result = $null
    try {
        Get-ChildItem $Directory -Recurse -ErrorAction SilentlyContinue | Where-Object{ $_.PSIsContainer } | Invoke-Fzf | ForEach-Object { $result = $_ }
    } catch {
        
    }

    if ($result -ne $null) {
        Set-Location $result
    } 
}
New-Alias -Name fd -Value Invoke-FuzzySetLocation -ErrorAction SilentlyContinue

if (Get-Command Search-Everything -ErrorAction SilentlyContinue) {
    #.ExternalHelp PSFzf.psm1-help.xml
    function Set-LocationFuzzyEverything() {
        param($Directory=$null)
        if ($Directory -eq $null) {
            $Directory = $PWD.Path
            $Global = $False
        } else {
            $Global = $True
        }
        $result = $null
        try {
            Search-Everything -Global:$Global -PathInclude $Directory -FolderInclude @('') | Invoke-Fzf | ForEach-Object { $result = $_ }
        } catch {
            
        }
        if ($result -ne $null) {
            # use cd in case it's aliased to something else:
            cd $result
        }
    }
    New-Alias -Name cde -Value Set-LocationFuzzyEverything -ErrorAction SilentlyContinue
}

if (Get-Command Get-ZLocation -ErrorAction SilentlyContinue) {
    #.ExternalHelp PSFzf.psm1-help.xml
    function Invoke-FuzzyZLocation() {
        $result = $null
        try {
            (Get-ZLocation).GetEnumerator() | Sort-Object { $_.Value } -Descending | ForEach-Object{ $_.Key } | Invoke-Fzf -NoSort | ForEach-Object { $result = $_ }
        } catch {
            
        }
        if ($result -ne $null) {
            cd $result
        }
    }
    New-Alias -Name fz -Value Invoke-FuzzyZLocation -ErrorAction SilentlyContinue
} 

if (Get-Command git -ErrorAction SilentlyContinue) {
    #.ExternalHelp PSFzf.psm1-help.xml
    function Invoke-FuzzyGitStatus() {
        $result = @()
        try {
            $gitRoot = git rev-parse --show-toplevel
            git status --porcelain | Invoke-Fzf -Multi -Bind 'ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all' | ForEach-Object { $result += Join-Path $gitRoot $('{0}' -f $_.Substring('?? '.Length)) }
        } catch {
            # do nothing
        }
        if ($result -ne $null) {
            $result
        }
    }
    New-Alias -Name fgs -Value Invoke-FuzzyGitStatus -ErrorAction SilentlyContinue
}
