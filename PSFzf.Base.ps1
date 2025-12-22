param(
	[parameter(Position = 0, Mandatory = $false)][string]$PSReadlineChordProvider = 'Ctrl+t',
	[parameter(Position = 1, Mandatory = $false)][string]$PSReadlineChordReverseHistory = 'Ctrl+r',
	[parameter(Position = 2, Mandatory = $false)][string]$PSReadlineChordSetLocation = 'Alt+c',
	[parameter(Position = 3, Mandatory = $false)][string]$PSReadlineChordReverseHistoryArgs = 'Alt+a')

$script:IsWindows = ($PSVersionTable.PSVersion.Major -le 5) -or $IsWindows
if ($script:IsWindows) {
	$script:ShellCmd = 'cmd.exe /S /C {0}'
	$script:DefaultFileSystemCmd = @"
dir /s/b "{0}"
"@
	$script:DefaultFileSystemCmdDirOnly = @"
dir /s/b/ad "{0}"
"@
}
else {
	$script:ShellCmd = '/bin/sh -c "{0}"'
	$script:DefaultFileSystemCmd = @"
find -L '{0}' -path '*/\.*' -prune -o -type f -print -o -type l -print 2> /dev/null
"@
	$script:DefaultFileSystemCmdDirOnly = @"
find -L '{0}' -path '*/\.*' -prune -o -type d -print 2> /dev/null
"@
}

$script:AnsiCompatible = [bool]($env:WT_Session) -or [bool]($env:ConEmuANSI) -or [bool]($env:TERM_PROGRAM -eq "WezTerm")
if ($script:AnsiCompatible) {
	$script:DefaultFileSystemFdCmd = "fd.exe --color always . --full-path `"{0}`" --fixed-strings"
}
else {
	$script:DefaultFileSystemFdCmd = "fd.exe . --full-path `"{0}`" --fixed-strings"
}

$script:UseFd = $false
$script:AltCCommand = [ScriptBlock] {
	param($Location)
	Set-Location $Location
}

function Get-FileSystemCmd {
	param($dir, [switch]$dirOnly = $false)

	# Note that there is no way to know how to list only directories using
	# FZF_DEFAULT_COMMAND, so we never use it in that case.
	if ($dirOnly -or [string]::IsNullOrWhiteSpace($env:FZF_DEFAULT_COMMAND)) {
		if ($script:UseFd) {
			if ($dirOnly) {
				"$($script:DefaultFileSystemFdCmd -f $dir) --type directory"
			}
			else {
				$script:DefaultFileSystemFdCmd -f $dir
			}
		}
		else {
			$cmd = $script:DefaultFileSystemCmd
			if ($dirOnly) {
				$cmd = $script:DefaultFileSystemCmdDirOnly
			}
			$script:ShellCmd -f ($cmd -f $dir)
		}
	}
 else {
		$script:ShellCmd -f ($env:FZF_DEFAULT_COMMAND -f $dir)
	}
}

class FzfDefaultOpts {
	[bool]$UsePsFzfOpts
	[string]$PrevEnv
	[bool]$Restored

	FzfDefaultOpts([string]$tempVal) {
		$this.UsePsFzfOpts = -not [string]::IsNullOrWhiteSpace($env:_PSFZF_FZF_DEFAULT_OPTS)
		$this.PrevEnv = $env:FZF_DEFAULT_OPTS
		$env:FZF_DEFAULT_OPTS = $this.Get() + " " + $tempVal
	}

	[string]Get() {
		if ($this.UsePsFzfOpts) {
			return $env:_PSFZF_FZF_DEFAULT_OPTS;
		}
		else {
			return $env:FZF_DEFAULT_OPTS;
		}
	}

	[void]Restore() {
		$env:FZF_DEFAULT_OPTS = $this.PrevEnv
	}
}

class FzfDefaultCmd {
	[string]$PrevEnv

	FzfDefaultCmd([string]$overrideVal) {
		$this.PrevEnv = $env:FZF_DEFAULT_COMMAND
		$env:FZF_DEFAULT_COMMAND = $overrideVal
	}

	[void]Restore() {
		$env:FZF_DEFAULT_COMMAND = $this.PrevEnv
	}
}

function FixCompletionResult($str, [switch]$AlwaysQuote) {
	if ([string]::IsNullOrEmpty($str)) {
		return ""
	}
	
	$str = $str.Replace("`r`n", "")
	
	# check if already quoted
	$isAlreadyQuoted = ($str.StartsWith("'") -and $str.EndsWith("'")) -or `
		($str.StartsWith("""") -and $str.EndsWith(""""))
	
	if ($isAlreadyQuoted) {
		return $str
	}
	
	# Quote if it contains spaces/tabs, or if AlwaysQuote is specified
	if ($AlwaysQuote -or $str.Contains(" ") -or $str.Contains("`t")) {
		return """{0}""" -f $str
	}
	else {
		return $str
	}
}



#HACK: workaround for fact that PSReadLine seems to clear screen
# after keyboard shortcut action is executed, and to work around a UTF8
# PSReadLine issue (GitHub PSFZF issue #71)
function InvokePromptHack() {
	$previousOutputEncoding = [Console]::OutputEncoding
	[Console]::OutputEncoding = [Text.Encoding]::UTF8

	try {
		Invoke-PSConsoleReadLinePrompt
	}
 finally {
		[Console]::OutputEncoding = $previousOutputEncoding
	}
}

