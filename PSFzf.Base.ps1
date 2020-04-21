param(
	[parameter(Position=0,Mandatory=$false)][string]$PSReadlineChordProvider = 'Ctrl+t',
	[parameter(Position=1,Mandatory=$false)][string]$PSReadlineChordReverseHistory = 'Ctrl+r',
	[parameter(Position=2,Mandatory=$false)][string]$PSReadlineChordSetLocation = 'Alt+c',
	[parameter(Position=3,Mandatory=$false)][string]$PSReadlineChordReverseHistoryArgs = 'Alt+a')

$script:IsWindows = ($PSVersionTable.PSVersion.Major -le 5) -or $IsWindows
if ($script:IsWindows) {	
	$script:ShellCmd = 'cmd.exe /S /C {0}'	
	$script:DefaultFileSystemCmd = @"
dir /s/b "{0}"
"@ 
} else {
	$script:ShellCmd = '/bin/sh -c "{0}"'
	$script:DefaultFileSystemCmd = @"
find {0} -path '*/\.*' -prune -o -type f -print -o -type l -print 2> /dev/null
"@
}

function Get-FileSystemCmd
{
	if ([string]::IsNullOrWhiteSpace($env:FZF_DEFAULT_COMMAND)) {
		$script:DefaultFileSystemCmd
	} else {
		$env:FZF_DEFAULT_COMMAND
	}
}

$script:RunningInWindowsTerminal = [bool]($env:WT_Session)
$script:FzfLocation = $null
$script:PSReadlineHandlerChords = @()
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove =
{
	$PsReadlineShortcuts.Values | Where-Object Chord | ForEach-Object { 
		Remove-PSReadlineKeyHandler $_.Chord
	}
	RemovePsFzfAliases

	RemoveGitKeyBindings
}

function Set-PsFzfOption{
	param(
		[switch]
		$TabExpansion,
		[string]
		$PSReadlineChordProvider,
		[string]
		$PSReadlineChordReverseHistory,
		[string]
		$PSReadlineChordSetLocation,
		[string]
		$PSReadlineChordReverseHistoryArgs,
		[switch]
		$GitKeyBindings,
		[switch]
		$EnableAliasFuzzyEdit,
		[switch]
		$EnableAliasFuzzyFasd,
		[switch]
		$EnableAliasFuzzyHistory,
		[switch]
		$EnableAliasFuzzyKillProcess,
		[switch]
		$EnableAliasFuzzySetLocation,
		[switch]
		$EnableAliasFuzzySetEverything,
		[switch]
		$EnableAliasFuzzyZLocation,
		[switch]
		$EnableAliasFuzzyGitStatus
	)
	if ($PSBoundParameters.ContainsKey('TabExpansion')) {
		SetTabExpansion $TabExpansion
	}

	if ($PSBoundParameters.ContainsKey('GitKeyBindings')) {
		SetGitKeyBindings $GitKeyBindings
	}

	$PsReadlineShortcuts.GetEnumerator() | ForEach-Object {
		if ($PSBoundParameters.ContainsKey($_.key)) {
			$info = $_.value
			$newChord = $PSBoundParameters[$_.key]
			$result = SetPsReadlineShortcut $newChord -Override $info.BriefDesc $info.Desc $info.ScriptBlock
			if ($result) {
				if (($null -ne $info.Chord) -and ($info.Chord.ToLower() -ne $newChord.ToLower())) {
					Remove-PSReadLineKeyHandler $info.Chord
				}
				$info.Chord = $newChord
			}
		}	
	}

	if ($EnableAliasFuzzyEdit) 			{ SetPsFzfAlias "fe"      Invoke-FuzzyEdit}
	if ($EnableAliasFuzzyFasd) 			{ SetPsFzfAlias "ff"      Invoke-FuzzyFasd}
	if ($EnableAliasFuzzyHistory) 		{ SetPsFzfAlias "fh"      Invoke-FuzzyHistory }
	if ($EnableAliasFuzzyKillProcess) 	{ SetPsFzfAlias "fkill"   Invoke-FuzzyKillProcess }
	if ($EnableAliasFuzzySetLocation) 	{ SetPsFzfAlias "fd"      Invoke-FuzzySetLocation }
	if ($EnableAliasFuzzyZLocation) 	{ SetPsFzfAlias "fz"      Invoke-FuzzyZLocation }
	if ($EnableAliasFuzzyGitStatus) 	{ SetPsFzfAlias "fgs"     Invoke-FuzzyGitStatus }
	if ($EnableAliasFuzzySetEverything) {
        if (${function:Set-LocationFuzzyEverything}) {
            SetPsFzfAlias "cde" Set-LocationFuzzyEverything 
        }
	}
}

