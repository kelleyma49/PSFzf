# check if we're running on Windows PowerShell. This method is faster than Get-Command:
if ($(get-host).Version.Major -le 5) {
    $script:PowershellCmd = 'powershell'
} else {
    $script:PowershellCmd = 'pwsh'
}

# borrowed from https://github.com/dahlbyk/posh-git/blob/f69efd9229029519adb32e37a464b7e1533a372c/src/GitTabExpansion.ps1#L81
filter script:quoteStringWithSpecialChars {
    if ($_ -and ($_ -match '\s+|#|@|\$|;|,|''|\{|\}|\(|\)')) {
        $str = $_ -replace "'", "''"
        "'$str'"
    }
    else {
        $_
    }
}

# taken from https://github.com/dahlbyk/posh-git/blob/2ad946347e7342199fd4bb1b42738833f68721cd/src/GitUtils.ps1#L407
function script:Get-AliasPattern($cmd) {
    $aliases = @($cmd) + @(Get-Alias | Where-Object { $_.Definition -eq $cmd } | Select-Object -Exp Name)
   "($($aliases -join '|'))"
}

function Expand-GitWithFzf($lastBlock) {
    $gitResults = Expand-GitCommand $lastBlock
    # if no results, invoke filesystem completion:
    if ($null -eq $gitResults) {
        $results = Invoke-Fzf -Multi | script:quoteStringWithSpecialChars
    } else {
        $results = $gitResults | Invoke-Fzf -Multi | script:quoteStringWithSpecialChars
    }

    if ($results.Count -gt 1) {
        $results -join ' '
    } else {
        if (-not $null -eq $results) {
            $results
        } else {
            '' # output something to prevent default tab expansion
        }
    }

    InvokePromptHack
}

function Expand-FileDirectoryPath($lastWord) {
    # find dir and file pattern connected to the trigger:
    $lastWord = $lastWord.Substring(0, $lastWord.Length - 2)
    if ($lastWord.EndsWith('\')) {
        $dir = $lastWord.Substring(0, $lastWord.Length - 1)
        $file = $null    
    } elseif (-not [string]::IsNullOrWhiteSpace($lastWord)) {
        $dir = Split-Path $lastWord -Parent
        $file = Split-Path $lastWord -Leaf    
    }
    if (-not [System.IO.Path]::IsPathRooted($dir)) {
        $dir = Join-Path $PWD.ProviderPath $dir
    }
    $prevPath = $Pwd.ProviderPath
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

    InvokePromptHack
}

$script:TabExpansionEnabled = $false
function SetTabExpansion($enable)
{
    if ($enable) {
        if (-not $script:TabExpansionEnabled) {
                $script:TabExpansionEnabled = $true

                RegisterBuiltinCompleters

                Register-ArgumentCompleter -CommandName git,tgit,gitk -Native -ScriptBlock {
                    param($wordToComplete, $commandAst, $cursorPosition)
                
                    # The PowerShell completion has a habit of stripping the trailing space when completing:
                    # git checkout <tab>
                    # The Expand-GitCommand expects this trailing space, so pad with a space if necessary.
                    $padLength = $cursorPosition - $commandAst.Extent.StartOffset
                    $textToComplete = $commandAst.ToString().PadRight($padLength, ' ').Substring(0, $padLength)
                
                    Expand-GitCommandPsFzf $textToComplete
                }
                
        }
    } else {
        if ($script:TabExpansionEnabled) {
            $script:TabExpansionEnabled = $false
        }
    }   
}

function CheckFzfTrigger {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $cursorPosition,$action)
    if ([string]::IsNullOrWhiteSpace($env:FZF_COMPLETION_TRIGGER)) {
        $completionTrigger = '**'
    } else {
        $completionTrigger = $env:FZF_COMPLETION_TRIGGER
    }
    if ($wordToComplete.EndsWith($completionTrigger)) {
        $wordToComplete = $wordToComplete.Substring(0, $wordToComplete.Length - $completionTrigger.Length)
        $wordToComplete
    }
}


