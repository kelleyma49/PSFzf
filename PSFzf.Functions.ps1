#.ExternalHelp PSFzf.psm1-help.xml
function Invoke-FuzzyEdit()
{
    $files = Invoke-Fzf -Multi

    $editor = $env:EDITOR
    if ($editor -eq $null) {
        if (!$IsWindows) {
            $editor = 'vim'
        } else {
            $editor = 'code'
        }
    }
    if ($files -ne $null) {
        Invoke-Expression -Command ("$editor {0}" -f ($files -join ' ')) 
    }
}
Set-Alias -Name fe -Value Invoke-FuzzyEdit

if (Get-Command Get-Frecents -ErrorAction SilentlyContinue) {
    #.ExternalHelp PSFzf.psm1-help.xml
    function Invoke-FuzzyFasd() {
        $result = $null
        try {
            Get-Frecents | % { $_.FullPath } | Invoke-Fzf -ReverseInput -NoSort -ThrowException | % { $result = $_ }
        } catch {
            
        }
        if ($result -ne $null) {
            # use cd in case it's aliased to something else:
            cd $result
        }
    }
    Set-Alias -Name ff -Value Invoke-FuzzyFasd
} elseif (Get-Command fasd -ErrorAction SilentlyContinue) {
    #.ExternalHelp PSFzf.psm1-help.xml
    function Invoke-FuzzyFasd() {
        $result = $null
        try {
            fasd -l | Invoke-Fzf -ReverseInput -NoSort -ThrowException | % { $result = $_ }
        } catch {
            
        }
        if ($result -ne $null) {
            # use cd in case it's aliased to something else:
            cd $result
        }
    }
    Set-Alias -Name ff -Value Invoke-FuzzyFasd    
}

#.ExternalHelp PSFzf.psm1-help.xml
function Invoke-FuzzyHistory() {
    $result = Get-History | % { $_.CommandLine } | Invoke-Fzf -Reverse -NoSort
    if ($result -ne $null) {
        Write-Output "Invoking '$result'`n"
        Invoke-Expression "$result" -Verbose
    }
}
Set-Alias -Name fh -Value Invoke-FuzzyHistory

#.ExternalHelp PSFzf.psm1-help.xml
function Invoke-FuzzyKillProcess() {
    $result = Get-Process | where { ![string]::IsNullOrEmpty($_.ProcessName) } | % { "{0}: {1}" -f $_.Id,$_.ProcessName } | Invoke-Fzf -Multi
    $result | % {
        $id = $_ -replace "([0-9]+)(:)(.*)",'$1' 
        Stop-Process $id -Verbose
    }
}
Set-Alias -Name fkill -Value Invoke-FuzzyKillProcess

#.ExternalHelp PSFzf.psm1-help.xml
function Invoke-FuzzySetLocation() {
    param($Directory=$null)

    if ($Directory -eq $null) { $Directory = $PWD.Path }
    $result = Get-ChildItem $Directory -Recurse -ErrorAction SilentlyContinue | ?{ $_.PSIsContainer } | % { $_.FullName } | Invoke-Fzf 
    Set-Location $result
}
Set-Alias -Name fd -Value Invoke-FuzzySetLocation

if (Get-Command Search-Everything -ErrorAction SilentlyContinue) {
    #.ExternalHelp PSFzf.psm1-help.xml
    function Set-LocationFuzzyEverything() {
        $result = $null
        try {
            Search-Everything | Invoke-Fzf -ThrowException | % { $result = $_ }
        } catch {
            
        }
        if ($result -ne $null) {
            # use cd in case it's aliased to something else:
            cd $result
        }
    }
    Set-Alias -Name cde -Value Set-LocationFuzzyEverything
}