$script:FzfLocation = $null
$script:OverrideFzfDefaults = $null
$script:PSReadlineHandlerChords = @()
$script:TabContinuousTrigger = [IO.Path]::DirectorySeparatorChar.ToString()
$script:PsReadlineHandlerProviderDelimiter = ','
$script:TabCompletionPreviewWindow = 'hidden|down|right|right:hidden'

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
	}
 else {
		return $argStr
	}
}

function Set-PsFzfOption {
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
		$EnableAliasFuzzyScoop,
		[switch]
		$EnableAliasFuzzySetEverything,
		[switch]
		$EnableAliasFuzzyZLocation,
		[switch]
		$EnableAliasFuzzyGitStatus,
		[switch]
		$EnableFd,
		[string]
		$TabContinuousTrigger,
		[ScriptBlock]
		$AltCCommand,
		[string]
		$PsReadlineHandlerProviderDelimiter,
		[string]
		$TabCompletionPreviewWindow
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

	if ($EnableAliasFuzzyEdit) { SetPsFzfAlias "fe"      Invoke-FuzzyEdit }
	if ($EnableAliasFuzzyFasd) { SetPsFzfAlias "ff"      Invoke-FuzzyFasd }
	if ($EnableAliasFuzzyHistory) { SetPsFzfAlias "fh"      Invoke-FuzzyHistory }
	if ($EnableAliasFuzzyKillProcess) { SetPsFzfAlias "fkill"   Invoke-FuzzyKillProcess }
	if ($EnableAliasFuzzySetLocation) { SetPsFzfAlias "fd"      Invoke-FuzzySetLocation }
	if ($EnableAliasFuzzyZLocation) { SetPsFzfAlias "fz"      Invoke-FuzzyZLocation }
	if ($EnableAliasFuzzyGitStatus) { SetPsFzfAlias "fgs"     Invoke-FuzzyGitStatus }
	if ($EnableAliasFuzzyScoop) { SetPsFzfAlias "fs"      Invoke-FuzzyScoop }
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

	if ($PSBoundParameters.ContainsKey('AltCCommand')) {
		$script:AltCCommand = $AltCCommand
	}

	if ($PSBoundParameters.ContainsKey('PsReadlineHandlerProviderDelimiter')) {
		$script:PsReadlineHandlerProviderDelimiter = $PsReadlineHandlerProviderDelimiter
	}

	if ($PSBoundParameters.ContainsKey('TabCompletionPreviewWindow')) {
		$script:TabCompletionPreviewWindow = $TabCompletionPreviewWindow
	}
}

