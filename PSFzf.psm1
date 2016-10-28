$script:IsWindows = Get-Variable IsWindows -Scope Global -ErrorAction SilentlyContinue
if ($script:IsWindows -eq $null -or $script:IsWindows.Value -eq $true) {
	$script:AppName = 'fzf.exe'
	$script:IsWindows = $true
} else {
	$script:AppName = 'fzf'	
	$script:IsWindows = $false
}
$script:FzfLocation = $null
$script:PSReadlineHandlerChord = $null
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove =
{
	if ($script:PSReadlineHandlerChord -ne $null) {
		Remove-PSReadlineKeyHandler $script:PSReadlineHandlerChord
	}
}

function Invoke-Fzf {
	param( 
			[Alias("x")]
			[switch]$Extended,
			[Alias('e')]
		  	[switch]$ExtendedExact,
			[Alias('i')]
		  	[switch]$CaseInsensitive,
		  	[switch]$CaseSensitive,
		  	[Alias('d')]
		  	[string]$Delimiter,
		  	[switch]$NoSort,
			[Alias('tac')]
		  	[switch]$ReverseInput,
		  	[ValidateSet('length','begin','end','index')]
		  	[string]
		  	$Tiebreak = 'length',
			[Alias('m')]
		  	[switch]$Multi,
			#[switch]$Ansi,
			[switch]$NoMouse,
			#$Color,
			[switch]$Black,
			[switch]$Reverse,
			[switch]$Cycle,
			[switch]$NoHScroll,
			[switch]$InlineInfo,
			[string]$Prompt,
			#[string]$Bind,
			[string]$History,
			[int]$HistorySize = -1,
			
			[Alias('q')]
			[string]$Query,
			[Alias('1')]
			[switch]$Select1,
			[Alias('0')]
			[switch]$Exit0,
			[Alias('f')]
			[string]$Filter,
			
		  	[Parameter(ValueFromPipeline=$True)]
            [string[]]$Input
    )

	Begin {
		# process parameters: 
		$arguments = ''
		if ($Extended) 									{ $arguments += '--extended '}
		if ($ExtendedExact) 							{ $arguments += '--extended-exact '}
		if ($CaseInsensitive) 							{ $arguments += '-i '}
		if ($CaseSensitive) 							{ $arguments += '+i '}
		if (![string]::IsNullOrWhiteSpace($Delimiter)) 	{ $arguments += "--delimiter=$Delimiter "}
		if ($NoSort) 									{ $arguments += '--no-sort '}
		if ($ReverseInput) 								{ $arguments += '--tac '}
		if (![string]::IsNullOrWhiteSpace($Tiebreak))	{ $arguments += "--tiebreak=$Tiebreak "}
		if ($Multi) 									{ $arguments += '--multi '}
		if ($NoMouse)					 				{ $arguments += '--no-mouse '}
		if ($Black) 									{ $arguments += '--black '}
		if ($Reverse)					 				{ $arguments += '--reverse '}
		if ($Cycle)						 				{ $arguments += '--cycle '}
		if ($NoHScroll) 								{ $arguments += '--no-hscroll '}
		if ($InlineInfo) 								{ $arguments += '--inline-info '}
		if (![string]::IsNullOrWhiteSpace($Prompt)) 	{ $arguments += "--prompt='$Prompt' "}
		if ($History) 									{ $arguments += "--history='$History' "}
		if ($HistorySize -ge 1)							{ $arguments += "--history-size=$HistorySize "}
		if (![string]::IsNullOrWhiteSpace($Query))		{ $arguments += "--query=$Query "}
		if ($Select1)									{ $arguments += '--select-1 '}
		if ($Exit0)										{ $arguments += '--exit-0 '}
		if (![string]::IsNullOrWhiteSpace($Filter0))	{ $arguments += "--filter=$Filter " }
	
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo.FileName = $script:FzfLocation
		$process.StartInfo.Arguments = $arguments
        $process.StartInfo.RedirectStandardInput = 1
        $process.StartInfo.RedirectStandardOutput = 1
        $process.StartInfo.UseShellExecute = 0
        
        # Creating string builders to store stdout and stderr.
        $stdOutStr = New-Object -TypeName System.Text.StringBuilder

        # Adding event handers for stdout and stderr.
        $scripBlock = {
            if (! [String]::IsNullOrEmpty($EventArgs.Data)) {
                $Event.MessageData.AppendLine($EventArgs.Data)
            }
        }
        $stdOutEvent = Register-ObjectEvent -InputObject $process `
        -Action $scripBlock -EventName 'OutputDataReceived' `
        -MessageData $stdOutStr

        $process.Start() | Out-Null
        $process.BeginOutputReadLine() | Out-Null
	}

	Process {
		try {
			foreach ($i in $Input) {
				$process.StandardInput.WriteLine($i)
			}
			$process.StandardInput.Flush()
		} catch {
			# do nothing
		}
        if ($process.HasExited) {
            Unregister-Event -SourceIdentifier $stdOutEvent.Name
            $stdOutStr.ToString()
            break
        }
	}

	End {
	   $process.StandardInput.Close() | Out-Null
        $process.WaitForExit() | Out-Null
        Unregister-Event -SourceIdentifier $stdOutEvent.Name | Out-Null
        $stdOutStr.ToString()
	}
}