function GetServiceSelection() {
    param(
        [scriptblock]
        $ResultAction
    )
    $header = [System.Environment]::NewLine + $("{0,-24} NAME" -f "DISPLAYNAME") + [System.Environment]::NewLine
    $result = Get-Service | Where-Object { ![string]::IsNullOrEmpty($_.Name) } | ForEach-Object { 
        "{0,-24} {1}" -f $_.DisplayName.Substring(0,[System.Math]::Min(24,$_.DisplayName.Length)),$_.Name } | Invoke-Fzf -Multi -Header $header
    $result | ForEach-Object {
        &$ResultAction $_
    }
}

function RegisterBuiltinCompleters {
    $processIdOrNameScriptBlock = {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $cursorPosition, $action)
        $wordToComplete = CheckFzfTrigger $commandName $parameterName $wordToComplete $commandAst $cursorPosition
        if ($null -ne $wordToComplete)
        {
            if ($parameterName -eq 'Name') {
                $group = '$2'
            } elseif ($parameterName -eq 'Id') {
                $group = '$1'
            }

            $script:resultArr = @()
            GetProcessSelection -ResultAction {
                param($result) 
                $script:resultArr += $result -replace "([0-9]+)\s*(.*)",$group
            }

            if ($script:resultArr.Length -ge 1) {
                $script:resultArr -join ', '
            }
            
            InvokePromptHack
        } else {
            # don't return anything - let normal tab completion work
        }
    }

    'Get-Process','Stop-Process' | ForEach-Object {
        Register-ArgumentCompleter -CommandName $_ -ParameterName "Name" -ScriptBlock $processIdOrNameScriptBlock
        Register-ArgumentCompleter -CommandName $_ -ParameterName "Id" -ScriptBlock $processIdOrNameScriptBlock            
    }

    $serviceNameScriptBlock = {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $cursorPosition,$action)
        $wordToComplete = CheckFzfTrigger $commandName $parameterName $wordToComplete $commandAst $cursorPosition
        if ($null -ne $wordToComplete)
        {
            if ($parameterName -eq 'Name') {
                $group = '$2'
            } elseif ($parameterName -eq 'DisplayName') {
                $group = '$1'
            }

            $script:resultArr = @()
            GetServiceSelection -ResultAction {
                param($result) 
                $script:resultArr += $result.Substring(24+1)
            }

            if ($script:resultArr.Length -ge 1) {
                $script:resultArr -join ', '
            }
            InvokePromptHack
        } else {
            # don't return anything - let normal tab completion work
        }
    }

    'Get-Service','Start-Service','Stop-Service' | ForEach-Object {
        Register-ArgumentCompleter -CommandName $_ -ParameterName "Name" -ScriptBlock $serviceNameScriptBlock
        Register-ArgumentCompleter -CommandName $_ -ParameterName "DisplayName" -ScriptBlock $serviceNameScriptBlock            
    }
}


function Expand-GitCommandPsFzf($lastWord) {
    if ([string]::IsNullOrWhiteSpace($env:FZF_COMPLETION_TRIGGER)) {
        $completionTrigger = '**'
    }
    else {
        $completionTrigger = $env:FZF_COMPLETION_TRIGGER
    }
    if ($lastWord.EndsWith($completionTrigger)) {
            $lastWord = $lastWord.Substring(0, $lastWord.Length - $completionTrigger.Length)
            Expand-GitWithFzf $lastWord
    } else {
        Expand-GitCommand $lastWord
    }
}