function Stop-Pipeline {
	# borrowed from https://stackoverflow.com/a/34800670:
	(Add-Type -Passthru -TypeDefinition '
	using System.Management.Automation;
	namespace PSFzf.IO {
	  public static class CustomPipelineStopper {
		public static void Stop(Cmdlet cmdlet) {
		  throw (System.Exception) System.Activator.CreateInstance(typeof(Cmdlet).Assembly.GetType("System.Management.Automation.StopUpstreamCommandsException"), cmdlet);
		}
	  }
	}')::Stop($PSCmdlet)
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
		[ValidateSet('default', 'path', 'history')]
		[string]
		$Scheme = $null,
		[Alias('d')]
		[string]$Delimiter,
		[Alias('n')]
		[string]$WithNth,
		[switch]$NoSort,
		[Alias('tac')]
		[switch]$ReverseInput,
		[switch]$Phony,
		[ValidateSet('length', 'begin', 'end', 'index')]
		[string]
		$Tiebreak = $null,
		[switch]$Disabled,

		# Interface
		[Alias('m')]
		[switch]$Multi,
		[switch]$HighlightLine,
		[switch]$NoMouse,
		[string[]]$Bind,
		[switch]$Cycle,
		[switch]$KeepRight,
		[switch]$NoHScroll,
		[switch]$FilepathWord,

		# Layout
		[ValidatePattern("^[1-9]+[0-9]+$|^[1-9][0-9]?%?$|^100%?$")]
		[string]$Height,
		[ValidateRange(1, [int]::MaxValue)]
		[int]$MinHeight,
		[ValidateSet('default', 'reverse', 'reverse-list')]
		[string]$Layout = $null,
		[switch]$Border,
		[ValidateSet('rounded', 'sharp', 'bold', 'block', 'double', 'horizontal', 'vertical', 'top', 'bottom', 'left', 'right', 'none')]
		[string]$BorderStyle,
		[string]$BorderLabel,
		[ValidateSet('default', 'inline', 'hidden')]
		[string]$Info = $null,
		[string]$Prompt,
		[string]$Pointer,
		[string]$Marker,
		[string]$Header,
		[int]$HeaderLines = -1,

		# Display
		[switch]$Read0,
		[switch]$Ansi,
		[int]$Tabstop = 8,
		[string]$Color,
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

		[Parameter(ValueFromPipeline = $True)]
		[object[]]$Input
	)

	Begin {
		# process parameters:
		$arguments = ''
		$WriteLine = $true
		if ($PSBoundParameters.ContainsKey('Extended') -and $Extended) { $arguments += '--extended ' }
		if ($PSBoundParameters.ContainsKey('Exact') -and $Exact) { $arguments += '--exact ' }
		if ($PSBoundParameters.ContainsKey('CaseInsensitive') -and $CaseInsensitive) { $arguments += '-i ' }
		if ($PSBoundParameters.ContainsKey('CaseSensitive') -and $CaseSensitive) { $arguments += '+i ' }
		if ($PSBoundParameters.ContainsKey('Scheme') -and ![string]::IsNullOrWhiteSpace($Scheme)) { $arguments += "--scheme=$Scheme " }
		if ($PSBoundParameters.ContainsKey('Delimiter') -and ![string]::IsNullOrWhiteSpace($Delimiter)) { $arguments += "--delimiter=$Delimiter " }
		if ($PSBoundParameters.ContainsKey('WithNth') -and ![string]::IsNullOrWhiteSpace($WithNth)) { $arguments += "--with-nth=$WithNth " }
		if ($PSBoundParameters.ContainsKey('NoSort') -and $NoSort) { $arguments += '--no-sort ' }
		if ($PSBoundParameters.ContainsKey('ReverseInput') -and $ReverseInput) { $arguments += '--tac ' }
		if ($PSBoundParameters.ContainsKey('Phony') -and $Phony) { $arguments += '--phony ' }
		if ($PSBoundParameters.ContainsKey('Tiebreak') -and ![string]::IsNullOrWhiteSpace($Tiebreak)) { $arguments += "--tiebreak=$Tiebreak " }
		if ($PSBoundParameters.ContainsKey('Disabled') -and $Disabled) { $arguments += '--disabled ' }
		if ($PSBoundParameters.ContainsKey('Multi') -and $Multi) { $arguments += '--multi ' }
		if ($PSBoundParameters.ContainsKey('Highlightline') -and $Highlightline) { $arguments += '--highlight-line ' }
		if ($PSBoundParameters.ContainsKey('NoMouse') -and $NoMouse) { $arguments += '--no-mouse ' }
		if ($PSBoundParameters.ContainsKey('Bind') -and $Bind.Length -ge 1) { $Bind | ForEach-Object { $arguments += "--bind=""$_"" " } }
		if ($PSBoundParameters.ContainsKey('Reverse') -and $Reverse) { $arguments += '--reverse ' }
		if ($PSBoundParameters.ContainsKey('Cycle') -and $Cycle) { $arguments += '--cycle ' }
		if ($PSBoundParameters.ContainsKey('KeepRight') -and $KeepRight) { $arguments += '--keep-right ' }
		if ($PSBoundParameters.ContainsKey('NoHScroll') -and $NoHScroll) { $arguments += '--no-hscroll ' }
		if ($PSBoundParameters.ContainsKey('FilepathWord') -and $FilepathWord) { $arguments += '--filepath-word ' }
		if ($PSBoundParameters.ContainsKey('Height') -and ![string]::IsNullOrWhiteSpace($Height)) { $arguments += "--height=$height " }
		if ($PSBoundParameters.ContainsKey('MinHeight') -and $MinHeight -ge 0) { $arguments += "--min-height=$MinHeight " }
		if ($PSBoundParameters.ContainsKey('Layout') -and ![string]::IsNullOrWhiteSpace($Layout)) { $arguments += "--layout=$Layout " }
		if ($PSBoundParameters.ContainsKey('Border') -and $Border) { $arguments += '--border ' }
		if ($PSBoundParameters.ContainsKey('BorderLabel') -and ![string]::IsNullOrWhiteSpace($BorderLabel)) { $arguments += "--border-label=""$BorderLabel"" " }
		if ($PSBoundParameters.ContainsKey('BorderStyle') -and ![string]::IsNullOrWhiteSpace($BorderStyle)) { $arguments += "--border=$BorderStyle " }
		if ($PSBoundParameters.ContainsKey('Info') -and ![string]::IsNullOrWhiteSpace($Info)) { $arguments += "--info=$Info " }
		if ($PSBoundParameters.ContainsKey('Prompt') -and ![string]::IsNullOrWhiteSpace($Prompt)) { $arguments += "--prompt=""$Prompt"" " }
		if ($PSBoundParameters.ContainsKey('Pointer') -and ![string]::IsNullOrWhiteSpace($Pointer)) { $arguments += "--pointer=""$Pointer"" " }
		if ($PSBoundParameters.ContainsKey('Marker') -and ![string]::IsNullOrWhiteSpace($Marker)) { $arguments += "--marker=""$Marker"" " }
		if ($PSBoundParameters.ContainsKey('Header') -and ![string]::IsNullOrWhiteSpace($Header)) { $arguments += "--header=""$Header"" " }
		if ($PSBoundParameters.ContainsKey('HeaderLines') -and $HeaderLines -ge 0) { $arguments += "--header-lines=$HeaderLines " }
		if ($PSBoundParameters.ContainsKey('Read0') -and $Read0) { $arguments += '--read0 ' ; $WriteLine = $false }
		if ($PSBoundParameters.ContainsKey('Ansi') -and $Ansi) { $arguments += '--ansi ' }
		if ($PSBoundParameters.ContainsKey('Tabstop') -and $Tabstop -ge 0) { $arguments += "--tabstop=$Tabstop " }
		if ($PSBoundParameters.ContainsKey('Color') -and ![string]::IsNullOrWhiteSpace($Color)) { $arguments += "--color=""$Color"" " }
		if ($PSBoundParameters.ContainsKey('NoBold') -and $NoBold) { $arguments += '--no-bold ' }
		if ($PSBoundParameters.ContainsKey('History') -and $History) { $arguments += "--history=""$History"" " }
		if ($PSBoundParameters.ContainsKey('HistorySize') -and $HistorySize -ge 1) { $arguments += "--history-size=$HistorySize " }
		if ($PSBoundParameters.ContainsKey('Preview') -and ![string]::IsNullOrWhiteSpace($Preview)) { $arguments += "--preview=""$Preview"" " }
		if ($PSBoundParameters.ContainsKey('PreviewWindow') -and ![string]::IsNullOrWhiteSpace($PreviewWindow)) { $arguments += "--preview-window=""$PreviewWindow"" " }
		if ($PSBoundParameters.ContainsKey('Query') -and ![string]::IsNullOrWhiteSpace($Query)) { $arguments += "--query=""{0}"" " -f $(PrepareArg $Query) }
		if ($PSBoundParameters.ContainsKey('Select1') -and $Select1) { $arguments += '--select-1 ' }
		if ($PSBoundParameters.ContainsKey('Exit0') -and $Exit0) { $arguments += '--exit-0 ' }
		if ($PSBoundParameters.ContainsKey('Filter') -and ![string]::IsNullOrEmpty($Filter)) { $arguments += "--filter=$Filter " }
		if ($PSBoundParameters.ContainsKey('PrintQuery') -and $PrintQuery) { $arguments += '--print-query ' }
		if ($PSBoundParameters.ContainsKey('Expect') -and ![string]::IsNullOrWhiteSpace($Expect)) { $arguments += "--expect=""$Expect"" " }

		if (!$script:OverrideFzfDefaults) {
			$script:OverrideFzfDefaults = [FzfDefaultOpts]::new("")
		}

		if ($script:UseHeightOption -and [string]::IsNullOrWhiteSpace($Height) -and `
			([string]::IsNullOrWhiteSpace($script:OverrideFzfDefaults.Get()) -or `
				(-not $script:OverrideFzfDefaults.Get().Contains('--height')))) {
			$arguments += "--height=40% "
		}

		if ($Border -eq $true -and -not [string]::IsNullOrWhiteSpace($BorderStyle)) {
			throw '-Border and -BorderStyle are mutally exclusive'
		}
		if ($script:UseFd -and $script:AnsiCompatible -and -not $arguments.Contains('--ansi')) {
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
		if ($pwd.Provider.Name -eq 'FileSystem') {
			$process.StartInfo.WorkingDirectory = $pwd.ProviderPath
		}

		# Adding event handers for stdout:
		$stdOutEventId = "PsFzfStdOutEh-" + [System.Guid]::NewGuid()
		$stdOutEvent = Register-ObjectEvent -InputObject $process `
			-EventName 'OutputDataReceived' `
			-SourceIdentifier $stdOutEventId

		$processHasExited = new-object psobject -property @{flag = $false }
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
		$script:utf8Stream = New-Object System.IO.StreamWriter -ArgumentList $process.StandardInput.BaseStream, $utf8Encoding

		$cleanup = [scriptblock] {
			if ($script:OverrideFzfDefaults) {
				$script:OverrideFzfDefaults.Restore()
				$script:OverrideFzfDefaults = $null
			}

			try {
				$process.StandardInput.Close() | Out-Null
				$process.WaitForExit()
			}
			catch {
				# do nothing
			}

			try {
				#$stdOutEventId,$exitedEventId | ForEach-Object {
				#	Unregister-Event $_ -ErrorAction SilentlyContinue
				#}

				$stdOutEvent, $exitedEvent | ForEach-Object {
					Stop-Job $_  -ErrorAction SilentlyContinue
					Remove-Job $_ -Force  -ErrorAction SilentlyContinue
				}
			}
			catch {

			}

			# events seem to be generated out of order - therefore, we need sort by time created. For example,
			# -print-query and -expect and will be outputted first if specified on the command line.
			Get-Event -SourceIdentifier $stdOutEventId | `
				Sort-Object -Property TimeGenerated | `
				Where-Object { $null -ne $_.SourceEventArgs.Data } | ForEach-Object {
				Write-Output $_.SourceEventArgs.Data
				Remove-Event -EventIdentifier $_.EventIdentifier
			}
		}
		$checkProcessStatus = [scriptblock] {
			if ($processHasExited.flag -or $process.HasExited) {
				$script:utf8stream = $null
				& $cleanup
				Stop-Pipeline
			}
		}
	}

	Process {
		$hasInput = $PSBoundParameters.ContainsKey('Input')

		# handle no piped input:
		if (!$hasInput) {
			# optimization for filesystem provider:
			if ($PWD.Provider.Name -eq 'FileSystem') {
				Invoke-Expression (Get-FileSystemCmd $PWD.ProviderPath) | ForEach-Object {
					try {
						if ($WriteLine) {
							$utf8Stream.WriteLine($_)
						}
						else {
							$utf8Stream.Write($_)
						}
					}
					catch [System.Management.Automation.MethodInvocationException] {
						# Possibly broken pipe. Next clause will handle graceful shutdown.
					}
					finally {
						& $checkProcessStatus
					}
				}
			}
			else {
				Get-ChildItem . -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
					$item = $_
					if ($item -is [System.String]) {
						$str = $item
					}
					else {
						# search through common properties:
						$str = $item.FullName
						if ($null -eq $str) {
							$str = $item.Name
							if ($null -eq $str) {
								$str = $item.ToString()
							}
						}
					}
					try {
						if ($WriteLine) {
							$utf8Stream.WriteLine($str)
						}
						else {
							$utf8Stream.Write($str)
						}
					}
					catch [System.Management.Automation.MethodInvocationException] {
						# Possibly broken pipe. We will shutdown the pipe below.
					}
					& $checkProcessStatus
				}
			}

		}
		else {
			foreach ($item in $Input) {
				if ($item -is [System.String]) {
					$str = $item
				}
				else {
					# search through common properties:
					$str = $item.FullName
					if ($null -eq $str) {
						$str = $item.Name
						if ($null -eq $str) {
							$str = $item.ToString()
						}
					}
				}
				try {
					if ($WriteLine) {
						$utf8Stream.WriteLine($str)
					}
					else {
						$utf8Stream.Write($str)
					}
				}
				catch [System.Management.Automation.MethodInvocationException] {
					# Possibly broken pipe. We will shutdown the pipe below.
				}
				& $checkProcessStatus
			}
		}
		if ($null -ne $utf8Stream) {
			try {
				$utf8Stream.Flush()
			}
			catch [System.Management.Automation.MethodInvocationException] {
				# Possibly broken pipe, check process status.
				& $checkProcessStatus
			}
		}
	}

	End {
		& $cleanup
	}
}