function Find-CurrentPath {
	param([string]$line,[int]$cursor,[ref]$leftCursor,[ref]$rightCursor)
	
	if ($line.Length -eq 0) {
		$leftCursor.Value = $rightCursor.Value = 0
		return $null
	}

	if ($cursor -ge $line.Length) {
		$leftCursorTmp = $cursor - 1
	} else {
		$leftCursorTmp = $cursor
	}
	:leftSearch for (;$leftCursorTmp -ge 0;$leftCursorTmp--) {
		if ([string]::IsNullOrWhiteSpace($line[$leftCursorTmp])) {
			if (($leftCursorTmp -lt $cursor) -and ($leftCursorTmp -lt $line.Length-1)) {
				$leftCursorTmpQuote = $leftCursorTmp - 1
				$leftCursorTmp = $leftCursorTmp + 1
			} else {
				$leftCursorTmpQuote = $leftCursorTmp
			}
			for (;$leftCursorTmpQuote -ge 0;$leftCursorTmpQuote--) {
				if (($line[$leftCursorTmpQuote] -eq '"') -and (($leftCursorTmpQuote -le 0) -or ($line[$leftCursorTmpQuote-1] -ne '"'))) {
					$leftCursorTmp = $leftCursorTmpQuote
					break leftSearch
				}
				elseif (($line[$leftCursorTmpQuote] -eq "'") -and (($leftCursorTmpQuote -le 0) -or ($line[$leftCursorTmpQuote-1] -ne "'"))) {
					$leftCursorTmp = $leftCursorTmpQuote
					break leftSearch
				}
			}
			break leftSearch
		}
	}
	:rightSearch for ($rightCursorTmp = $cursor;$rightCursorTmp -lt $line.Length;$rightCursorTmp++) {
		if ([string]::IsNullOrWhiteSpace($line[$rightCursorTmp])) {
			if ($rightCursorTmp -gt $cursor) {
				$rightCursorTmp = $rightCursorTmp - 1
			}
			for ($rightCursorTmpQuote = $rightCursorTmp+1;$rightCursorTmpQuote -lt $line.Length;$rightCursorTmpQuote++) {
				if (($line[$rightCursorTmpQuote] -eq '"') -and (($rightCursorTmpQuote -gt $line.Length) -or ($line[$rightCursorTmpQuote+1] -ne '"'))) {
					$rightCursorTmp = $rightCursorTmpQuote
					break rightSearch
				}
				elseif (($line[$rightCursorTmpQuote] -eq "'") -and (($rightCursorTmpQuote -gt $line.Length) -or ($line[$rightCursorTmpQuote+1] -ne "'"))) {
					$rightCursorTmp = $rightCursorTmpQuote
					break rightSearch
				}
			}
			break rightSearch
		}
	}
	if ($leftCursorTmp -lt 0 -or $leftCursorTmp -gt $line.Length-1) { $leftCursorTmp = 0}
	if ($rightCursorTmp -ge $line.Length) { $rightCursorTmp = $line.Length-1 }
	$leftCursor.Value = $leftCursorTmp
	$rightCursor.Value = $rightCursorTmp
	$str = -join ($line[$leftCursorTmp..$rightCursorTmp])
	return $str.Trim("'").Trim('"')
}

function Invoke-FzfPsReadlineHandler {
	$leftCursor = $null
	$rightCursor = $null
	$line = $null
	$cursor = $null
	[Microsoft.PowerShell.PSConsoleReadline]::GetBufferState([ref]$line, [ref]$cursor)
	$currentPath = Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor)
	$addSpace = $currentPath -ne $null -and $currentPath.StartsWith(" ")
	if ([String]::IsNullOrWhitespace($currentPath) -or !(Test-Path $currentPath)) {
		$currentPath = $null
	}
	$result = Invoke-Fzf $currentPath
	if ($result -ne $null) {

		# quote strings if we need to:
		if ($result -is [system.array]) {
			for ($i = 0;$i -lt $result.Length;$i++) {
				if ($result[$i].Contains(" ") -or $result[$i].Contains("`t")) {
					$result[$i] = "'{0}'" -f $result[$i]
				}
			}
		} else {
			if ($result.Contains(" ") -or $result.Contains("`t")) {
					$result = "'{0}'" -f $result
			}
		}
		
		$str = $result -join ','
		if ($addSpace) {
			$str = ' ' + $str
		}
		$replaceLen = $rightCursor - $leftCursor
		if ($rightCursor -eq 0 -and $leftCursor -eq 0) {
			[Microsoft.PowerShell.PSConsoleReadLine]::Insert($str)
		} else {
			[Microsoft.PowerShell.PSConsoleReadLine]::Replace($leftCursor,$replaceLen+1,$str)
		}		
	}
}
 
# install PSReadline shortcut:
if (Get-Module -ListAvailable -Name PSReadline) {
	if ($args.Length -ge 1) {
		$script:PSReadlineHandlerChord = $args[0] 
	} else {
		$script:PSReadlineHandlerChord = 'Ctrl+T'
	}
	if (Get-PSReadlineKeyHandler -Bound | Where Key -eq $script:PSReadlineHandlerChord) {
		Write-Warning ("PSReadline chord {0} already in use - keyboard handler not installed" -f $script:PSReadlineHandlerChord)
	} else {
		Set-PSReadlineKeyHandler -Key Ctrl+T -BriefDescription "Invoke Fzf" -ScriptBlock  {
			Invoke-FzfPsReadlineHandler
		}
	} 
} else {
	Write-Warning "PSReadline module not found - keyboard handler not installed" 
}


# find location of fzf executable: 
$script:FzfLocation = Get-Command $script:AppName
if ($script:FzfLocation -ne $null) {
    $script:FzfLocation = $script:FzfLocation.Source
} else {
    if ([string]::IsNullOrWhiteSpace($env:GOPATH)) {
	    throw 'environment variable GOPATH not set'
    }
    $script:FzfLocation = Join-Path $env:GOPATH (Join-Path 'bin' $script:AppName) 
}
if ($script:FzfLocation -eq $null) {
    throw "Failed to find '{0}' in path" -f $script:AppName 
}
 

	
