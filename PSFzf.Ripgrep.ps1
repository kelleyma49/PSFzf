function Invoke-PsFzfRipgrep() {
    param([Parameter(Mandatory)]$SearchString)
    $(rg --color=always --line-number --no-heading --smart-case "${*:-}" "$SearchString" | `
        fzf.exe --ansi --delimiter ':' --preview 'bat --color=always {1} --highlight-line {2}' --preview-window 'up,60%,border-bottom,+{2}+3/3,~3') | `
        ForEach-Object { $results += $_ }

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