function Find-CurrentPath {
	param([string]$line, [int]$cursor, [ref]$leftCursor, [ref]$rightCursor)

	if ($line.Length -eq 0) {
		$leftCursor.Value = $rightCursor.Value = 0
		return $null
	}

	if ($cursor -ge $line.Length) {
		$leftCursorTmp = $cursor - 1
	}
 else {
		$leftCursorTmp = $cursor
	}
	:leftSearch for (; $leftCursorTmp -ge 0; $leftCursorTmp--) {
		if ([string]::IsNullOrWhiteSpace($line[$leftCursorTmp])) {
			if (($leftCursorTmp -lt $cursor) -and ($leftCursorTmp -lt $line.Length - 1)) {
				$leftCursorTmpQuote = $leftCursorTmp - 1
				$leftCursorTmp = $leftCursorTmp + 1
			}
			else {
				$leftCursorTmpQuote = $leftCursorTmp
			}
			for (; $leftCursorTmpQuote -ge 0; $leftCursorTmpQuote--) {
				if (($line[$leftCursorTmpQuote] -eq '"') -and (($leftCursorTmpQuote -le 0) -or ($line[$leftCursorTmpQuote - 1] -ne '"'))) {
					$leftCursorTmp = $leftCursorTmpQuote
					break leftSearch
				}
				elseif (($line[$leftCursorTmpQuote] -eq "'") -and (($leftCursorTmpQuote -le 0) -or ($line[$leftCursorTmpQuote - 1] -ne "'"))) {
					$leftCursorTmp = $leftCursorTmpQuote
					break leftSearch
				}
			}
			break leftSearch
		}
	}
	:rightSearch for ($rightCursorTmp = $cursor; $rightCursorTmp -lt $line.Length; $rightCursorTmp++) {
		if ([string]::IsNullOrWhiteSpace($line[$rightCursorTmp])) {
			if ($rightCursorTmp -gt $cursor) {
				$rightCursorTmp = $rightCursorTmp - 1
			}
			for ($rightCursorTmpQuote = $rightCursorTmp + 1; $rightCursorTmpQuote -lt $line.Length; $rightCursorTmpQuote++) {
				if (($line[$rightCursorTmpQuote] -eq '"') -and (($rightCursorTmpQuote -gt $line.Length) -or ($line[$rightCursorTmpQuote + 1] -ne '"'))) {
					$rightCursorTmp = $rightCursorTmpQuote
					break rightSearch
				}
				elseif (($line[$rightCursorTmpQuote] -eq "'") -and (($rightCursorTmpQuote -gt $line.Length) -or ($line[$rightCursorTmpQuote + 1] -ne "'"))) {
					$rightCursorTmp = $rightCursorTmpQuote
					break rightSearch
				}
			}
			break rightSearch
		}
	}
	if ($leftCursorTmp -lt 0 -or $leftCursorTmp -gt $line.Length - 1) { $leftCursorTmp = 0 }
	if ($rightCursorTmp -ge $line.Length) { $rightCursorTmp = $line.Length - 1 }
	$leftCursor.Value = $leftCursorTmp
	$rightCursor.Value = $rightCursorTmp
	$str = -join ($line[$leftCursorTmp..$rightCursorTmp])
	return $str.Trim("'").Trim('"')
}

