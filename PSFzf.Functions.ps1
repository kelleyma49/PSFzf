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

function Invoke-FuzzySetLocation() {
    param($Directory=$null)

    if ($Directory -eq $null) { $Directory = $PWD.Path }
    $result = Get-ChildItem $Directory -Recurse | ?{ $_.PSIsContainer } | % { $_.FullName } | Invoke-Fzf 
    Set-Location $result
}

function Invoke-FuzzyHistory() {
    $result = Get-History | % { $_.CommandLine } | Invoke-Fzf -Reverse -NoSort
    if ($result -ne $null) {
        Write-Output "Invoking '$result'`n"
        Invoke-Expression "$result" -Verbose
    }
}

function Invoke-FuzzyKillProcess() {
    $result = Get-Process | % { "{0}: {1}" -f $_.Id,$_.Name } | Invoke-Fzf -Multi
    $result | % {
        $id = $_ -replace "([0-9]+)(:)(.*)",'$1' 
        Stop-Process $id 
    }
}