function Invoke-FzfTabCompletion()
{
	$script:continueCompletion = $true
	do 
	{
		$script:continueCompletion = script:Invoke-FzfTabCompletionInner
	}
	while ($script:continueCompletion)
}
function script:Invoke-FzfTabCompletionInner()
{
	$script:result = @()

	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Management.Automation") 
	$line = $null
	$cursor = $null
	[Microsoft.PowerShell.PSConsoleReadline]::GetBufferState([ref]$line, [ref]$cursor)

	if ($cursor -lt 0 -or [string]::IsNullOrWhiteSpace($line)) { 
		return $false
	}
	$completions = [System.Management.Automation.CommandCompletion]::CompleteInput($line, $cursor, @{})
    
    $completionMatches = $completions.CompletionMatches 
	if ($completionMatches.Count -le 0) {
		return $false
	}
	$script:continueCompletion = $false

    $addSpace = $null -ne $currentPath -and $currentPath.StartsWith(" ")

	if ($completionMatches.Count -eq 1) {		        
        $script:result = $completionMatches[0].CompletionText
	} elseif ($completionMatches.Count -gt 1) {
		$helpers = New-Object PSFzf.IO.CompletionHelpers
		$ambiguous = $false
        $addSpace  = $false
		$prefix = $helpers.GetUnambiguousPrefix($completionMatches,[ref]$ambiguous)
		
		$script:result = @()
		$script:checkCompletion = $true
		$expectTrigger = $script:TabContinuousTrigger
		# need to escape the key if it's a forward slash:
		if ($expectTrigger -eq '\') {
			$expectTrigger += $expectTrigger 
        }

        # normalize so path works correctly for Windows:
        $path = $PWD.ProviderPath.Replace('\','/')
        
        $previewScript = $(Join-Path $PsScriptRoot 'helpers/PsFzfTabExpansion-Preview.ps1')
        $additionalCmd = @{ Preview=$($script:PowershellCmd + " -NoProfile -NonInteractive -File \""$previewScript\"" \""" + $path + "\"" {}") } 

        $script:fzfOutput = @()
        $completionMatches | ForEach-Object { $_.CompletionText } | Invoke-Fzf `
            -Layout reverse `
            -Expect $expectTrigger `
            -Query "$prefix" `
            -PrintQuery `
            -Bind 'tab:down,btab:up' `
            @additionalCmd | ForEach-Object {
                if ($null -eq $_) {
                    $script:fzfOutput += ""
                } else {
                    $script:fzfOutput += $_
                }
            }

        # check if there's a selection:
        if ($script:fzfOutput.Length -gt 2) {
            $script:result = $script:fzfOutput[2..($script:fzfOutput.Length-1)]
        }
        # or just complete with the query string: 
        else {
            $script:result = $script:fzfOutput[0]
        }    

        # check if we should continue completion:
        $script:continueCompletion = $script:fzfOutput[1] -eq $script:TabContinuousTrigger
    
		InvokePromptHack
	}	

	$result = $script:result
	if ($null -ne $result) {
		# quote strings if we need to:
		if ($result -is [system.array]) {
			for ($i = 0;$i -lt $result.Length;$i++) {
				$result[$i] = FixCompletionResult $result[$i]
			}
			$str = $result -join ','
		} else {
			$str = FixCompletionResult $result
		}
		
		if ($script:continueCompletion) {
            $isQuoted = $str.EndsWith("'")
            $resultTrimmed = $str.Trim(@('''','"')) 
			if (Test-Path "$resultTrimmed"  -PathType Container) {
                if ($isQuoted) {
                    $str = "'{0}{1}'" -f "$resultTrimmed",$script:TabContinuousTrigger
                } else {
                    $str = "$resultTrimmed" + $script:TabContinuousTrigger
                }
			} else {
                # no more paths to complete, so let's stop completion:
				$str += ' ' 
				$script:continueCompletion = $false
			}
		}

		if ($addSpace) {
			$str = ' ' + $str
		}
    
        $leftCursor = $completions.ReplacementIndex
        $replacementLength = $completions.ReplacementLength
		if ($leftCursor -le 0 -and $replacementLength -le 0) {
			[Microsoft.PowerShell.PSConsoleReadLine]::Insert($str)
		} else {
			[Microsoft.PowerShell.PSConsoleReadLine]::Replace($leftCursor,$replacementLength,$str)
		}
		
	}

	return $script:continueCompletion
}
