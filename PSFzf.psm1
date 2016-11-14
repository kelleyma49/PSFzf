$script:IsWindows = Get-Variable IsWindows -Scope Global -ErrorAction SilentlyContinue
if ($script:IsWindows -eq $null -or $script:IsWindows.Value -eq $true) {	
	$script:IsWindows = $true	
	$script:DefaultFileSystemCmd = @"
dir /s/b "{0}"
"@ 
} else {
	$script:IsWindows = $false
	$script:DefaultFileSystemCmd = @"
find {0} -path '*/\.*' -prune -o -type f -print -o -type l -print 2> /dev/null | sed s/^..//
"@
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
            # Search
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

            # Interface
			[Alias('m')]
		  	[switch]$Multi,
			[switch]$NoMouse,
			[switch]$Cycle,
			[switch]$NoHScroll,

            # Layout
			[switch]$Reverse,
			[switch]$InlineInfo,
			[string]$Prompt,
			[string]$Header,
            [int]$HeaderLines = -1,

            # History
			[string]$History,
			[int]$HistorySize = -1,
			
            #Preview
            [string]$Preview,
            [string]$PreviewWindow,

            # Scripting
			[Alias('q')]
			[string]$Query,
			[Alias('1')]
			[switch]$Select1,
			[Alias('0')]
			[switch]$Exit0,
			[Alias('f')]
			[string]$Filter,
			
		  	[Parameter(ValueFromPipeline=$True)]
            [object[]]$Input,
            [switch]$ThrowException # work around for ReadlineHandler
    )

	Begin {
		# process parameters: 
		$arguments = ''
		if ($Extended) 										{ $arguments += '--extended '}
		if ($ExtendedExact) 								{ $arguments += '--extended-exact '}
		if ($CaseInsensitive) 								{ $arguments += '-i '}
		if ($CaseSensitive) 								{ $arguments += '+i '}
		if (![string]::IsNullOrWhiteSpace($Delimiter)) 		{ $arguments += "--delimiter=$Delimiter "}
		if ($NoSort) 										{ $arguments += '--no-sort '}
		if ($ReverseInput) 									{ $arguments += '--tac '}
		if (![string]::IsNullOrWhiteSpace($Tiebreak))		{ $arguments += "--tiebreak=$Tiebreak "}
		if ($Multi) 										{ $arguments += '--multi '}
		if ($NoMouse)					 					{ $arguments += '--no-mouse '}
		if ($Reverse)					 					{ $arguments += '--reverse '}
		if ($Cycle)						 					{ $arguments += '--cycle '}
		if ($NoHScroll) 									{ $arguments += '--no-hscroll '}
		if ($InlineInfo) 									{ $arguments += '--inline-info '}
		if (![string]::IsNullOrWhiteSpace($Prompt)) 		{ $arguments += "--prompt='$Prompt' "}
        if (![string]::IsNullOrWhiteSpace($Header)) 		{ $arguments += "--header=""$Header"" "}
        if ($HeaderLines -ge 0) 		               		{ $arguments += "--header-lines=$HeaderLines "}
		if ($History) 										{ $arguments += "--history='$History' "}
		if ($HistorySize -ge 1)								{ $arguments += "--history-size=$HistorySize "}
        if (![string]::IsNullOrWhiteSpace($Preview)) 	    { $arguments += "--preview=""$Preview"" "}
        if (![string]::IsNullOrWhiteSpace($PreviewWindow)) 	{ $arguments += "--preview-window=""$PreviewWindow"" "}
		if (![string]::IsNullOrWhiteSpace($Query))			{ $arguments += "--query=$Query "}
		if ($Select1)										{ $arguments += '--select-1 '}
		if ($Exit0)											{ $arguments += '--exit-0 '}
		if (![string]::IsNullOrWhiteSpace($Filter))			{ $arguments += "--filter=$Filter " }
	
        # Windows only - if running under ConEmu, use option:
        if ($script:IsWindows) {
            if ("$env:ConEmuHooks" -eq 'Enabled') {
                #$arguments += '-new_console:s50H '
            }
        }
        
		# prepare to start process:
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo.FileName = $script:FzfLocation
		$process.StartInfo.Arguments = $arguments
        $process.StartInfo.RedirectStandardInput = 1
        $process.StartInfo.RedirectStandardOutput = 1
        $process.StartInfo.UseShellExecute = 0
        
        # Creating string builders to store stdout:
        $stdOutStr = New-Object -TypeName System.Text.StringBuilder

        # Adding event handers for stdout:
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
        $hasInput = $PSBoundParameters.ContainsKey('Input')
        
        $loopProcess = [scriptblock] {
            param($item)

            # check some common parameter names:
            $str = $item.FullName
            if ($str -eq $null) {
                $str = $item.Name
                if ($str -eq $null) {
                    $str = $item.ToString()
                }
            }
            if ($str -ne $null) {
                $process.StandardInput.WriteLine($str) 
            }
        }

		try {
			# handle no piped input:
			if (!$hasInput) {
                # optimization for filesystem provider:
                if ($PWD.Provider.Name -eq 'FileSystem') {
                    cmd.exe /c ($script:DefaultFileSystemCmd -f $PWD.Path) | ForEach-Object { 
                        $process.StandardInput.WriteLine($_) 
                        if ($process.HasExited) {
                            break processExited
                        }
				    }
                }
                else {
                    Get-ChildItem . -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                        & $loopProcess -item $_ 
                        if ($process.HasExited) {
                            break processExited
                        }
				    }
                }
                 
			} else {
                foreach ($i in $Input) {
                    & $loopProcess -item $i
				}				
			}
			$process.StandardInput.Flush()
		} catch {
			# do nothing
		}

        # dummy loop:
        :processExited while ($false) {

        }

		# if process has exited, stop pipeline:
        if ($process.HasExited) {
			try {
           		$process.StandardInput.Close() | Out-Null
			} catch {
				# do nothing
			}
            Unregister-Event -SourceIdentifier $stdOutEvent.Name
            $stdOutStr.ToString().Split([System.Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
            if ($ThrowException) {
                throw "Exit"
            } else {
                break
            }
            
        }
	}

	End {
	    $process.StandardInput.Close() | Out-Null
        $process.WaitForExit() | Out-Null
        Unregister-Event -SourceIdentifier $stdOutEvent.Name | Out-Null
        $stdOutStr.ToString().Split([System.Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
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
		$currentPath = $PWD
	}
    
    $result = @()
    try 
    {
        if ([string]::IsNullOrWhiteSpace($currentPath)) {
            Invoke-Fzf -Multi -ThrowException | % { $result += $_ }
        } else {
            $resolvedPath = Resolve-Path $currentPath -ErrorAction SilentlyContinue
            $providerName = $null
            if ($resolvedPath -ne $null) {
                $providerName = $resolvedPath.Provider.Name 
            }
            switch ($providerName) {
                # Get-ChildItem is way too slow - we optimize for the FileSystem provider by 
                # using batch commands:
                'FileSystem'    { cmd.exe /c ($script:DefaultFileSystemCmd -f $resolvedPath.ProviderPath) | Invoke-Fzf -Multi -ThrowException | % { $result += $_ } }
                'Registry'      { Get-ChildItem $currentPath -Recurse -ErrorAction SilentlyContinue | Select Name -ExpandProperty Name | Invoke-Fzf -Multi -ThrowException | % { $result += $_ } }
                $null           { Get-ChildItem $currentPath -Recurse -ErrorAction SilentlyContinue | Select FullName -ExpandProperty FullName | Invoke-Fzf -Multi -ThrowException | % { $result += $_ } }
                Default         {}
            }
        }
    }
    catch 
    {
        # catch custom exception
    }
	
	if ($result -ne $null) {
		# quote strings if we need to:
		if ($result -is [system.array]) {
			for ($i = 0;$i -lt $result.Length;$i++) {
				if ($result[$i].Contains(" ") -or $result[$i].Contains("`t")) {
					$result[$i] = "'{0}'" -f $result[$i].Replace("`r`n","")
				} else {
                    $result[$i] = $result[$i].Replace("`r`n","")
                }
			}
		} else {
			if ($result.Contains(" ") -or $result.Contains("`t")) {
					$result = "'{0}'" -f $result.Replace("`r`n","")
			} else {
                $result = $result.Replace("`r`n","")
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
 
function SetPsReadlineShortcut()
{
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
}


function FindFzf()
{
	if ($script:IsWindows) {
		$AppNames = @('fzf-*-windows_*.exe','fzf.exe')
	} else {
		if ($IsOSX) {
			$AppNames = @('fzf-*-darwin_*','fzf')
		} elseif ($IsLinux) {
			$AppNames = @('fzf-*-linux_*','fzf')
		}
	}

    # find it in our path:
    $script:FzfLocation = $null
    $AppNames | ForEach-Object {
        if ($script:FzfLocation -eq $null) {
            $result = Get-Command $_ -ErrorAction SilentlyContinue
            $result | ForEach-Object {
                $script:FzfLocation = Resolve-Path $_.Source   
            }
        }
    }
    
    if ($script:FzfLocation -eq $null) {
        throw 'Failed to find fzf binary in PATH' 
    }
}

 
SetPsReadlineShortcut
FindFzf

@('PSFzf.Functions.ps1') | % {  Join-Path $PSScriptRoot $_ } | ForEach-Object {
	. $_
}

	