function Invoke-FzfDefaultSystem {
	param($ProviderPath, $DefaultOpts)

	$script:OverrideFzfDefaultOpts = [FzfDefaultOpts]::new($DefaultOpts)
	$arguments = ''
	if (-not $script:OverrideFzfDefaultOpts.Get().Contains('--height')) {
		$arguments += "--height=40% "
	}

	if ($script:UseFd -and $script:AnsiCompatible -and -not $script:OverrideFzfDefaultOpts.Get().Contains('--ansi')) {
		$arguments += "--ansi "
	}
	if ($script:UseWalker -and -not $script:OverrideFzfDefaultOpts.Get().Contains('--walker')) {
		$arguments += "--walker=file,dir "
	}

	$script:OverrideFzfDefaultCommand = [FzfDefaultCmd]::new('')
	try {
		# native filesystem walking is MUCH faster with native Go code:
		$env:FZF_DEFAULT_COMMAND = ""

		$result = @()

		# --height doesn't work with Invoke-Expression - not sure why. Thus, we need to use
		# System.Diagnostics.Process:
		$process = New-Object System.Diagnostics.Process
		$process.StartInfo.FileName = $script:FzfLocation
		$process.StartInfo.Arguments = $arguments
		$process.StartInfo.RedirectStandardInput = $false
		$process.StartInfo.RedirectStandardOutput = $true
		$process.StartInfo.UseShellExecute = $false
		$process.StartInfo.WorkingDirectory = $ProviderPath

		# Adding event handers for stdout:
		$stdOutEventId = "Invoke-FzfDefaultSystem-PsFzfStdOutEh-" + [System.Guid]::NewGuid()
		$stdOutEvent = Register-ObjectEvent -InputObject $process `
			-EventName 'OutputDataReceived' `
			-SourceIdentifier $stdOutEventId

		$process.Start() | Out-Null
		$process.BeginOutputReadLine() | Out-Null
		$process.WaitForExit()

		Get-Event -SourceIdentifier $stdOutEventId | `
			Sort-Object -Property TimeGenerated | `
			Where-Object { $null -ne $_.SourceEventArgs.Data } | ForEach-Object {
			$result += $_.SourceEventArgs.Data
			Remove-Event -EventIdentifier $_.EventIdentifier
		}
		Remove-Event -SourceIdentifier $stdOutEventId
	}
 catch {
		# ignore errors
	}
 finally {
		if ($script:OverrideFzfDefaultCommand) {
			$script:OverrideFzfDefaultCommand.Restore()
			$script:OverrideFzfDefaultCommand = $null
		}
		if ($script:OverrideFzfDefaultOpts) {
			$script:OverrideFzfDefaultOpts.Restore()
			$script:OverrideFzfDefaultOpts = $null
		}
	}
	if ((Join-Path $PWD '') -ne (Join-Path $ProviderPath '')) {
		for ($i = 0;$i -lt $result.Length;$i++) {
			$result[$i] = Join-Path $ProviderPath $result[$i]
		}
	}

	return $result
}

