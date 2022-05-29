function Invoke-PsFzfRipgrep() {
    param([Parameter(Mandatory)]$SearchString)

    $env:FZF_DEFAULT_COMMAND = 'rg --color=always --line-number --no-heading ' + $SearchString
    fzf.exe --ansi --delimiter ':' --preview 'bat --color=always {1} --highlight-line {2}' --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' | `
        ForEach-Object { $results += $_ }
    #TODO: restore default command and make sure it works in PSReadline keyboard shortcut

    # invoke editor if we got results:
    if (-not [string]::IsNullOrEmpty($results)) {
        $split = $results.Split(':')
        $fileList = Resolve-Path $split[0]
        $lineNum = $split[1]
        $cmd = Get-EditorLaunch -FileList $fileList -LineNum $lineNum
        Write-Host "Executing $cmd..."
        Invoke-Expression -Command $cmd
    }
}