function Invoke-Fzf {
	param( 
            # Search
			[Alias("x")]
			[switch]$Extended,
			[Alias('e')]
		  	[switch]$Exact,
			[Alias('i')]
		  	[switch]$CaseInsensitive,
		  	[switch]$CaseSensitive,
		  	[Alias('d')]
		  	[string]$Delimiter,
		  	[switch]$NoSort,
			[Alias('tac')]
			[switch]$ReverseInput,
			[switch]$Phony,
		  	[ValidateSet('length','begin','end','index')]
		  	[string]
		  	$Tiebreak = 'length',

            # Interface
			[Alias('m')]
		  	[switch]$Multi,
			[switch]$NoMouse,
            [string]$Bind,
			[switch]$Cycle,
			[switch]$KeepRight,
			[switch]$NoHScroll,
			[switch]$FilepathWord,

			# Layout
			[ValidatePattern("^[1-9]+[0-9]+$|^[1-9][0-9]?%?$|^100%?$")]
			[string]$Height,
			[ValidateRange(1,[int]::MaxValue)]
			[int]$MinHeight,
			[ValidateSet('default','reverse','reverse-list')]
			[string]$Layout = 'default',
			[switch]$Border,
			[ValidateSet('rounded','sharp','horizontal')]
			[string]$BorderStyle,
			[ValidateSet('default','inline','hidden')]
			[string]$Info = 'default',
			[string]$Prompt,
			[string]$Pointer,
			[string]$Marker,
			[string]$Header,
			[int]$HeaderLines = -1,

			# Display
			[switch]$Ansi,
			[int]$Tabstop = 8,
			[switch]$NoBold,

            # History
			[string]$History,
			[int]$HistorySize = -1,
			
            #Preview
            [string]$Preview,
			[string]$PreviewWindow,

            # Scripting
			[Alias('q')]
			[string]$Query,
			[Alias('s1')]
			[switch]$Select1,
			[Alias('e0')]
			[switch]$Exit0,
			[Alias('f')]
			[string]$Filter,
			[string]$Expect,
			
		  	[Parameter(ValueFromPipeline=$True)]
            [object[]]$Input
    )

	Begin {
		# process parameters: 
		$arguments = ''
		if ($Extended) 										{ $arguments += '--extended '}
		if ($Exact) 			        					{ $arguments += '--exact '}
		if ($CaseInsensitive) 								{ $arguments += '-i '}
		if ($CaseSensitive) 								{ $arguments += '+i '}
		if (![string]::IsNullOrWhiteSpace($Delimiter)) 		{ $arguments += "--delimiter=$Delimiter "}
		if ($NoSort) 										{ $arguments += '--no-sort '}
		if ($ReverseInput) 									{ $arguments += '--tac '}
		if ($Phony)											{ $arguments += '--phony '}
		if (![string]::IsNullOrWhiteSpace($Tiebreak))		{ $arguments += "--tiebreak=$Tiebreak "}
		if ($Multi) 										{ $arguments += '--multi '}
		if ($NoMouse)					 					{ $arguments += '--no-mouse '}
        if (![string]::IsNullOrWhiteSpace($Bind))		    { $arguments += "--bind=$Bind "}
		if ($Reverse)					 					{ $arguments += '--reverse '}
		if ($Cycle)						 					{ $arguments += '--cycle '}
		if ($KeepRight)						 				{ $arguments += '--keep-right '}
		if ($NoHScroll) 									{ $arguments += '--no-hscroll '}
		if ($FilepathWord)									{ $arguments += '--filepath-word '}
		if (![string]::IsNullOrWhiteSpace($Height))			{ $arguments += "--height=$height "}
		if ($MinHeight -ge 0)								{ $arguments += "--min-height=$MinHeight "}
		if (![string]::IsNullOrWhiteSpace($Layout))			{ $arguments += "--layout=$Layout "}
		if ($Border)										{ $arguments += '--border '}
		if (![string]::IsNullOrWhiteSpace($BorderStyle))	{ $arguments += "--border=$BorderStyle "}
		if (![string]::IsNullOrWhiteSpace($Info)) 			{ $arguments += "--info=$Info "}
		if (![string]::IsNullOrWhiteSpace($Prompt)) 		{ $arguments += "--prompt='$Prompt' "}
		if (![string]::IsNullOrWhiteSpace($Pointer)) 		{ $arguments += "--pointer='$Pointer' "}
		if (![string]::IsNullOrWhiteSpace($Marker)) 		{ $arguments += "--marker='$Marker' "}
        if (![string]::IsNullOrWhiteSpace($Header)) 		{ $arguments += "--header=""$Header"" "}
		if ($HeaderLines -ge 0) 		               		{ $arguments += "--header-lines=$HeaderLines "}
		if ($Ansi)											{ $arguments += '--ansi '}
		if ($Tabstop -ge 0)									{ $arguments += "--tabstop=$Tabstop "}
		if ($NoBold)										{ $arguments += '--no-bold '}
		if ($History) 										{ $arguments += "--history='$History' "}
		if ($HistorySize -ge 1)								{ $arguments += "--history-size=$HistorySize "}
        if (![string]::IsNullOrWhiteSpace($Preview)) 	    { $arguments += "--preview=""$Preview"" "}
        if (![string]::IsNullOrWhiteSpace($PreviewWindow)) 	{ $arguments += "--preview-window=""$PreviewWindow"" "}
		if (![string]::IsNullOrWhiteSpace($Query))			{ $arguments += "--query=$Query "}
		if ($Select1)										{ $arguments += '--select-1 '}
		if ($Exit0)											{ $arguments += '--exit-0 '}
		if (![string]::IsNullOrEmpty($Filter))				{ $arguments += "--filter=$Filter " }
		if (![string]::IsNullOrWhiteSpace($Expect)) 	    { $arguments += "--expect=""$Expect"" "}
	 
		if ($script:UseHeightOption -and [string]::IsNullOrWhiteSpace($Height)) {
			$arguments += "--height=40% "
		}
		
		if ($Border -eq $true -and -not [string]::IsNullOrWhiteSpace($BorderStyle)) {
			throw '-Border and -BorderStyle are mutally exclusive'
		}

		$fileSystemCmd = Get-FileSystemCmd
		  
		# prepare to start process:
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo.FileName = $script:FzfLocation
		$process.StartInfo.Arguments = $arguments
        $process.StartInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $process.StartInfo.RedirectStandardInput = $true
        $process.StartInfo.RedirectStandardOutput = $true
		$process.StartInfo.UseShellExecute = $false
		$process.StartInfo.WorkingDirectory = $pwd.Path 
        
        # Creating string builders to store stdout:
        $stdOutStr = New-Object -TypeName System.Text.StringBuilder

        # Adding event handers for stdout:
        $scriptBlockRecv = {
            if (! [String]::IsNullOrEmpty($EventArgs.Data)) {
                $Event.MessageData.AppendLine($EventArgs.Data)
            }
        }
		$stdOutEventId = "PsFzfStdOutEh-" + [System.Guid]::NewGuid()
        $stdOutEvent = Register-ObjectEvent -InputObject $process `
        -Action $scriptBlockRecv -EventName 'OutputDataReceived' `
		-SourceIdentifier $stdOutEventId `
        -MessageData $stdOutStr

        $processHasExited = new-object psobject -property @{flag = $false}
        # register on exit:
        $scriptBlockExited = {
            $Event.MessageData.flag = $true
        }
        $exitedEventId = "PsFzfExitedEh-" + [System.Guid]::NewGuid()
        $exitedEvent = Register-ObjectEvent -InputObject $process `
        -Action $scriptBlockExited -EventName 'Exited' `
		-SourceIdentifier $exitedEventId `
        -MessageData $processHasExited

        $process.Start() | Out-Null
        $process.BeginOutputReadLine() | Out-Null

		$cleanup = [scriptblock] {
			try {
           		$process.StandardInput.Close() | Out-Null
				$process.WaitForExit()
			} catch {
				# do nothing
			}

			$stdOutEventId,$exitedEventId | ForEach-Object {
				Unregister-Event $_
				Stop-Job $_
				Remove-Job $_ -Force
			}
            $stdOutStr.ToString().Split([System.Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
				Write-Output $_
			}			
		}
	}

	Process {
		$brokePipeline = $false
        $hasInput = $PSBoundParameters.ContainsKey('Input')
        $utf8Encoding = New-Object System.Text.UTF8Encoding -ArgumentList $false
        $utf8Stream = New-Object System.IO.StreamWriter -ArgumentList $process.StandardInput.BaseStream, $utf8Encoding
        
        try {
			# handle no piped input:
			if (!$hasInput) {
                # optimization for filesystem provider:
                if ($PWD.Provider.Name -eq 'FileSystem') {
					$cmd = $script:ShellCmd -f ($fileSystemCmd -f $PWD.Path)
					Invoke-Expression $cmd | ForEach-Object { 
                        $utf8Stream.WriteLine($_)
                        if ($processHasExited.flag) {
                            throw "breaking inner pipeline"
                        }
				    }
                }
                else {
                    Get-ChildItem . -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                        $item = $_ 
                        if ($item -is [System.String]) {
                            $str = $item
                        } else {
                            # search through common properties:
                            $str = $item.FullName
                            if ($null -eq $str) {
                                $str = $item.Name
                                if ($null -eq $str) {
                                    $str = $item.ToString()
                                }
                            }
                        }
                        if (![System.String]::IsNullOrWhiteSpace($str)) {
                            $utf8Stream.WriteLine($str)
                        }

                        if ($processHasExited.flag) {
                            throw "breaking inner pipeline"
                        }
				    }
                }
                 
			} else {
                foreach ($item in $Input) {
                    if ($item -is [System.String]) {
				    $str = $item
                    } else {
                        # search through common properties:
                        $str = $item.FullName
                        if ($null -eq $str) {
                            $str = $item.Name
                            if ($null -eq $str) {
                                $str = $item.ToString()
                            }
                        }
                    }
                    if (![System.String]::IsNullOrWhiteSpace($str)) {
                        $utf8Stream.WriteLine($str)
                    }
                    if ($processHasExited.flag) {
                        throw "breaking inner pipeline"
					}
				}
			}
			$utf8Stream.Flush()
		} catch {
			# do nothing
			$brokePipeline = $true
		}

		if ($brokePipeline) {
			& $cleanup
			throw "Stopped fzf pipeline input"
		}
	}

	End {
		& $cleanup
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

function Invoke-FzfPsReadlineHandlerProvider {
	$leftCursor = $null
	$rightCursor = $null
	$line = $null
	$cursor = $null
	[Microsoft.PowerShell.PSConsoleReadline]::GetBufferState([ref]$line, [ref]$cursor)
	$currentPath = Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor)
	$addSpace = $null -ne $currentPath -and $currentPath.StartsWith(" ")
	if ([String]::IsNullOrWhitespace($currentPath) -or !(Test-Path $currentPath)) {
		$currentPath = $PWD
	}

	$fileSystemCmd = Get-FileSystemCmd

    $result = @()
    try 
    {
        if (-not [System.String]::IsNullOrWhiteSpace($env:FZF_CTRL_T_COMMAND)) {
			Invoke-Expression ($env:FZF_CTRL_T_COMMAND) | Invoke-Fzf -Multi | ForEach-Object { $result += $_ }
		} else {
			if ([string]::IsNullOrWhiteSpace($currentPath)) {
				Invoke-Fzf -Multi | ForEach-Object { $result += $_ }
			} else {
				$resolvedPath = Resolve-Path $currentPath -ErrorAction SilentlyContinue
				$providerName = $null
				if ($null -ne $resolvedPath) {
					$providerName = $resolvedPath.Provider.Name 
				}
				switch ($providerName) {
					# Get-ChildItem is way too slow - we optimize for the FileSystem provider by 
					# using batch commands:
					'FileSystem'    { Invoke-Expression ($script:ShellCmd -f ($fileSystemCmd -f $resolvedPath.ProviderPath)) | Invoke-Fzf -Multi | ForEach-Object { $result += $_ } }
					'Registry'      { Get-ChildItem $currentPath -Recurse -ErrorAction SilentlyContinue | Select-Object Name -ExpandProperty Name | Invoke-Fzf -Multi | ForEach-Object { $result += $_ } }
					$null           { Get-ChildItem $currentPath -Recurse -ErrorAction SilentlyContinue | Select-Object FullName -ExpandProperty FullName | Invoke-Fzf -Multi | ForEach-Object { $result += $_ } }
					Default         {}
				}
			}
		}
    }
    catch 
    {
        # catch custom exception
    }
	
	#HACK: workaround for fact that PSReadLine seems to clear screen 
	# after keyboard shortcut action is executed:
	[Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()

	if ($null -ne $result) {
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
function Invoke-FzfPsReadlineHandlerHistory {
	$result = $null
	try
	{
		$reader = New-Object PSFzf.IO.ReverseLineReader -ArgumentList $((Get-PSReadlineOption).HistorySavePath)

		$fileHist = @{}
		$reader.GetEnumerator() | ForEach-Object {
			if (-not $fileHist.ContainsKey($_)) {
				$fileHist.Add($_,$true)
				$_
			}
		} | Invoke-Fzf -NoSort -Bind ctrl-r:toggle-sort | ForEach-Object { $result = $_ }
	}
	catch
	{
		# catch custom exception
	}
	finally 
	{
		# ensure that stream is closed:
		$reader.Dispose()
	}

	#HACK: workaround for fact that PSReadLine seems to clear screen 
	# after keyboard shortcut action is executed:
	[Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()

	if (-not [string]::IsNullOrEmpty($result)) {
		[Microsoft.PowerShell.PSConsoleReadLine]::Insert($result)
	}
}

function Invoke-FzfPsReadlineHandlerHistoryArgs {	
	try 
    {
		$line = $null
		$cursor = $null
		[Microsoft.PowerShell.PSConsoleReadline]::GetBufferState([ref]$line, [ref]$cursor)
		$line = $line.Insert($cursor,"{}") # add marker for fzf
        
        $contentTable = @{}
		$reader = New-Object PSFzf.IO.ReverseLineReader -ArgumentList $((Get-PSReadlineOption).HistorySavePath)
		
		$fileHist = @{}
		$reader.GetEnumerator() | ForEach-Object {
			if (-not $fileHist.ContainsKey($_)) {
				$fileHist.Add($_,$true)
				[System.Management.Automation.PsParser]::Tokenize($_, [ref] $null) 
			}  
		} | Where-Object {$_.type -eq "commandargument" -or $_.type -eq "string"} | 
				ForEach-Object { 
					if (!$contentTable.ContainsKey($_.Content)) { $_.Content ; $contentTable[$_.Content] = $true } 
				} | Invoke-Fzf -NoSort -Preview "echo $line" -PreviewWindow "up:20%" | ForEach-Object { $result = $_ }
	}
	catch 
	{
		# catch custom exception
	}
	finally
	{
		$reader.Dispose()
	}
	
	#HACK: workaround for fact that PSReadLine seems to clear screen 
	# after keyboard shortcut action is executed:
	[Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()

	if (-not [string]::IsNullOrEmpty($result)) {
		# add quotes:
		if ($result.Contains(" ") -or $result.Contains("`t")) {
			$result = "'{0}'" -f $result.Replace("'","''")
		}
		[Microsoft.PowerShell.PSConsoleReadLine]::Replace($cursor,0,$result)
	}
}

function Invoke-FzfPsReadlineHandlerSetLocation {
    $result = $null
	try 
    {
		if ($null -eq $env:FZF_ALT_C_COMMAND) {
			Get-ChildItem . -Recurse -ErrorAction SilentlyContinue -Directory | Invoke-Fzf | ForEach-Object { $result = $_ }
		} else {
			Invoke-Expression ($env:FZF_ALT_C_COMMAND + ' ' + $env:FZF_ALT_C_OPTS) | Invoke-Fzf | ForEach-Object { $result = $_ }
		}
    } 
	catch 
	{
		# catch custom exception
	}
    if (-not [string]::IsNullOrEmpty($result)) {
        Set-Location $result
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
	} else {
		#HACK: workaround for fact that PSReadLine seems to clear screen 
		# after keyboard shortcut action is executed:
		[Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
	}
}

function SetPsReadlineShortcut($Chord,[switch]$Override,$BriefDesc,$Desc,[scriptblock]$scriptBlock)
{
	if ([string]::IsNullOrEmpty($Chord)) {
		return $false
	}
	if ((Get-PSReadlineKeyHandler -Bound | Where-Object {$_.Key.ToLower() -eq $Chord}) -and -not $Override) {
		return $false
	} else {
		Set-PSReadlineKeyHandler -Key $Chord -Description $Desc -BriefDescription $BriefDesc -ScriptBlock $scriptBlock
		return $true
	} 
}


function FindFzf()
{
	if ($script:IsWindows) {
		$AppNames = @('fzf-*-windows_*.exe','fzf.exe')
	} else {
		if ($IsMacOS) {
			$AppNames = @('fzf-*-darwin_*','fzf')
		} elseif ($IsLinux) {
			$AppNames = @('fzf-*-linux_*','fzf')
		} else {
			throw 'Unknown OS'
		}
	}

    # find it in our path:
    $script:FzfLocation = $null
    $AppNames | ForEach-Object {
        if ($null -eq $script:FzfLocation) {
            $result = Get-Command $_ -ErrorAction SilentlyContinue
            $result | ForEach-Object {
                $script:FzfLocation = Resolve-Path $_.Source   
            }
        }
    }
    
    if ($null -eq $script:FzfLocation) {
        throw 'Failed to find fzf binary in PATH.  You can download a binary from this page: https://github.com/junegunn/fzf-bin/releases' 
    }
}

$PsReadlineShortcuts = @{
	PSReadlineChordProvider = [PSCustomObject]@{
		'Chord' = "$PSReadlineChordProvider" 
		'BriefDesc' = 'Fzf Provider Select' 
		'Desc' = 'Run fzf for current provider based on current token' 
		'ScriptBlock' = { Invoke-FzfPsReadlineHandlerProvider } };
	PSReadlineChordReverseHistory = [PsCustomObject]@{
		'Chord' = "$PSReadlineChordReverseHistory" 
		'BriefDesc' = 'Fzf Reverse History Select' 
		'Desc' = 'Run fzf to search through PSReadline history' 
		'ScriptBlock' = { Invoke-FzfPsReadlineHandlerHistory } };
	PSReadlineChordSetLocation = @{
		'Chord' = "$PSReadlineChordSetLocation"
		'BriefDesc' = 'Fzf Set Location'
		'Desc' = 'Run fzf to select directory to set current location' 
		'ScriptBlock' = { Invoke-FzfPsReadlineHandlerSetLocation } };
	PSReadlineChordReverseHistoryArgs = @{
		'Chord' = "$PSReadlineChordReverseHistoryArgs"
		'BriefDesc' = 'Fzf Reverse History Arg Select'
		'Desc' = 'Run fzf to search through command line arguments in PSReadline history' 
		'ScriptBlock' = { Invoke-FzfPsReadlineHandlerHistoryArgs } };	
}
if (Get-Module -ListAvailable -Name PSReadline) {
	$PsReadlineShortcuts.GetEnumerator() | ForEach-Object {
		$info = $_.Value
		$result = SetPsReadlineShortcut $info.Chord -Override:$PSBoundParameters.ContainsKey($_.Key) $info.BriefDesc $info.Desc $info.ScriptBlock
		# store that the chord is not activated:
		if (-not $result) {
			$info.Chord = $null
		}
	} 
} else {
	Write-Warning "PSReadline module not found - keyboard handlers not installed" 
}

FindFzf

try 
{
	$fzfVersion = $(& $script:FzfLocation --version).Split('.') 
	$script:UseHeightOption = $fzfVersion.length -eq 3 -and `
							  ([int]$fzfVersion[0] -gt 0 -or `
							  [int]$fzfVersion[1] -ge 21) -and `
							  $script:RunningInWindowsTerminal 	
}
catch 
{
	# continue
}