function Invoke-FzfPsReadlineHandlerProvider {
	$leftCursor = $null
	$rightCursor = $null
	$bufferState = Get-PSConsoleReadLineBufferState
	$line = $bufferState.Line
	$cursor = $bufferState.Cursor
	$currentPath = Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor)
	$addSpace = $null -ne $currentPath -and $currentPath.StartsWith(" ")
	if ([String]::IsNullOrWhitespace($currentPath) -or !(Test-Path $currentPath)) {
		$currentPath = $PWD
	}
	$isUsingPath = -not [string]::IsNullOrWhiteSpace($currentPath)

	$result = @()
	try {
		$script:OverrideFzfDefaults = [FzfDefaultOpts]::new($env:FZF_CTRL_T_OPTS)

		if (-not [System.String]::IsNullOrWhiteSpace($env:FZF_CTRL_T_COMMAND)) {
			Invoke-Expression ($env:FZF_CTRL_T_COMMAND) | Invoke-Fzf -Multi | ForEach-Object { $result += $_ }
		}
		else {
			if (-not $isUsingPath) {
				Invoke-Fzf -Multi | ForEach-Object { $result += $_ }
			}
			else {
				$resolvedPath = Resolve-Path $currentPath -ErrorAction SilentlyContinue
				$providerName = $null
				if ($null -ne $resolvedPath) {
					$providerName = $resolvedPath.Provider.Name
				}
				switch ($providerName) {
					# Get-ChildItem is way too slow - we optimize using our own function for calling fzf directly (Invoke-FzfDefaultSystem):
					'FileSystem' {
						if (-not $script:UseFd) {
							$result = Invoke-FzfDefaultSystem $resolvedPath.ProviderPath '--multi'
						}
						else {
							Invoke-Expression (Get-FileSystemCmd $resolvedPath.ProviderPath) | Invoke-Fzf -Multi | ForEach-Object { $result += $_ }
						}
					}
					'Registry' { Get-ChildItem $currentPath -Recurse -ErrorAction SilentlyContinue | Select-Object Name -ExpandProperty Name | Invoke-Fzf -Multi | ForEach-Object { $result += $_ } }
					$null { Get-ChildItem $currentPath -Recurse -ErrorAction SilentlyContinue | Select-Object FullName -ExpandProperty FullName | Invoke-Fzf -Multi | ForEach-Object { $result += $_ } }
					Default {}
				}
			}
		}
	}
	catch {
		# catch custom exception
	}
	finally {
		if ($script:OverrideFzfDefaults) {
			$script:OverrideFzfDefaults.Restore()
			$script:OverrideFzfDefaults = $null
		}
	}

	InvokePromptHack

	if ($null -ne $result) {
		# quote strings if we need to:
		if ($result -is [system.array]) {
			for ($i = 0; $i -lt $result.Length; $i++) {
				if ($isUsingPath) {
					$resultFull = Join-Path $currentPath $result[$i]
				}
				else {
					$resultFull = $result[$i]
				}
				$result[$i] = FixCompletionResult $resultFull -AlwaysQuote
			}
		}
		else {
			if ($isUsingPath) {
				$result = Join-Path $currentPath $result
			}
			$result = FixCompletionResult $result
		}

		$str = $result -join $script:PsReadlineHandlerProviderDelimiter
		if ($addSpace) {
			$str = ' ' + $str
		}
		$replaceLen = $rightCursor - $leftCursor
		if (-not [string]::IsNullOrWhiteSpace($str)) {
			if ($rightCursor -eq 0 -and $leftCursor -eq 0) {
				Insert-PSConsoleReadLineText -TextToInsert $str
			}
			else {
				Replace-PSConsoleReadLineText -Start $leftCursor -Length ($replaceLen + 1) -ReplacementText $str
			}
		}
	}
}

