function Invoke-FuzzyEdit()
{
    $files = Invoke-Fzf -Multi

    $editor = $env:EDITOR
    # default to Visual Studio Code:
    if ($editor -eq $null) {
        $editor = 'code'
    }
    if ($files -ne $null) {
        echo ($files -join ' ')
        & "$editor" ($files -join ' ') 
    }
}