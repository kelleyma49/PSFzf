param(
	[parameter(Position=0,Mandatory=$false)][string]$PSReadlineChordProvider = 'Ctrl+T',
	[parameter(Position=1,Mandatory=$false)][string]$PSReadlineChordReverseHistory = 'Ctrl+R',
	[parameter(Position=1,Mandatory=$false)][string]$PSReadlineChordSetLocation = 'Alt+C',
	[parameter(Position=1,Mandatory=$false)][string]$PSReadlineChordReverseHistoryArgs = 'Alt+A')

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

$script:FzfLocation = $null
$script:PSReadlineHandlerChords = @()
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove =
{
	$script:PSReadlineHandlerChords | ForEach-Object {
			Remove-PSReadlineKeyHandler $_
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
		  	[ValidateSet('length','begin','end','index')]
		  	[string]
		  	$Tiebreak = 'length',

            # Interface
			[Alias('m')]
		  	[switch]$Multi,
			[switch]$NoMouse,
            [string]
		  	$Bind,
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
			[Alias('s1')]
			[switch]$Select1,
			[Alias('e0')]
			[switch]$Exit0,
			[Alias('f')]
			[string]$Filter,
			
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
		if (![string]::IsNullOrWhiteSpace($Tiebreak))		{ $arguments += "--tiebreak=$Tiebreak "}
		if ($Multi) 										{ $arguments += '--multi '}
		if ($NoMouse)					 					{ $arguments += '--no-mouse '}
        if (![string]::IsNullOrWhiteSpace($Bind))		    { $arguments += "--bind=$Bind "}
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
        
        try {
			# handle no piped input:
			if (!$hasInput) {
                # optimization for filesystem provider:
                if ($PWD.Provider.Name -eq 'FileSystem') {
					$cmd = $script:ShellCmd -f ($script:DefaultFileSystemCmd -f $PWD.Path)
					Invoke-Expression $cmd | ForEach-Object { 
                        $process.StandardInput.WriteLine($_) 
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
                            if ($str -eq $null) {
                                $str = $item.Name
                                if ($str -eq $null) {
                                    $str = $item.ToString()
                                }
                            }
                        }
                        if (![System.String]::IsNullOrWhiteSpace($str)) {
                            $process.StandardInput.WriteLine($str) 
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
                        if ($str -eq $null) {
                            $str = $item.Name
                            if ($str -eq $null) {
                                $str = $item.ToString()
                            }
                        }
                    }
                    if (![System.String]::IsNullOrWhiteSpace($str)) {
                        $process.StandardInput.WriteLine($str) 
                    }
                    if ($processHasExited.flag) {
                        throw "breaking inner pipeline"
					}
				}
			}
			$process.StandardInput.Flush()
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
	$addSpace = $currentPath -ne $null -and $currentPath.StartsWith(" ")
	if ([String]::IsNullOrWhitespace($currentPath) -or !(Test-Path $currentPath)) {
		$currentPath = $PWD
	}
    
    $result = @()
    try 
    {
        if ([string]::IsNullOrWhiteSpace($currentPath)) {
            Invoke-Fzf -Multi | ForEach-Object { $result += $_ }
        } else {
            $resolvedPath = Resolve-Path $currentPath -ErrorAction SilentlyContinue
            $providerName = $null
            if ($resolvedPath -ne $null) {
                $providerName = $resolvedPath.Provider.Name 
            }
            switch ($providerName) {
                # Get-ChildItem is way too slow - we optimize for the FileSystem provider by 
                # using batch commands:
                'FileSystem'    { Invoke-Expression ($script:ShellCmd -f ($script:DefaultFileSystemCmd -f $resolvedPath.ProviderPath)) | Invoke-Fzf -Multi | ForEach-Object { $result += $_ } }
                'Registry'      { Get-ChildItem $currentPath -Recurse -ErrorAction SilentlyContinue | Select-Object Name -ExpandProperty Name | Invoke-Fzf -Multi | ForEach-Object { $result += $_ } }
                $null           { Get-ChildItem $currentPath -Recurse -ErrorAction SilentlyContinue | Select-Object FullName -ExpandProperty FullName | Invoke-Fzf -Multi | ForEach-Object { $result += $_ } }
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
function Invoke-FzfPsReadlineHandlerHistory {
	$result = $null
	try
	{
		if ((Get-PSReadlineOption).HistoryNoDuplicates) {
			$modifier = { $input | Select-Object -Unique }
		} else {
			$modifier = { process { $_ } }
		}
		Get-Content (Get-PSReadlineOption).HistorySavePath | & $modifier | Invoke-Fzf -NoSort -ReverseInput | ForEach-Object { $result = $_ }
	}
	catch
	{
		# catch custom exception
	}
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
		Get-Content (Get-PSReadlineOption).HistorySavePath |
			ForEach-Object { [System.Management.Automation.PsParser]::Tokenize($_, [ref] $null) } |
			Where-Object {$_.type -eq "commandargument" -or $_.type -eq "string"} | 
                ForEach-Object { if (!$contentTable.ContainsKey($_.Content)) { $_.Content ; $contentTable[$_.Content] = $true } } |
				Invoke-Fzf -NoSort -ReverseInput -Preview "echo $line" -PreviewWindow "up:20%" | ForEach-Object { $result = $_ }
	}
	catch 
	{
		# catch custom exception
	}
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
		Get-ChildItem . -Recurse -ErrorAction SilentlyContinue -Directory | Invoke-Fzf | ForEach-Object { $result = $_ }
    } 
	catch 
	{
		# catch custom exception
	}
    if (-not [string]::IsNullOrEmpty($result)) {
        Set-Location $result
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
}

function SetPsReadlineShortcut($Chord,[switch]$Override,$BriefDesc,$Desc,[scriptblock]$scriptBlock)
{
	if ([string]::IsNullOrEmpty($Chord)) {
		return
	}

	if ((Get-PSReadlineKeyHandler -Bound | Where-Object Key -eq $Chord) -and -not $Override) {
		Write-Warning ("PSReadline chord {0} already in use - keyboard handler not installed.  To bind your own keyboard chord, use the -ArgumentList parameter when you call Import-Module." -f $Chord)
	} else {
		$script:PSReadlineHandlerChords += $Chord
		Set-PSReadlineKeyHandler -Key $Chord -Description $Desc -BriefDescription $BriefDesc -ScriptBlock $scriptBlock
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
        throw 'Failed to find fzf binary in PATH.  You can download a binary from this page: https://github.com/junegunn/fzf-bin/releases' 
    }
}
if (Get-Module -ListAvailable -Name PSReadline) { 
	SetPsReadlineShortcut "$PSReadlineChordProvider" -Override:$PSBoundParameters.ContainsKey('PSReadlineChordProvider') 'Fzf Provider Select' 'Run fzf for current provider based on current token' { Invoke-FzfPsReadlineHandlerProvider }
	SetPsReadlineShortcut "$PSReadlineChordReverseHistory" -Override:$PSBoundParameters.ContainsKey('PSReadlineChordReverseHistory') 'Fzf Reverse History Select' 'Run fzf to search through PSReadline history' { Invoke-FzfPsReadlineHandlerHistory }
	SetPsReadlineShortcut "$PSReadlineChordSetLocation" -Override:$PSBoundParameters.ContainsKey('PSReadlineChordSetLocation') 'Fzf Set Location' 'Run fzf to select directory to set current location' { Invoke-FzfPsReadlineHandlerSetLocation }
	SetPsReadlineShortcut "$PSReadlineChordReverseHistoryArgs" -Override:$PSBoundParameters.ContainsKey('PSReadlineChordReverseHistoryArgs') 'Fzf Reverse History Arg Select' 'Run fzf to search through command line arguments in PSReadline history' { Invoke-FzfPsReadlineHandlerHistoryArgs }
} else {
	Write-Warning "PSReadline module not found - keyboard handlers not installed" 
}

FindFzf

@('PSFzf.Functions.ps1') | ForEach-Object {  Join-Path $PSScriptRoot $_ } | ForEach-Object {
	. $_
}

	
