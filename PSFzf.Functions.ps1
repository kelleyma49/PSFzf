function Invoke-FuzzyEdit()
{
    $files = $null | Invoke-Fzf -Multi

    $editor = $env:EDITOR
    # default to Visual Studio Code:
    if ($editor -eq $null) {
        $editor = 'code'
    }
    if ($files -ne $null) {
        Invoke-Expression -Command ("$editor {0}" -f ($files -join ' ')) 
    }
}