function Get-PickedHistory($Query = '', [switch]$UsePSReadLineHistory) {
	try {
		$script:OverrideFzfDefaults = [FzfDefaultOpts]::new($env:FZF_CTRL_R_OPTS)

		$fileHist = @{}
		if ($UsePSReadLineHistory) {
			$reader = New-Object PSFzf.IO.ReverseLineReader -ArgumentList $((Get-PSReadlineOption).HistorySavePath)

			$result = $reader.GetEnumerator() | ForEach-Object `
				-Begin { $lines = @() } `
				-Process {
				if ([string]::IsNullOrWhiteSpace($_)) {
					# do nothing
				}
				elseif ($lines.Count -eq 0) {
					$lines = @($_) # start collecting lines
				}
				elseif ($_.EndsWith('`')) {
					$lines += $_.TrimEnd("`n").TrimEnd('`') # continue collecting lines with backtick
				}
				else {
					if ($lines.Length -eq 1) {
						$lines = $lines[0]
					}
					else {
						$lines = $lines[-1.. - ($lines.Length)] -join "`n"
					}
					# found a new line, so emit and start over:
					if (-not $fileHist.ContainsKey($lines)) {
						$fileHist.Add($lines, $true)
						$lines + [char]0
					}

					$lines = @($_)
				}
			} `
				-End {
				if ($lines.Length -eq 1) {
					$lines = $lines[0]
				}
				else {
					$lines = $lines[-1.. - ($lines.Length)] -join "`n"
				}
				# found a new line, so emit and start over:
				if (-not $fileHist.ContainsKey($lines)) {
					$fileHist.Add($lines, $true)
					$lines + [char]0
				}
			} | Invoke-Fzf -Query "$Query" -Bind ctrl-r:toggle-sort, ctrl-z:ignore -Scheme history -Read0 -HighlightLine
		}
		else {
			$result = Get-History | ForEach-Object { $_.CommandLine } | ForEach-Object {
				if (-not $fileHist.ContainsKey($_)) {
					$fileHist.Add($_, $true)
					$_
				}
			} | Invoke-Fzf -Query "$Query" -Reverse -Scheme history
		}

	}
	catch {
		# catch custom exception
	}
	finally {
		if ($script:OverrideFzfDefaults) {
			$script:OverrideFzfDefaults.Restore()
			$script:OverrideFzfDefaults = $null
		}

		# ensure that stream is closed:
		if ($reader) {
			$reader.Dispose()
		}
	}

	$result
}
function Invoke-FzfPsReadlineHandlerHistory {
	$result = $null
	$bufferState = Get-PSConsoleReadLineBufferState
	$line = $bufferState.Line
	$cursor = $bufferState.Cursor

	$result = Get-PickedHistory -Query $line -UsePSReadLineHistory

	InvokePromptHack

	if (-not [string]::IsNullOrEmpty($result)) {
		Replace-PSConsoleReadLineText -Start 0 -Length $line.Length -ReplacementText $result
	}
}

function Invoke-FzfPsReadlineHandlerHistoryArgs {
	$result = @()
	try {
		$bufferState = Get-PSConsoleReadLineBufferState
		$line = $bufferState.Line
		$cursor = $bufferState.Cursor
		$line = $line.Insert($cursor, "{}") # add marker for fzf

		$contentTable = @{}
		$reader = New-Object PSFzf.IO.ReverseLineReader -ArgumentList $((Get-PSReadlineOption).HistorySavePath)

		$fileHist = @{}
		$reader.GetEnumerator() | ForEach-Object {
			if (-not $fileHist.ContainsKey($_)) {
				$fileHist.Add($_, $true)
				[System.Management.Automation.PsParser]::Tokenize($_, [ref] $null)
			}
		} | Where-Object { $_.type -eq "commandargument" -or $_.type -eq "string" } |
		ForEach-Object {
			if (!$contentTable.ContainsKey($_.Content)) { $_.Content ; $contentTable[$_.Content] = $true }
		} | Invoke-Fzf -Multi | ForEach-Object { $result += $_ }
	}
	catch {
		# catch custom exception
	}
	finally {
		$reader.Dispose()
	}

	InvokePromptHack

	[array]$result = $result | ForEach-Object {
		# add quotes:
		if ($_.Contains(" ") -or $_.Contains("`t")) {
			"'{0}'" -f $_.Replace("'", "''")
		}
		else {
			$_
		}
	}
	if ($result.Length -ge 0) {
		Replace-PSConsoleReadLineText -Start $cursor -Length 0 -ReplacementText ($result -join ' ')
	}
}

