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

$script:RunningInWindowsTerminal = [bool]($env:WT_Session)
if ($script:RunningInWindowsTerminal) {
	$script:DefaultFileSystemFdCmd = "fd.exe --color always . {0}"	
} else {
	$script:DefaultFileSystemFdCmd = "fd.exe . {0}"	
}

$script:UseFd = $false

function Get-FileSystemCmd
{
	param($dir)
	if ([string]::IsNullOrWhiteSpace($env:FZF_DEFAULT_COMMAND)) {
		if ($script:UseFd) {
			# need to quote if there's spaces in the path name:
			if ($dir.Contains(' ')) {
				$strDir = """$dir""" 
			} else {
				$strDir = $dir
			}
			$script:DefaultFileSystemFdCmd -f $strDir
		} else {
			$script:ShellCmd -f ($script:DefaultFileSystemCmd -f $dir)
		}
	} else {
		$script:ShellCmd -f ($env:FZF_DEFAULT_COMMAND -f $dir)
	}
}

function FixCompletionResult($str) 
{
	if ($str.Contains(" ") -or $str.Contains("`t")) {
		return "'{0}'" -f $str.Replace("`r`n","").Trim(@('''','"'))
	} else {
		return $str.Replace("`r`n","")
	}
}

$script:FzfLocation = $null
$script:PSReadlineHandlerChords = @()
$script:TabContinuousTrigger = [IO.Path]::DirectorySeparatorChar.ToString()

$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove =
{
	$PsReadlineShortcuts.Values | Where-Object Chord | ForEach-Object { 
		Remove-PSReadlineKeyHandler $_.Chord
	}
	RemovePsFzfAliases

	RemoveGitKeyBindings
}

# if the quoted string ends with a '\', and we need to escape it for Windows:
function script:PrepareArg($argStr) {
	if (-not $argStr.EndsWith("\\") -and $argStr.EndsWith('\')) {
		return $argStr + '\'
	} else {
		return $argStr
	}
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
		$EnableAliasFuzzyGitStatus,
		[switch]
		$EnableFd
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
	if ($PSBoundParameters.ContainsKey('EnableFd')) {
		$script:UseFd = $EnableFd
	}
	if ($PSBoundParameters.ContainsKey('TabContinuousTrigger')) {
		$script:TabContinuousTrigger = $TabContinuousTrigger
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
		  	$Tiebreak = $null,

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
			[string]$Layout = $null,
			[switch]$Border,
			[ValidateSet('rounded','sharp','horizontal')]
			[string]$BorderStyle,
			[ValidateSet('default','inline','hidden')]
			[string]$Info = $null,
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
			[switch]$PrintQuery,
			[string]$Expect,
			
		  	[Parameter(ValueFromPipeline=$True)]
            [object[]]$Input
    )

	Begin {
		# process parameters: 
		$arguments = ''
		if ($PSBoundParameters.ContainsKey('Extended') -and $Extended) 											{ $arguments += '--extended '}
		if ($PSBoundParameters.ContainsKey('Exact') -and $Exact) 			        							{ $arguments += '--exact '}
		if ($PSBoundParameters.ContainsKey('CaseInsensitive') -and $CaseInsensitive) 							{ $arguments += '-i '}
		if ($PSBoundParameters.ContainsKey('CaseSensitive') -and $CaseSensitive) 								{ $arguments += '+i '}
		if ($PSBoundParameters.ContainsKey('Delimiter') -and ![string]::IsNullOrWhiteSpace($Delimiter)) 		{ $arguments += "--delimiter=$Delimiter "}
		if ($PSBoundParameters.ContainsKey('NoSort') -and $NoSort) 												{ $arguments += '--no-sort '}
		if ($PSBoundParameters.ContainsKey('ReverseInput') -and $ReverseInput) 									{ $arguments += '--tac '}
		if ($PSBoundParameters.ContainsKey('Phony') -and $Phony)												{ $arguments += '--phony '}
		if ($PSBoundParameters.ContainsKey('Tiebreak') -and ![string]::IsNullOrWhiteSpace($Tiebreak))			{ $arguments += "--tiebreak=$Tiebreak "}
		if ($PSBoundParameters.ContainsKey('Multi') -and $Multi) 												{ $arguments += '--multi '}
		if ($PSBoundParameters.ContainsKey('NoMouse') -and $NoMouse)					 						{ $arguments += '--no-mouse '}
        if ($PSBoundParameters.ContainsKey('Bind') -and ![string]::IsNullOrWhiteSpace($Bind))		    		{ $arguments += "--bind=$Bind "}
		if ($PSBoundParameters.ContainsKey('Reverse') -and $Reverse)					 						{ $arguments += '--reverse '}
		if ($PSBoundParameters.ContainsKey('Cycle') -and $Cycle)						 						{ $arguments += '--cycle '}
		if ($PSBoundParameters.ContainsKey('KeepRight') -and $KeepRight)						 				{ $arguments += '--keep-right '}
		if ($PSBoundParameters.ContainsKey('NoHScroll') -and $NoHScroll) 										{ $arguments += '--no-hscroll '}
		if ($PSBoundParameters.ContainsKey('FilepathWord') -and $FilepathWord)									{ $arguments += '--filepath-word '}
		if ($PSBoundParameters.ContainsKey('Height') -and ![string]::IsNullOrWhiteSpace($Height))				{ $arguments += "--height=$height "}
		if ($PSBoundParameters.ContainsKey('MinHeight') -and $MinHeight -ge 0)									{ $arguments += "--min-height=$MinHeight "}
		if ($PSBoundParameters.ContainsKey('Layout') -and ![string]::IsNullOrWhiteSpace($Layout))				{ $arguments += "--layout=$Layout "}
		if ($PSBoundParameters.ContainsKey('Border') -and $Border)												{ $arguments += '--border '}
		if ($PSBoundParameters.ContainsKey('BorderStyle') -and ![string]::IsNullOrWhiteSpace($BorderStyle))		{ $arguments += "--border=$BorderStyle "}
		if ($PSBoundParameters.ContainsKey('Info') -and ![string]::IsNullOrWhiteSpace($Info)) 					{ $arguments += "--info=$Info "}
		if ($PSBoundParameters.ContainsKey('Prompt') -and ![string]::IsNullOrWhiteSpace($Prompt)) 				{ $arguments += "--prompt='$Prompt' "}
		if ($PSBoundParameters.ContainsKey('Pointer') -and ![string]::IsNullOrWhiteSpace($Pointer)) 			{ $arguments += "--pointer='$Pointer' "}
		if ($PSBoundParameters.ContainsKey('Marker') -and ![string]::IsNullOrWhiteSpace($Marker)) 				{ $arguments += "--marker='$Marker' "}
        if ($PSBoundParameters.ContainsKey('Header') -and ![string]::IsNullOrWhiteSpace($Header)) 				{ $arguments += "--header=""$Header"" "}
		if ($PSBoundParameters.ContainsKey('HeaderLines') -and $HeaderLines -ge 0) 		               			{ $arguments += "--header-lines=$HeaderLines "}
		if ($PSBoundParameters.ContainsKey('Ansi') -and $Ansi)													{ $arguments += '--ansi '}
		if ($PSBoundParameters.ContainsKey('Tabstop') -and $Tabstop -ge 0)										{ $arguments += "--tabstop=$Tabstop "}
		if ($PSBoundParameters.ContainsKey('NoBold') -and $NoBold)												{ $arguments += '--no-bold '}
		if ($PSBoundParameters.ContainsKey('History') -and $History) 											{ $arguments += "--history='$History' "}
		if ($PSBoundParameters.ContainsKey('HistorySize') -and $HistorySize -ge 1)								{ $arguments += "--history-size=$HistorySize "}
        if ($PSBoundParameters.ContainsKey('Preview') -and ![string]::IsNullOrWhiteSpace($Preview)) 	    	{ $arguments += "--preview=""$Preview"" "}
        if ($PSBoundParameters.ContainsKey('PreviewWindow') -and ![string]::IsNullOrWhiteSpace($PreviewWindow)) { $arguments += "--preview-window=""$PreviewWindow"" "}
		if ($PSBoundParameters.ContainsKey('Query') -and ![string]::IsNullOrWhiteSpace($Query))					{ $arguments += "--query=""{0}"" " -f $(PrepareArg $Query)}
		if ($PSBoundParameters.ContainsKey('Select1') -and $Select1)											{ $arguments += '--select-1 '}
		if ($PSBoundParameters.ContainsKey('Exit0') -and $Exit0)												{ $arguments += '--exit-0 '}
		if ($PSBoundParameters.ContainsKey('Filter') -and ![string]::IsNullOrEmpty($Filter))					{ $arguments += "--filter=$Filter " }
		if ($PSBoundParameters.ContainsKey('PrintQuery') -and $PrintQuery)										{ $arguments += '--print-query '}
		if ($PSBoundParameters.ContainsKey('Expect') -and ![string]::IsNullOrWhiteSpace($Expect)) 	   			{ $arguments += "--expect=""$Expect"" "}
	 
		if ($script:UseHeightOption -and [string]::IsNullOrWhiteSpace($Height) -and `
		  	([string]::IsNullOrWhiteSpace($env:FZF_DEFAULT_OPTS) -or (-not $env:FZF_DEFAULT_OPTS.Contains('--height')))) {
			$arguments += "--height=40% "
		}
		
		if ($Border -eq $true -and -not [string]::IsNullOrWhiteSpace($BorderStyle)) {
			throw '-Border and -BorderStyle are mutally exclusive'
		}
		if ($script:UseFd -and $script:RunningInWindowsTerminal -and -not $arguments.Contains('--ansi')) {
			$arguments += "--ansi "
		}

		# prepare to start process:
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo.FileName = $script:FzfLocation
		$process.StartInfo.Arguments = $arguments
        $process.StartInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $process.StartInfo.RedirectStandardInput = $true
        $process.StartInfo.RedirectStandardOutput = $true
		$process.StartInfo.UseShellExecute = $false
		if ($pwd.Provider -eq 'FileSystem') {
			$process.StartInfo.WorkingDirectory = $pwd.Path
		}
        
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

		$utf8Encoding = New-Object System.Text.UTF8Encoding -ArgumentList $false
        $utf8Stream = New-Object System.IO.StreamWriter -ArgumentList $process.StandardInput.BaseStream, $utf8Encoding

		$cleanup = [scriptblock] {
			try {
           		$process.StandardInput.Close() | Out-Null
				$process.WaitForExit()
				
				# $utf8Stream.Close()
				$utf8Stream = $null
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
        
        try {
			# handle no piped input:
			if (!$hasInput) {
                # optimization for filesystem provider:
                if ($PWD.Provider.Name -eq 'FileSystem') {
					Invoke-Expression (Get-FileSystemCmd $PWD.Path) | ForEach-Object { 
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

    $result = @()
    try 
    {
		$prevDefaultOpts = $env:FZF_DEFAULT_OPTS
		$env:FZF_DEFAULT_OPTS = $env:FZF_DEFAULT_OPTS + ' ' + $env:FZF_CTRL_T_OPTS
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
					'FileSystem'    { Invoke-Expression (Get-FileSystemCmd $resolvedPath.ProviderPath) | Invoke-Fzf -Multi | ForEach-Object { $result += $_ } }
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
	finally 
	{
		$env:FZF_DEFAULT_OPTS = $prevDefaultOpts
	}
	
	#HACK: workaround for fact that PSReadLine seems to clear screen 
	# after keyboard shortcut action is executed:
	[Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()

	if ($null -ne $result) {
		# quote strings if we need to:
		if ($result -is [system.array]) {
			for ($i = 0;$i -lt $result.Length;$i++) {
				$result[$i] = FixCompletionResult $result[$i]
			}
		} else {
			$result = FixCompletionResult $result
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
		$prevDefaultOpts = $env:FZF_DEFAULT_OPTS
		$env:FZF_DEFAULT_OPTS = $env:FZF_DEFAULT_OPTS + ' ' + $env:FZF_CTRL_R_OPTS 

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
		$env:FZF_DEFAULT_OPTS = $prevDefaultOpts
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
		$prevDefaultOpts = $env:FZF_DEFAULT_OPTS
		$env:FZF_DEFAULT_OPTS = $env:FZF_DEFAULT_OPTS + ' ' + $env:FZF_ALT_C_OPTS
		if ($null -eq $env:FZF_ALT_C_COMMAND) {
			Get-ChildItem . -Recurse -ErrorAction SilentlyContinue -Directory | Invoke-Fzf | ForEach-Object { $result = $_ }
		} else {
			Invoke-Expression ($env:FZF_ALT_C_COMMAND) | Invoke-Fzf | ForEach-Object { $result = $_ }
		}
    } 
	catch 
	{
		# catch custom exception
	}
	finally 
	{
		$env:FZF_DEFAULT_OPTS = $prevDefaultOpts
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


function Invoke-TabCompletion()
{
	$script:continueCompletion = $true
	do 
	{
		$script:continueCompletion = Invoke-TabCompletionInner
	}
	while ($script:continueCompletion)
}
function Invoke-TabCompletionInner()
{
	$script:result = @()

	[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Management.Automation") 
	$leftCursor = $null
	$rightCursor = $null
	$line = $null
	$cursor = $null
	[Microsoft.PowerShell.PSConsoleReadline]::GetBufferState([ref]$line, [ref]$cursor)
	$currentPath = Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor)
	$addSpace = $null -ne $currentPath -and $currentPath.StartsWith(" ")

	if ($cursor -lt 0 -or [string]::IsNullOrWhiteSpace($line)) { 
		return $false
	}
	$completions = [System.Management.Automation.CommandCompletion]::CompleteInput($line, $cursor, @{})

	$completionMatches = $completions.CompletionMatches 
	if ($completionMatches.Count -le 0) {
		return $false
	}
	$script:continueCompletion = $false

	if ($completionMatches.Count -eq 1) {		
		$script:result = $completionMatches[0].CompletionText
	} elseif ($completionMatches.Count -gt 1) {
		$helpers = New-Object PSFzf.IO.CompletionHelpers
		$ambiguous = $false

		$prefix = $helpers.GetUnambiguousPrefix($completionMatches,[ref]$ambiguous)
		#if ($ambiguous) {
		#	$prefix = ''
		#}
		
		$script:result = @()
		$script:checkCompletion = $true
		$expectTrigger = $script:TabContinuousTrigger
		# need to escape the key if it's a forward slash:
		if ($expectTrigger -eq '\') {
			$expectTrigger += $expectTrigger 
		}
		$completionMatches | ForEach-Object { $_.CompletionText } | Invoke-Fzf -Layout reverse -Expect $expectTrigger -Query $prefix | 
		ForEach-Object {
			if ($script:checkCompletion) {
				$script:continueCompletion = $_ -eq $script:TabContinuousTrigger
				if (-not $script:continueCompletion) {
					$script:result += $_
				}
				$script:checkCompletion = $false
			} else {
				$script:result += $_
			}
		}

		#HACK: workaround for fact that PSReadLine seems to clear screen 
		# after keyboard shortcut action is executed:
		[Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
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
			if (Test-Path $str -PathType Container) {
				$str += $script:TabContinuousTrigger
			} else {
				# no more paths to complete, so let's stop completion:
				$str += ' ' 
				$script:continueCompletion = $false
			}
		}

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

	return $script:continueCompletion
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
	PSReadlineChordTabCompletion = [PSCustomObject]@{
		'Chord' = "Tab"
		'BriefDesc' = 'crap'
		'Desc' = 'crap'
		'ScriptBlock' = { Invoke-TabCompletion } };	
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