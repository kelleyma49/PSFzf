function Invoke-FuzzyEdit()
{
    $files = Invoke-Fzf -Multi

    $editor = $env:EDITOR
    # default to Visual Studio Code:
    if ($editor -eq $null) {
        $editor = 'code'
    }
    if ($files -ne $null) {
        Invoke-Expression -Command ("$editor {0}" -f ($files -join ' ')) 
    }
}
Set-Alias -Name fe -Value Invoke-FuzzyEdit

if (Get-Command Get-Frecents -ErrorAction SilentlyContinue) {
    function Invoke-FuzzyFasdr() {
        $result = $null
        try {
            Get-Frecents | % { $_.FullPath } | Invoke-Fzf -Reverse -NoSort -ThrowException | % { $result = $_ }
        } catch {
            
        }
        if ($result -ne $null) {
            # use cd in case it's aliased to something else:
            cd $result
        }
    }
    Set-Alias -Name ff -Value Invoke-FuzzyFasdr
}

function Invoke-FuzzyHistory() {
    $result = Get-History | % { $_.CommandLine } | Invoke-Fzf -Reverse -NoSort
    if ($result -ne $null) {
        Write-Output "Invoking '$result'`n"
        Invoke-Expression "$result" -Verbose
    }
}
Set-Alias -Name fh -Value Invoke-FuzzyHistory

function Invoke-FuzzyKillProcess() {
    $result = Get-Process | % { "{0}: {1}" -f $_.Id,$_.Name } | Invoke-Fzf -Multi
    $result | % {
        $id = $_ -replace "([0-9]+)(:)(.*)",'$1' 
        Stop-Process $id 
    }
}
Set-Alias -Name fkill -Value Invoke-FuzzyKillProcess

function Invoke-FuzzySetLocation() {
    param($Directory=$null)

    if ($Directory -eq $null) { $Directory = $PWD.Path }
    $result = Get-ChildItem $Directory -Recurse | ?{ $_.PSIsContainer } | % { $_.FullName } | Invoke-Fzf 
    Set-Location $result
}
Set-Alias -Name fd -Value Invoke-FuzzySetLocation

if (Get-Command Search-Everything -ErrorAction SilentlyContinue) {
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