function Invoke-FzfPsReadlineHandlerSetLocation {
	$result = $null
	try {
		$script:OverrideFzfDefaults = [FzfDefaultOpts]::new($env:FZF_ALT_C_OPTS)

		if ($null -eq $env:FZF_ALT_C_COMMAND) {
			Invoke-Expression (Get-FileSystemCmd . -dirOnly) | Invoke-Fzf | ForEach-Object { $result = $_ }
		}
		else {
			Invoke-Expression ($env:FZF_ALT_C_COMMAND) | Invoke-Fzf | ForEach-Object { $result = $_ }
		}
	}
	catch {
		# catch custom exception
	}
	finally {
		if ($script:OverrideFzfDefaults) {
			$script:OverrideFzfDefaults.Restore()
			$script:OverrideFzfDefaults = $null
		}
	}
	if (-not [string]::IsNullOrEmpty($result)) {
		& $script:AltCCommand -Location $result
		Invoke-PSConsoleReadLineAcceptLine
	}
	else {
		InvokePromptHack
	}
}

function SetPsReadlineShortcut($Chord, [switch]$Override, $BriefDesc, $Desc, [scriptblock]$scriptBlock) {
	if ([string]::IsNullOrEmpty($Chord)) {
		return $false
	}
	if ((Get-PSReadlineKeyHandler -Bound | Where-Object { $_.Key.ToLower() -eq $Chord }) -and -not $Override) {
		return $false
	}
	else {
		Set-PSReadlineKeyHandler -Key $Chord -Description $Desc -BriefDescription $BriefDesc -ScriptBlock $scriptBlock
		if ($(Get-PSReadLineOption).EditMode -eq [Microsoft.PowerShell.EditMode]::Vi) {
			Set-PSReadlineKeyHandler -Key $Chord -ViMode Command -Description $Desc -BriefDescription $BriefDesc -ScriptBlock $scriptBlock
		}
		return $true
	}
}


function FindFzf() {
	if ($script:IsWindows) {
		$AppNames = @('fzf.exe', 'fzf-*-windows_*.exe')
	}
	else {
		if ($IsMacOS) {
			$AppNames = @('fzf', 'fzf-*-darwin_*')
		}
		elseif ($IsLinux) {
			$AppNames = @('fzf', 'fzf-*-linux_*')
		}
		else {
			throw 'Unknown OS'
		}
	}

	# find it in our path:
	$script:FzfLocation = $null
	$AppNames | ForEach-Object {
		if ($null -eq $script:FzfLocation) {
			$result = Get-Command $_ -ErrorAction Ignore
			$result | ForEach-Object {
				$script:FzfLocation = Resolve-Path $_.Source
			}
		}
	}

	if ($null -eq $script:FzfLocation) {
		throw 'Failed to find fzf binary in PATH.  You can download a binary from this page: https://github.com/junegunn/fzf/releases'
	}
}

$PsReadlineShortcuts = @{
	PSReadlineChordProvider           = [PSCustomObject]@{
		'Chord'       = "$PSReadlineChordProvider"
		'BriefDesc'   = 'Fzf Provider Select'
		'Desc'        = 'Run fzf for current provider based on current token'
		'ScriptBlock' = { Invoke-FzfPsReadlineHandlerProvider }
	};
	PSReadlineChordReverseHistory     = [PsCustomObject]@{
		'Chord'       = "$PSReadlineChordReverseHistory"
		'BriefDesc'   = 'Fzf Reverse History Select'
		'Desc'        = 'Run fzf to search through PSReadline history'
		'ScriptBlock' = { Invoke-FzfPsReadlineHandlerHistory }
	};
	PSReadlineChordSetLocation        = @{
		'Chord'       = "$PSReadlineChordSetLocation"
		'BriefDesc'   = 'Fzf Set Location'
		'Desc'        = 'Run fzf to select directory to set current location'
		'ScriptBlock' = { Invoke-FzfPsReadlineHandlerSetLocation }
	};
	PSReadlineChordReverseHistoryArgs = @{
		'Chord'       = "$PSReadlineChordReverseHistoryArgs"
		'BriefDesc'   = 'Fzf Reverse History Arg Select'
		'Desc'        = 'Run fzf to search through command line arguments in PSReadline history'
		'ScriptBlock' = { Invoke-FzfPsReadlineHandlerHistoryArgs }
	};
	PSReadlineChordTabCompletion      = [PSCustomObject]@{
		'Chord'       = "Tab"
		'BriefDesc'   = 'Fzf Tab Completion'
		'Desc'        = 'Invoke Fzf for tab completion'
		'ScriptBlock' = { Invoke-TabCompletion }
	};
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
}
else {
	Write-Warning "PSReadline module not found - keyboard handlers not installed"
}

FindFzf

try {
	$fzfVersion = $(& $script:FzfLocation --version).Replace(' (devel)', '').Split('.')
	$script:UseHeightOption = $fzfVersion.length -ge 2 -and `
	([int]$fzfVersion[0] -gt 0 -or `
			[int]$fzfVersion[1] -ge 21) -and `
		$script:AnsiCompatible
	$script:UseWalker = $fzfVersion.length -ge 2 -and `
	([int]$fzfVersion[0] -gt 0 -or `
			[int]$fzfVersion[1] -ge 48)
}
catch {
	# continue
}

# check if we're running on Windows PowerShell. This method is faster than Get-Command:
if ($(get-host).Version.Major -le 5) {
	$script:PowershellCmd = 'powershell'
}
else {
	$script:PowershellCmd = 'pwsh'
}
