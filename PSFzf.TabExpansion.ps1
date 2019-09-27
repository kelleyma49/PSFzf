if (Test-Path Function:\TabExpansion) {
    Rename-Item Function:\TabExpansion TabExpansionBackupPSFzf
}

function Invoke-FzfWithGit($lastBlock) {
    Expand-GitCommand $lastBlock | Invoke-Fzf 
}

function TabExpansion($line, $lastWord) {
    $lastBlock = [regex]::Split($line, '[|;]')[-1].TrimStart()

    if ($lastWord.EndsWith('**')) {
        $lastBlock = $lastBlock.Substring(0,$lastBlock.Length-2)
        switch -regex ($lastBlock) {
            # Execute git tab completion for all git-related commands
            "^$(Get-AliasPattern git) (.*)" {  Invoke-FzfWithGit $lastBlock }
            "^$(Get-AliasPattern tgit) (.*)" { Invoke-FzfWithGit $lastBlock }
            "^$(Get-AliasPattern gitk) (.*)" { Invoke-FzfWithGit $lastBlock }
            "^$(Get-AliasPattern Remove-GitBranch) (.*)" { Invoke-FzfWithGit $lastBlock }

            # Fall back on existing tab expansion
            default {

                $lastWord = $lastWord.Substring(0,$lastWord.Length-2)
                if ($lastWord.EndsWith('\')) {
                    $dir = $lastWord.Substring(0,$lastWord.Length-1)
                    $file = $null    
                } else {
                    $dir = Split-Path $lastWord -Parent
                    $file = Split-Path $lastWord -Leaf    
                }
                if (-not [System.IO.Path]::IsRooted($dir)) {
                    $dir = Join-Path $PWD.Path $dir
                }
                $prevPath = $Pwd.Path
                try {
                    if (-not [string]::IsNullOrEmpty($dir)) {
                        Set-Location $dir
                    }
                    if (-not [string]::IsNullOrEmpty($file)) {
                        Invoke-Fzf -Query $file
                    } else {
                        Invoke-Fzf
                    }
                } finally {
                    Set-Location $prevPath
                }
            }
        }
    } else {
        if (Test-Path Function:\TabExpansionBackupPSFzf) {
            TabExpansionBackupPSFzf $line $lastWord
        }
    }
}