if (Test-Path Function:\TabExpansion) {
    Rename-Item Function:\TabExpansion TabExpansionBackupPSFzf
}

function Expand-GitWithFzf($lastBlock) {
    Expand-GitCommand $lastBlock | Invoke-Fzf 
}

function Expand-FileDirectoryPath($lastWord) {
            # find dir and file pattern connected to the trigger:
            $lastWord = $lastWord.Substring(0, $lastWord.Length - 2)
            if ($lastWord.EndsWith('\')) {
                $dir = $lastWord.Substring(0, $lastWord.Length - 1)
                $file = $null    
            }
            else {
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
                }
                else {
                    Invoke-Fzf
                }
            }
            finally {
                Set-Location $prevPath
            }

}

function TabExpansion($line, $lastWord) {
    $lastBlock = [regex]::Split($line, '[|;]')[-1].TrimStart()

    if ([string]::IsNullOrWhiteSpace($env:FZF_COMPLETION_TRIGGER)) {
        $completionTrigger = '**'
    }
    else {
        $completionTrigger = $env:FZF_COMPLETION_TRIGGER
    }
    if ($lastWord.EndsWith($completionTrigger)) {
        if (Get-Command 'Expand-GitCommand' -ErrorAction SilentlyContinue) {
            $lastBlock = $lastBlock.Substring(0, $lastBlock.Length - 2)
            switch -regex ($lastBlock) {
                # Execute git tab completion for all git-related commands
                "^$(Get-AliasPattern git) (.*)" { Expand-GitWithFzf $lastBlock }
                "^$(Get-AliasPattern tgit) (.*)" { Expand-GitWithFzf $lastBlock }
                "^$(Get-AliasPattern gitk) (.*)" { Expand-GitWithFzf $lastBlock }
                "^$(Get-AliasPattern Remove-GitBranch) (.*)" { Expand-GitWithFzf $lastBlock }
    
                default { Expand-FileDirectoryPath $lastWord }
            }
        } else {
            Expand-FileDirectoryPath $lastWord
        }
    }
    else {
        # Fall back on existing tab expansion
        if (Test-Path Function:\TabExpansionBackupPSFzf) {
            TabExpansionBackupPSFzf $line $lastWord
        }
    }
}