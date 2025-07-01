#
# This is a PowerShell Unit Test file.
# You need a unit test framework such as Pester to run PowerShell Unit tests.
# You can download Pester from http://go.microsoft.com/fwlink/?LinkID=534084
#
Get-Module PsFzf | Remove-Module

# set env variable so Import-Module doesn't fail:
if ([string]::IsNullOrEmpty($env:GOPATH)) {
	$env:GOPATH = "c:\ADirectoryThatShouldNotExist\"
}

Import-Module $(Join-Path $PSScriptRoot PSFzf.psd1) -ErrorAction Stop
Describe "Find-CurrentPath" {
	InModuleScope PsFzf {
		Context "Function Exists" {
			It "Should Return Nothing" {
				$line = "" ; $cursor = 0
				$leftCursor = $rightCursor = $null
				Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor) | Should -Be $null
				$leftCursor | Should -Be 0
				$rightCursor | Should -Be 0
			}

			It "Should Return Nothing with Spaces Cursor at Beginning" {
				$line = " " ; $cursor = 0
				$leftCursor = $rightCursor = $null
				Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor) | Should -Be " "
				$leftCursor | Should -Be 0
				$rightCursor | Should -Be 0
			}

			It "Should Return Nothing with Spaces Cursor at End" {
				$line = " " ; $cursor = 1
				$leftCursor = $rightCursor = $null
				Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor) | Should -Be " "
				$leftCursor | Should -Be 0
				$rightCursor | Should -Be 0
			}

			It "Should Return Path Cursor at Beginning for Single Char" {
				$line = "~" ; $cursor = 0
				$leftCursor = $rightCursor = $null
				Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor) | Should -Be "~"
				$leftCursor | Should -Be 0
				$rightCursor | Should -Be ($line.Length - 1)
			}

			It "Should Return Path Cursor at Beginning" {
				$line = "C:\Windows\" ; $cursor = 0
				$leftCursor = $rightCursor = $null
				Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor) | Should -Be "c:\Windows\"
				$leftCursor | Should -Be 0
				$rightCursor | Should -Be ($line.Length - 1)
			}

			It "Should Return Path Cursor at End" {
				$line = "C:\Windows\" ; $cursor = $line.Length
				$leftCursor = $rightCursor = $null
				Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor) | Should -Be "c:\Windows\"
				$leftCursor | Should -Be 0
				$rightCursor | Should -Be ($line.Length - 1)
			}

			It "Should Return Command and Path Cursor at Beginning" {
				$line = "cd C:\Windows\" ; $cursor = 0
				$leftCursor = $rightCursor = $null
				Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor) | Should -Be "cd"
				$leftCursor | Should -Be 0
				$rightCursor | Should -Be ('cd'.Length - 1)
			}

			It "Should Return Command and Path Cursor at End" {
				$line = "cd C:\Windows\" ; $cursor = $line.Length
				$leftCursor = $rightCursor = $null
				Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor) | Should -Be "c:\Windows\"
				$leftCursor | Should -Be 'cd '.Length
				$rightCursor | Should -Be ($line.Length - 1)
			}

			It "Should Return Command and Path Cursor at End" {
				$line = "cd C:\Windows\" ; $cursor = $line.Length - 1
				$leftCursor = $rightCursor = $null
				Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor) | Should -Be "c:\Windows\"
				$leftCursor | Should -Be 'cd '.Length
				$rightCursor | Should -Be ($line.Length - 1)
			}

			It "Should Return Path With Quotes Cursor at Beginning" -ForEach @(
				@{ Quote = '"' }
				@{ Quote = "'" }
			) {
				$line = $quote + 'C:\Program Files\' + $quote ; $cursor = 0
				$leftCursor = $rightCursor = $null
				Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor) | Should -Be 'C:\Program Files\'
				$leftCursor | Should -Be 0
				$rightCursor | Should -Be ($line.Length - 1)
			}
		}
	}
}

Describe "Invoke-FzfTabCompletion" {
    InModuleScope PsFzf {
        # Variables to store original values or mock states
        $Original_PSConsoleReadLineBufferState = $null
        $Original_CommandCompletion_CompleteInput = $null
        $Original_InvokeFzf = $null
        $Original_InsertPSConsoleReadLineText = $null
        $Original_ReplacePSConsoleReadLineText = $null
        $Original_InvokePromptHack = $null
        $Original_TestPath = $null
        $Original_JoinPath = $null # Added for Join-Path if it's used by the function for preview scripts
        $Original_Script_PSScriptRoot = $null

        # Variables for mock control / captured data
        $Mocked_CompleteInputResult = $null
        $script:PSScriptRootMock = "mocked/script/root" # Mocked $PsScriptRoot value
        $script:mockedBufferState = $null # Test sets this: @{ line = '...'; cursor = ... }
        $script:mockedCompletionResult = $null # Test sets this for [CommandCompletion]::CompleteInput
        $script:mockedFzfSelection = $null # Test sets this for Invoke-Fzf return
        $script:capturedInsertText = $null # For Insert-PSConsoleReadLineText
        $script:capturedReplaceArgs = $null # For Replace-PSConsoleReadLineText @{Start=;Length=;ReplacementText=}
        $script:mockedTestPathResult = $true # Default for Test-Path mock

        # Original script scope variables that might be modified by the function
        $Original_Script_TabContinuousTrigger = $null
        $Original_Script_Result = $null
        $Original_Script_ContinueCompletion = $null
        $Original_Script_FzfOutput = $null
        $Original_Script_CheckCompletion = $null
        $Original_Script_PowershellCmd = $null

        BeforeEach {
            # Save original commands and states
            $Original_PSConsoleReadLineBufferState = Get-Command Get-PSConsoleReadLineBufferState -ErrorAction SilentlyContinue
            # For static method, Pester 5+ handles this via its own mechanism. We store the mock object itself.
            # $Original_CommandCompletion_CompleteInput is conceptual; Pester stores/removes the static mock.
            $Original_InvokeFzf = Get-Command Invoke-Fzf -ErrorAction SilentlyContinue -Module PsFzf
            $Original_InsertPSConsoleReadLineText = Get-Command Insert-PSConsoleReadLineText -ErrorAction SilentlyContinue
            $Original_ReplacePSConsoleReadLineText = Get-Command Replace-PSConsoleReadLineText -ErrorAction SilentlyContinue
            $Original_InvokePromptHack = Get-Command InvokePromptHack -ErrorAction SilentlyContinue -Module PsFzf
            $Original_TestPath = Get-Command Test-Path -ErrorAction SilentlyContinue
            $Original_JoinPath = Get-Command Join-Path -ErrorAction SilentlyContinue

            # Save original script variables
            $Original_Script_TabContinuousTrigger = $script:TabContinuousTrigger
            $Original_Script_Result = $script:result
            $Original_Script_ContinueCompletion = $script:continueCompletion
            $Original_Script_FzfOutput = $script:fzfOutput
            $Original_Script_CheckCompletion = $script:checkCompletion
            $Original_Script_PowershellCmd = $script:PowershellCmd
            $Original_Script_PSScriptRoot = $PSScriptRoot # Save the actual PSScriptRoot if needed, though we usually mock its usage

            # Mock functions
            Mock Get-PSConsoleReadLineBufferState {
                return $script:mockedBufferState
            } -ModuleName PsFzf # Assuming it's part of the module, otherwise remove -ModuleName or use global scope

            # Pester 5+ static method mocking
            # This mock will be controlled by setting $script:mockedCompletionResult in each test.
            # $script:mockedCompletionResult should be an instance of [System.Management.Automation.CommandCompletion] or a ScriptBlock
            if ($Mocked_CompleteInputResult -and $Mocked_CompleteInputResult.IsBound) { Remove-Mock -Mock $Mocked_CompleteInputResult -ErrorAction SilentlyContinue }
            $Mocked_CompleteInputResult = Mock -StaticNamespace ([System.Management.Automation.CommandCompletion]) -MockWith {
                param($line, $cursor, $options, $powershell) # Match expected parameters
                if ($script:mockedCompletionResult -is [scriptblock]) {
                    # The scriptblock can use $line, $cursor, $options, $powershell if needed
                    Invoke-Command -ScriptBlock $script:mockedCompletionResult # -ArgumentList $line, $cursor, $options, $powershell (if scriptblock takes args)
                } else {
                    $script:mockedCompletionResult
                }
            } -Verifiable

            Mock Invoke-Fzf {
                # Param block should match the actual Invoke-Fzf to avoid errors if called with specific params
                param(
                    [Parameter(ValueFromPipeline = $true)]$InputObject,
                    [string]$Query = $null,
                    [string]$Prompt = '> ',
                    [string]$Header = $null,
                    [string]$Preview = $null,
                    [string]$PreviewWindow = 'right:50%',
                    [string]$Delimiter = '\n',
                    [string]$Key = $null,
                    [string]$Layout = 'default',
                    [string]$Cycle = $null,
                    [string]$Height = $null,
                    [string]$MinHeight = '10', # Default from function
                    [string]$Sort = 'score',
                    [string]$Tiebreak = 'score,index,end,begin', # Default from function
                    [string]$Expect = $null,
                    [string]$Theme = $null,
                    [string]$Color = $null,
                    [string]$Border = $null,
                    [string]$BorderStyle = 'round', # Default from function
                    [string]$Pointer = '> ', # Default from function
                    [string]$Marker = '> ', # Default from function
                    [string]$Info = 'default', # Default from function
                    [string]$History = $null,
                    [string]$HistorySize = '1000', # Default from function
                    [string]$FzfExtraArgs = $null,
                    [switch]$Multi,
                    [switch]$NoSort,
                    [switch]$Reverse,
                    [switch]$Select1,
                    [switch]$Exit0,
                    [switch]$Filter,
                    [switch]$PrintQuery,
                    [switch]$PreviewScript,
                    [switch]$CaseInsensitive,
                    [switch]$CaseSensitive,
                    [switch]$PathCompletion,
                    [switch]$Continuous,
                    [switch]$ShowHelp,
                    [switch]$NoPreview,
                    [switch]$NoHeaderLines,
                    [switch]$NoHeight
                )
                Write-Verbose "Invoke-Fzf mock called with InputObject: $($InputObject | Out-String), Query: $Query"
                return $script:mockedFzfSelection
            } -ModuleName PsFzf

            Mock Insert-PSConsoleReadLineText {
                param([string]$TextToInsert)
                $script:capturedInsertText = $TextToInsert
                Write-Verbose "Insert-PSConsoleReadLineText mock called with: $TextToInsert"
            } # Assuming global, adjust if module specific

            Mock Replace-PSConsoleReadLineText {
                param([int]$Start, [int]$Length, [string]$ReplacementText)
                $script:capturedReplaceArgs = @{Start = $Start; Length = $Length; ReplacementText = $ReplacementText}
                Write-Verbose "Replace-PSConsoleReadLineText mock called with: Start=$Start, Length=$Length, ReplacementText='$ReplacementText'"
            } # Assuming global, adjust if module specific

            Mock InvokePromptHack {
                Write-Verbose "InvokePromptHack mock called"
                # Do nothing
            } -ModuleName PsFzf

            $script:mockedTestPathResults = @{} # For more granular Test-Path control
            Mock Test-Path {
                param($PathValue, $PathType = 'Any') # Match common params
                Write-Verbose "Test-Path mock called with PathValue: $PathValue, PathType: $PathType"
                if ($script:mockedTestPathResults.ContainsKey($PathValue)) {
                    return $script:mockedTestPathResults[$PathValue]
                }
                return $script:mockedTestPathResult # Default return
            } -ModuleName PsFzf # Or global if preferred

            # Mock Join-Path to verify calls that might use the mocked PSScriptRoot
            # This is a simplistic Join-Path mock; real Join-Path is more complex.
            # Only mock if its behavior related to $PsScriptRoot needs to be controlled/verified.
            # Otherwise, direct use of Join-Path is fine.
            # Mock Join-Path {
            #     param($Path, $ChildPath)
            #     if ($Path -eq $script:PSScriptRootMock) {
            #         return "$($script:PSScriptRootMock)\$ChildPath"
            #     }
            #     # Fallback to actual Join-Path for other cases if needed, carefully
            #     return Microsoft.PowerShell.Management\Join-Path -Path $Path -ChildPath $ChildPath
            # }

            # Reset script scope variables that might be modified by the function or mocks
            $script:TabContinuousTrigger = "`t"
            $script:result = $null
            $script:continueCompletion = $true
            $script:fzfOutput = $null
            $script:checkCompletion = $null
            $script:PowershellCmd = "powershell.exe"
            # $PSScriptRoot is a readonly variable, its usage is mocked via mocking Join-Path or by
            # ensuring functions use a script-scoped variable that can be set, e.g. $script:MyModuleRoot = $PSScriptRoot
            # For this setup, we use $script:PSScriptRootMock and ensure any tested code that needs PSScriptRoot
            # is either using a mockable helper or we mock the command that uses it (like Join-Path above).

            # Initialize captured data stores
            $script:capturedInsertText = $null
            $script:capturedReplaceArgs = $null
            $script:mockedTestPathResults = @{}
        }

        AfterEach {
            # Restore original commands
            if ($Original_PSConsoleReadLineBufferState) { Remove-Mock -CommandName Get-PSConsoleReadLineBufferState -ModuleName PsFzf -ErrorAction SilentlyContinue }
            else { Remove-Mock -CommandName Get-PSConsoleReadLineBufferState -ErrorAction SilentlyContinue }

            if ($Mocked_CompleteInputResult) { Remove-Mock -Mock $Mocked_CompleteInputResult -ErrorAction SilentlyContinue }

            if ($Original_InvokeFzf) { Remove-Mock -CommandName Invoke-Fzf -ModuleName PsFzf -ErrorAction SilentlyContinue }
            if ($Original_InsertPSConsoleReadLineText) { Remove-Mock -CommandName Insert-PSConsoleReadLineText -ErrorAction SilentlyContinue }
            if ($Original_ReplacePSConsoleReadLineText) { Remove-Mock -CommandName Replace-PSConsoleReadLineText -ErrorAction SilentlyContinue }
            if ($Original_InvokePromptHack) { Remove-Mock -CommandName InvokePromptHack -ModuleName PsFzf -ErrorAction SilentlyContinue }
            if ($Original_TestPath) { Remove-Mock -CommandName Test-Path -ModuleName PsFzf -ErrorAction SilentlyContinue }
            else { Remove-Mock -CommandName Test-Path -ErrorAction SilentlyContinue } # If Test-Path was mocked globally
            # if ($Original_JoinPath) { Remove-Mock -CommandName Join-Path -ErrorAction SilentlyContinue }


            # Restore script scope variables to their original state
            $script:TabContinuousTrigger = $Original_Script_TabContinuousTrigger
            $script:result = $Original_Script_Result
            $script:continueCompletion = $Original_Script_ContinueCompletion
            $script:fzfOutput = $Original_Script_FzfOutput
            $script:checkCompletion = $Original_Script_CheckCompletion
            $script:PowershellCmd = $Original_Script_PowershellCmd
            # $PSScriptRoot = $Original_Script_PSScriptRoot # $PSScriptRoot is readonly, cannot be restored directly.
                                                            # Ensure tests clean up if they modified related script variables.

            # Clear mock control variables
            $script:mockedBufferState = $null
            $script:mockedCompletionResult = $null
            $script:mockedFzfSelection = $null
            $script:capturedInsertText = $null
            $script:capturedReplaceArgs = $null
            $script:mockedTestPathResult = $true
            $script:mockedTestPathResults = @{}
            $Mocked_CompleteInputResult = $null # Clear the stored mock object
        }

        Context "Basic Scenarios" {
            It "Should exist as a function" {
                Get-Command Invoke-FzfTabCompletion | Should -Not -Be $null
            }

            It "Inner function script:Invoke-FzfTabCompletionInner should exist" {
                Get-Command script:Invoke-FzfTabCompletionInner | Should -Not -Be $null
            }

            # More tests will be added here in subsequent steps
        }

        Context "Single Completion Scenarios" {
            It "Should return false and not call CompleteInput or Fzf if line is empty" {
                $script:mockedBufferState = @{ Line = ''; Cursor = 0 }
                $script:mockedCompletionResult = $null # Ensure no leftover mock data

                $result = script:Invoke-FzfTabCompletionInner
                $result | Should -BeFalse

                Should -Not -Invoke '[System.Management.Automation.CommandCompletion]::CompleteInput'
                Should -Not -Invoke 'Invoke-Fzf' -ModuleName 'PsFzf'
                Should -Not -Invoke 'Insert-PSConsoleReadLineText'
                Should -Not -Invoke 'Replace-PSConsoleReadLineText'
            }

            It "Should return false and not call CompleteInput if cursor is invalid" {
                $script:mockedBufferState = @{ Line = 'some text'; Cursor = -1 }
                $script:mockedCompletionResult = $null

                $result = script:Invoke-FzfTabCompletionInner
                $result | Should -BeFalse

                Should -Not -Invoke '[System.Management.Automation.CommandCompletion]::CompleteInput'
            }

            It "Should return false gracefully if CompleteInput throws an exception" {
                $script:mockedBufferState = @{ Line = 'git c'; Cursor = 5 }
                $script:mockedCompletionResult = { throw "Test Exception from CompleteInput" }

                $result = script:Invoke-FzfTabCompletionInner
                $result | Should -BeFalse

                Should -Invoke '[System.Management.Automation.CommandCompletion]::CompleteInput' -Times 1
                Should -Not -Invoke 'Invoke-Fzf' -ModuleName 'PsFzf'
            }

            It "Should return false and not call Fzf if CompleteInput returns no matches" {
                $script:mockedBufferState = @{ Line = 'git unknown'; Cursor = 11 }
                $emptyCompletionMatches = @()
                $script:mockedCompletionResult = [System.Management.Automation.CommandCompletion]::new($emptyCompletionMatches, 0, 0)

                $result = script:Invoke-FzfTabCompletionInner
                $result | Should -BeFalse

                Should -Invoke '[System.Management.Automation.CommandCompletion]::CompleteInput' -Times 1
                Should -Not -Invoke 'Invoke-Fzf' -ModuleName 'PsFzf'
            }
        }
    }
}

Describe 'Invoke-PsFzfRipgrep' {
    InModuleScope PsFzf {
        $OriginalPSFZF_RG_PREFIX = $null
        $script:CapturedCommand = $null
        # $script:MockedFzfDefaultCmd = $null # No longer needed
        $script:SystemOriginalFzfDefaultCommand = $null

        BeforeEach {
            # Store and clear environment variables
            $OriginalPSFZF_RG_PREFIX = $env:PSFZF_RG_PREFIX
            $env:PSFZF_RG_PREFIX = $null

            $script:SystemOriginalFzfDefaultCommand = $env:FZF_DEFAULT_COMMAND
            $env:FZF_DEFAULT_COMMAND = "SENTINEL_FZF_COMMAND_FOR_RESTORE_TEST"

            # Reset captured command
            $script:CapturedCommand = $null

            # Mock Invoke-Expression to capture the command
            Mock Invoke-Expression {
                param($Command)
                $script:CapturedCommand = $Command
                # Simulate fzf returning no selection to allow the function to complete
                return $null
            } -ModuleName PsFzf

            # Mock Get-EditorLaunch to prevent actual editor launch
            Mock Get-EditorLaunch {
                param($FileList, $LineNum = 0)
                # Do nothing, just prevent original function call
                return "MockedEditorLaunch $FileList $LineNum"
            } -ModuleName PsFzf

            # Mock Resolve-Path for -NoEditor switch
            Mock Resolve-Path {
                param($Path)
                return "Resolved_$Path" # Simulate path resolution
            } -ModuleName PsFzf

            # No more mocking of FzfDefaultCmd constructor or Restore method
        }

        AfterEach {
            # Restore environment variables
            $env:PSFZF_RG_PREFIX = $OriginalPSFZF_RG_PREFIX
            $env:FZF_DEFAULT_COMMAND = $script:SystemOriginalFzfDefaultCommand
        }

        Context 'Default rg command' {
            It 'Should use the default rg prefix and restore FZF_DEFAULT_COMMAND' {
                Invoke-PsFzfRipgrep -SearchString 'testsearch' | Out-Null

                $defaultRgPrefix = "rg --column --line-number --no-heading --color=always --smart-case "
                $script:CapturedCommand | Should -Match ([regex]::Escape($defaultRgPrefix))
                $env:FZF_DEFAULT_COMMAND | Should -Be "SENTINEL_FZF_COMMAND_FOR_RESTORE_TEST"
            }
        }

        Context 'Custom rg command via PSFZF_RG_PREFIX' {
            It 'Should use the custom rg prefix and restore FZF_DEFAULT_COMMAND' {
                $customRgPrefix = 'my-custom-rg --awesome '
                $env:PSFZF_RG_PREFIX = $customRgPrefix

                Invoke-PsFzfRipgrep -SearchString 'testsearch' | Out-Null

                $script:CapturedCommand | Should -Match ([regex]::Escape($customRgPrefix))
                $script:CapturedCommand | Should -Not -Match ([regex]::Escape("rg --column --line-number"))
                $env:FZF_DEFAULT_COMMAND | Should -Be "SENTINEL_FZF_COMMAND_FOR_RESTORE_TEST"
            }
        }

        Context 'NoEditor switch' {
            It 'Should call Resolve-Path, not Get-EditorLaunch, and restore FZF_DEFAULT_COMMAND' {
                # Override Invoke-Expression mock for this specific test to return a value
                Mock Invoke-Expression {
                    param($Command)
                    $script:CapturedCommand = $Command
                    return "somefile.txt:123:content" # Simulate fzf selection
                } -ModuleName PsFzf

                $result = Invoke-PsFzfRipgrep -SearchString 'testsearch' -NoEditor

                $result | Should -Be "Resolved_somefile.txt"
                Should -Invoke 'Resolve-Path' -Times 1 -ModuleName PsFzf -ParameterFilter { $Path -eq 'somefile.txt' }
                Should -Not -Invoke 'Get-EditorLaunch' -ModuleName PsFzf
                $env:FZF_DEFAULT_COMMAND | Should -Be "SENTINEL_FZF_COMMAND_FOR_RESTORE_TEST"
            }
        }

        Context 'Editor launch' {
            It 'Should call Get-EditorLaunch, not Resolve-Path, and restore FZF_DEFAULT_COMMAND' {
                # Override Invoke-Expression mock for this specific test to return a value
                Mock Invoke-Expression {
                    param($Command)
                    $script:CapturedCommand = $Command
                    return "anotherfile.txt:45:foobar" # Simulate fzf selection
                } -ModuleName PsFzf

                Invoke-PsFzfRipgrep -SearchString 'testsearch' | Out-Null

                Should -Invoke 'Get-EditorLaunch' -Times 1 -ModuleName PsFzf -ParameterFilter {
                    $FileList -eq 'anotherfile.txt' -and $LineNum -eq '45'
                }
                Should -Not -Invoke 'Resolve-Path' -ModuleName PsFzf
                $env:FZF_DEFAULT_COMMAND | Should -Be "SENTINEL_FZF_COMMAND_FOR_RESTORE_TEST"
            }
        }
    }
}

Describe 'Invoke-FuzzySetLocation' {
	InModuleScope PsFzf {

		BeforeAll {
			# Variables for mocks and environment restoration
			$Original_FZF_ALT_C_COMMAND = $null
			$TempTestDirectory = "temp_test_dir_ifsl" # IFSL for Invoke-FuzzySetLocation
			$ResolvedTempTestDirectory = ''
		}

		BeforeEach {
			# Save and clear FZF_ALT_C_COMMAND
			$Original_FZF_ALT_C_COMMAND = $env:FZF_ALT_C_COMMAND
			$env:FZF_ALT_C_COMMAND = $null

			# Create a temporary directory for tests that need filesystem interaction
			$ParentPath = if (Test-Path -Path "TestDrive:") { "TestDrive:" } else { $PSScriptRoot }
			$ResolvedTempTestDirectory = Join-Path $ParentPath $TempTestDirectory
			New-Item -ItemType Directory -Path $ResolvedTempTestDirectory -Force | Out-Null
			New-Item -ItemType Directory -Path (Join-Path $ResolvedTempTestDirectory "subdir1") -Force | Out-Null
			New-Item -ItemType Directory -Path (Join-Path $ResolvedTempTestDirectory "subdir2") -Force | Out-Null
			New-Item -ItemType File -Path (Join-Path $ResolvedTempTestDirectory "somefile.txt") -Force | Out-Null
		}

		AfterEach {
			# Restore FZF_ALT_C_COMMAND
			$env:FZF_ALT_C_COMMAND = $Original_FZF_ALT_C_COMMAND

			# Remove temporary directory - don't remove due to this error: https://github.com/pester/Pester/issues/1070
			Remove-Item -Path $ResolvedTempTestDirectory -Recurse -Force -ErrorAction SilentlyContinue

			# Clear specific mocks to avoid interference between tests
			# Commenting out Remove-Mock due to persistent CommandNotFoundException in this environment.
			# This is a workaround; ideally, Remove-Mock should function correctly.
			# Pester\Remove-Mock -CommandName 'Invoke-Fzf' -ModuleName 'PsFzf' -ErrorAction SilentlyContinue
			# Pester\Remove-Mock -CommandName 'Set-Location' -ModuleName 'PsFzf' -ErrorAction SilentlyContinue
		}

		Context 'When FZF_ALT_C_COMMAND is set and not empty' {
			It 'Should use FZF_ALT_C_COMMAND, pass its output to Invoke-Fzf, and set location to Invoke-Fzf result' {
				# Arrange
				$env:FZF_ALT_C_COMMAND = 'Write-Output "custom_path_from_alt_c"' # This command's output goes to Invoke-Fzf
				$script:expectedPathForFzfMock = "custom_path_from_alt_c_SELECTED" # What Invoke-Fzf mock will return

				Mock Invoke-Fzf {
					param([Parameter(ValueFromPipeline = $true)]$InputObject) # Match real signature somewhat
					Write-Warning "Invoke-Fzf mock called. Input type: $($InputObject.GetType().Name). Input: $InputObject"
					return $script:expectedPathForFzfMock
				} -ModuleName PsFzf

				Mock Set-Location { param($Path) Write-Warning "Set-Location mock called with: $Path" } -ModuleName PsFzf

				# Act
				$result = Invoke-FuzzySetLocation

				# Assert
				$result | Should -Be $script:expectedPathForFzfMock
				Should -Invoke 'Invoke-Fzf' -Times 1 -ModuleName 'PsFzf' # Corrected assertion
				Should -Invoke 'Set-Location' -Times 1 -ModuleName 'PsFzf' -ParameterFilter { $Path -eq $script:expectedPathForFzfMock } # Corrected assertion
			}
		}

		Context 'When FZF_ALT_C_COMMAND is not set' {
			It 'Should use default Get-ChildItem command, pass its output to Invoke-Fzf, and set location to Invoke-Fzf result' {
				# Arrange
				$env:FZF_ALT_C_COMMAND = $null # Ensure it's null
				$script:expectedPathForFzfMock = Join-Path $ResolvedTempTestDirectory "subdir1_SELECTED" # Example selection from fzf

				Mock Invoke-Fzf {
					param([Parameter(ValueFromPipeline = $true)]$InputObject)
					Write-Warning "Invoke-Fzf mock (default case) called. Input type: $($InputObject.GetType().Name). Input count: $(if ($InputObject) {@($InputObject).Count} else {0})"
					return $script:expectedPathForFzfMock
				} -ModuleName PsFzf
				Mock Set-Location { param($Path) Write-Warning "Set-Location mock (default case) called with: $Path" } -ModuleName PsFzf

				# Act
				$result = Invoke-FuzzySetLocation -Directory $ResolvedTempTestDirectory

				# Assert
				$result | Should -Be $script:expectedPathForFzfMock
				Should -Invoke 'Invoke-Fzf' -Times 1 -ModuleName 'PsFzf' # Corrected assertion
				Should -Invoke 'Set-Location' -Times 1 -ModuleName 'PsFzf' -ParameterFilter { $Path -eq $script:expectedPathForFzfMock } # Corrected assertion
			}
		}

		Context 'When FZF_ALT_C_COMMAND is set to an empty string' {
			It 'Should use default Get-ChildItem command (like FZF_ALT_C_COMMAND not set)' {
				# Arrange
				$env:FZF_ALT_C_COMMAND = "" # Empty string
				$script:expectedPathForFzfMock = Join-Path $ResolvedTempTestDirectory "subdir2_SELECTED" # Example selection from fzf

				Mock Invoke-Fzf {
					param([Parameter(ValueFromPipeline = $true)]$InputObject)
					Write-Warning "Invoke-Fzf mock (empty alt_c) called. Input type: $($InputObject.GetType().Name). Input count: $(if ($InputObject) {@($InputObject).Count} else {0})"
					return $script:expectedPathForFzfMock
				} -ModuleName PsFzf
				Mock Set-Location { param($Path) Write-Warning "Set-Location mock (empty alt_c) called with: $Path" } -ModuleName PsFzf

				# Act
				$result = Invoke-FuzzySetLocation -Directory $ResolvedTempTestDirectory

				# Assert
				$result | Should -Be $script:expectedPathForFzfMock
				Should -Invoke 'Invoke-Fzf' -Times 1 -ModuleName 'PsFzf' # Corrected assertion
				Should -Invoke 'Set-Location' -Times 1 -ModuleName 'PsFzf' -ParameterFilter { $Path -eq $script:expectedPathForFzfMock } # Corrected assertion
			}
		}
	}
}

Describe 'Invoke-FuzzyZLocation' {
	InModuleScope PsFzf {
		BeforeAll {
			# simulate functions so we don't have to load module:
			if ($null -eq ${function:Get-ZLocation}) {
				${function:Get-ZLocation} = {}
			}
			if ($null -eq ${function:Set-ZLocation}) {
				${function:Set-ZLocation} = {}
			}

			# For Invoke-FuzzyZLocation tests, always mock Get-ZLocation to return a consistent dataset.
			# This makes tests independent of the actual ZLocation database state.
			Mock Get-ZLocation {
				Write-Warning "Mocked Get-ZLocation (providing consistent test data)"
				return @{
					'/path/to/projectA'         = 10;
					'/path/to/another/projectB' = 5;
					'/another/path/to/C'        = 15;
				}
			} -ModuleName PsFzf

			# Mock Set-ZLocation if it doesn't exist, or use a simple pass-through mock if it does.
			# This command is not directly asserted in these tests but might be called by other ZLocation logic.
			if (-not (Get-Command Set-ZLocation -ErrorAction SilentlyContinue)) {
				Mock Set-ZLocation {
					param($Path)
					Write-Warning "Mocked Set-ZLocation (original not found) called with: $Path"
				} -ModuleName PsFzf
			}
			else {
				# If it exists, we can still mock it to prevent actual DB writes if desired,
				# or let the original run if operations are idempotent and don't affect other tests.
				# For simplicity, let's just ensure it's available or minimally mocked.
				Mock Set-ZLocation {
					param($Path)
					Write-Warning "Mocked Set-ZLocation (original MAY exist, simple log) called with: $Path"
					# Optionally call original: & (Get-Command Set-ZLocation -ErrorAction Stop) @PSBoundParameters
				} -ModuleName PsFzf
			}
		}

		BeforeEach {
			# Common mocks for Invoke-FuzzyZLocation tests
			# These script-scoped variables are reset in AfterEach
			$script:StaticCollectedInputForAllMockCallsInTest = @()
			$script:StaticFzfQueryArgValue = $null
			$script:StaticFzfNoSortArgValue = $null
			$script:StaticActualInvokeFzfBeginCount = 0
			$script:StaticActualInvokeFzfProcessCount = 0
			$script:StaticActualInvokeFzfEndCount = 0

			Mock Invoke-Fzf {
				[CmdletBinding()]
				param(
					[Parameter(ValueFromPipeline = $true)] $InputObject,
					[string]$Query = $null,
					[switch]$NoSort
				)
				begin {
					$script:StaticActualInvokeFzfBeginCount++
					# Parameters should be consistent for a single logical pipeline invocation
					if ($script:StaticActualInvokeFzfBeginCount -eq 1) {
						$script:StaticFzfQueryArgValue = $Query
						$script:StaticFzfNoSortArgValue = $NoSort.IsPresent
					}
					Write-Warning "Invoke-Fzf MOCK ---BEGIN--- CallNo: $($script:StaticActualInvokeFzfBeginCount). Query: '$Query'. NoSort: '$($NoSort.IsPresent)'"
				}
				process {
					$script:StaticActualInvokeFzfProcessCount++
					if ($null -ne $InputObject) {
						# Ensure robust array accumulation
						$script:StaticCollectedInputForAllMockCallsInTest = @($script:StaticCollectedInputForAllMockCallsInTest) + $InputObject
					}
					Write-Warning "Invoke-Fzf MOCK ---PROCESS--- ItemNo: $($script:StaticActualInvokeFzfProcessCount). Input: '$InputObject'. Static collected now: $($script:StaticCollectedInputForAllMockCallsInTest.Count)"
				}
				end {
					$script:StaticActualInvokeFzfEndCount++
					Write-Warning "Invoke-Fzf MOCK ---END--- CallNo: $($script:StaticActualInvokeFzfEndCount). Total static collected: $($script:StaticCollectedInputForAllMockCallsInTest.Count). Query was: '$($script:StaticFzfQueryArgValue)'"

					# THE RETURN LOGIC NOW ONLY HAPPENS ON THE *LAST* EXPECTED CALL
					# AND OPERATES ON THE FULLY ACCUMULATED LIST
					# This assumes Get-ZLocation (mocked) provides 3 items.
					if ($script:StaticActualInvokeFzfEndCount -eq 3) {
						if ($script:StaticFzfQueryArgValue -eq 'projectA') {
							return '/path/to/projectA_SELECTED'
						}
						elseif ($script:StaticFzfQueryArgValue -eq 'nonexistent') {
							return $null
						}

						if ($script:StaticCollectedInputForAllMockCallsInTest.Count -gt 0 -and (-not $script:StaticFzfQueryArgValue)) {
							# First item of the *accumulated and sorted* list
							if ($script:StaticCollectedInputForAllMockCallsInTest[0] -eq '/another/path/to/C') {
								return '/another/path/to/C_SELECTED'
							}
						}
						# Fallback based on accumulated data if necessary
						if ($script:StaticCollectedInputForAllMockCallsInTest.Count -gt 0) {
							return $script:StaticCollectedInputForAllMockCallsInTest[0] + "_fallback_SELECTED"
						}
						return '/path/to/default/empty_input_SELECTED'
					}
					return $null # Intermediate "end" calls return nothing, so they don't pollute $result in Invoke-FuzzyZLocation
				}
			} -ModuleName PsFzf

			Mock Set-Location { param($Path) Write-Warning "Set-Location mock (Invoke-FuzzyZLocation specific) called with: $Path" } -ModuleName PsFzf
		}

		AfterEach {
			# Clear mocks after each test
			# Pester\Remove-Mock -CommandName 'Get-ZLocation' -ModuleName 'PsFzf' -ErrorAction SilentlyContinue
			# Pester\Remove-Mock -CommandName 'Invoke-Fzf' -ModuleName 'PsFzf' -ErrorAction SilentlyContinue
			# Pester\Remove-Mock -CommandName 'Set-Location' -ModuleName 'PsFzf' -ErrorAction SilentlyContinue
			$script:StaticCollectedInputForAllMockCallsInTest = @()
			$script:StaticFzfQueryArgValue = $null
			$script:StaticFzfNoSortArgValue = $null
			$script:StaticActualInvokeFzfBeginCount = 0
			$script:StaticActualInvokeFzfProcessCount = 0
			$script:StaticActualInvokeFzfEndCount = 0
		}

		Context 'When no query is provided' {
			It 'Should process ZLocation entries, pass them to Invoke-Fzf, and set location to the result' {
				# Diagnostic: See what Get-ZLocation returns in this context
				$actualZOutput = Get-ZLocation
				Write-Warning "Test 'When no query is provided': Get-ZLocation returned: $($actualZOutput | ConvertTo-Json -Depth 3 -Compress)"

				# Act
				Invoke-FuzzyZLocation

				# Assert
				Should -Invoke 'Get-ZLocation' -Times 1 -ModuleName 'PsFzf'
				# Even if mock is called 3 times, these parameters should be consistent from the first call
				$script:StaticFzfQueryArgValue | Should -BeNullOrEmpty
				$script:StaticFzfNoSortArgValue | Should -BeTrue

				# Verify the items accumulated by Invoke-Fzf mock are the sorted keys
				$expectedArray = @('/another/path/to/C', '/path/to/projectA', '/path/to/another/projectB')
				$script:StaticCollectedInputForAllMockCallsInTest | Should -Be $expectedArray

				# Check that Set-Location was called with the item fzf mock would return on its final call
				Should -Invoke 'Set-Location' -Times 1 -ModuleName 'PsFzf' -ParameterFilter { $Path -eq '/another/path/to/C_SELECTED' }
			}
		}

		Context 'When a query is provided' {
			It 'Should pass the query to Invoke-Fzf and set location to the result' {
				# Arrange
				$testQuery = 'projectA'

				# Act
				Invoke-FuzzyZLocation -Query $testQuery

				# Assert
				Should -Invoke 'Get-ZLocation' -Times 1 -ModuleName 'PsFzf'
				$script:StaticFzfQueryArgValue | Should -Be $testQuery
				$script:StaticFzfNoSortArgValue | Should -BeTrue
				$script:StaticCollectedInputForAllMockCallsInTest.Count | Should -Be 3 # Still processes all 3 items
				Should -Invoke 'Set-Location' -Times 1 -ModuleName 'PsFzf' -ParameterFilter { $Path -eq '/path/to/projectA_SELECTED' }
			}
		}

		Context 'When Invoke-Fzf returns no selection' {
			It 'Should not call Set-Location' {
				# Arrange
				$testQuery = 'nonexistent' # This query will make Invoke-Fzf mock return $null

				# Act
				Invoke-FuzzyZLocation -Query $testQuery

				# Assert
				Should -Invoke 'Get-ZLocation' -Times 1 -ModuleName 'PsFzf'
				$script:StaticFzfQueryArgValue | Should -Be $testQuery
				$script:StaticCollectedInputForAllMockCallsInTest.Count | Should -Be 3
				Should -Not -Invoke 'Set-Location' -ModuleName 'PsFzf'
			}
		}
	}
}


Describe "Add-BinaryModuleTypes" {
	InModuleScope PsFzf {
		Context "Module Loaded" {
			It "Be Able to Create Type" {
				$filePath = Join-Path ([system.io.path]::GetTempPath()) 'TestFile.txt'
				1..100 | Add-Content $filePath
				$newObject = New-Object PSFzf.IO.ReverseLineReader -ArgumentList $filePath
				$newObject | Should -Not -Be $null
			}
		}
	}
}

Describe "Check FixCompletionResult" {
	InModuleScope PsFzf {
		Context "Non-quoted Strings Should Not Change" {
			It "Check Simple String" {
				FixCompletionResult("not_quoted") | Should -Be "not_quoted"
			}
			It "Check Simple String with quote" {
				FixCompletionResult("not_quotedwith'") | Should -Be "not_quotedwith'"
			}
		}

		Context "Non-quoted Strings With Spaces Should Change" {
			It "Check Simple String With Space" {
				FixCompletionResult("with space") | Should -Be """with space"""
			}
			It "Check Simple String with quote" {
				FixCompletionResult("with space, ' and with'") | Should -Be """with space, ' and with'"""
			}
		}

		Context "Quoted Strings Should Not Change" {
			It "Check Simple String With Space and Already Double Quoted" {
				FixCompletionResult("""with space and already quoted""") | Should -Be """with space and already quoted"""
			}

			It "Check Simple String With Space and Already Single Quoted" {
				FixCompletionResult("'with space and already quoted'") | Should -Be "'with space and already quoted'"
			}
		}
	}
}

Describe "Check Parameters" {
	InModuleScope PsFzf {
		Context "Parameters Should Fail" {
			It "Borders Should -Be Mutally Exclusive" {
				{ $_ = '' | Invoke-Fzf -Border -BorderStyle 'sharp' } |
				Should -Throw '*are mutally exclusive*'
			}

			It "Validate Tiebreak" {
				{ $_ = '' | Invoke-Fzf -Tiebreak 'Tiebreak' } |
				Should -Throw 'Cannot validate argument on parameter ''Tiebreak''*'
			}

			It "Validate BorderStyle" {
				{ $_ = '' | Invoke-Fzf -BorderStyle 'InvalidStyle' } |
				Should -Throw 'Cannot validate argument on parameter ''BorderStyle''*'
			}

			It "Validate Info" {
				{ $_ = '' | Invoke-Fzf -Info 'InvalidInfo' } |
				Should -Throw 'Cannot validate argument on parameter ''Info''*'
			}

			It "Validate Height Pattern Percentage" {
				{ $_ = '' | Invoke-Fzf -Height '1000%' } |
				Should -Throw 'Cannot validate argument on parameter ''Height''*'
			}

			It "Validate Height Pattern Non-Number" {
				{ $_ = '' | Invoke-Fzf -Height 'adf1000' } |
				Should -Throw 'Cannot validate argument on parameter ''Height''*'
			}

			It "Validate Height Pattern Negative" {
				{ $_ = '' | Invoke-Fzf -Height '-1' } |
				Should -Throw 'Cannot validate argument on parameter ''Height''*'
			}

			It "Validate MinHeight Pattern Non-Number" {
				{ $_ = '' | Invoke-Fzf -MinHeight 'adf1' -Height 10 } |
				Should -Throw 'Cannot process argument transformation on parameter ''MinHeight''*'
			}

			It "Validate MinHeight Pattern Negative" {
				{ $_ = '' | Invoke-Fzf -MinHeight '-1' -Height 10 } |
				Should -Throw 'Cannot validate argument on parameter ''MinHeight''*'
			}

		}
	}
}

Describe "Get-EditorLaunch" {


	InModuleScope PSFzf {
		Context "Vim" {
			BeforeEach {
				$env:PSFZF_EDITOR_OPTIONS = $null
				$env:VSCODE_PID = $null
				$env:VISUAL = $null
				$env:EDITOR = $null

				$testFile1 = Join-Path $TestDrive 'somefile1.txt'
				Set-Content -Path $testFile1 -Value "hello 1"
				$testFile2 = Join-Path $TestDrive 'somefile2.txt'
				Set-Content -Path $testFile2 -Value "hello 2"
			}

			It "Should Return vim Single" {
				$env:EDITOR = 'vim'
				Get-EditorLaunch $testFile1 | Should -Be "vim ""$testFile1"" +0"
			}

			It "Should Return vim Single With Quotes" {
				$env:EDITOR = 'vim'
				Get-EditorLaunch """$testFile1""" | Should -Be "vim ""$testFile1"" +0"
			}

			It "Should Return vim Single With Options" {
				$env:EDITOR = 'vim'
				$env:PSFZF_EDITOR_OPTIONS = "--clean"
				Get-EditorLaunch $testFile1 | Should -Be "vim --clean ""$testFile1"" +0"
			}

			It "Should Return vim Single with Line Number" {
				$env:EDITOR = 'vim'
				Get-EditorLaunch $testFile1 -LineNum 101 | Should -Be "vim ""$testFile1"" +101"
			}

			It "Should Return vim Multiple" {
				$env:EDITOR = 'vim'
				Get-EditorLaunch @($testFile1, $testFile2) | Should -Be "vim ""$testFile1"" ""$testFile2"""
			}

			It "Should Return vim Multiple With Quotes" {
				$env:EDITOR = 'vim'
				Get-EditorLaunch @("""$testFile1""", """$testFile2""") | Should -Be "vim ""$testFile1"" ""$testFile2"""
			}

			It "Should Return code Single" {
				$env:EDITOR = 'code'
				Get-EditorLaunch $testFile1 | Should -Be $('code --goto "{0}:0"' -f $testFile1)
			}

			It "Should Return code Single With Quotes" {
				$env:EDITOR = 'code'
				Get-EditorLaunch """$testFile1""" | Should -Be $('code --goto "{0}:0"' -f $testFile1)
			}

			It "Should Return code Single Reuse Window" {
				$env:EDITOR = 'code'
				$env:VSCODE_PID = 100
				Get-EditorLaunch $testFile1 | Should -Be $('code --reuse-window --goto "{0}:0"' -f $testFile1)
			}

			It "Should Return code Single with Line Number" {
				$env:EDITOR = 'code'
				Get-EditorLaunch $testFile1 -LineNum 100 | Should -Be $('code --goto "{0}:100"' -f $testFile1)
			}

			It "Should Return code Multiple" {
				$env:EDITOR = 'code'
				Get-EditorLaunch @($testFile1, $testFile2) | Should -Be "code ""$testFile1"" ""$testFile2"""
			}

			It "Should Return code Multiple With Quotes" {
				$env:EDITOR = 'code'
				Get-EditorLaunch @("""$testFile1""", """$testFile2""") | Should -Be "code ""$testFile1"" ""$testFile2"""
			}
		}
	}
}
# CI seems to have problems on GitHub CI - timing issues?
if ( $false ) {

	Describe "Invoke-Fzf" {
		InModuleScope PsFzf {
			Context "Function Exists" {
				It "Should Return Nothing" {
					$result = '' | Invoke-Fzf -Query 'file1.txt' -Select1 -Exit0 -Filter ' '
					$result | Should -Be $null
				}

				It "Should Return 1 Item, 1 Element" {
					$result = 'file1.txt' | Invoke-Fzf -Select1 -Exit0 -Filter 'file1.txt'
					$result | Should -Be 'file1.txt'
				}

				It "Should Return 1 Item, Case Insensitive" {
					$result = 'file1.txt' | Invoke-Fzf -Select1 -Exit0 -CaseInsensitive -Filter 'FILE1.TXT'
					$result | Should -Be 'file1.txt'
				}

				It "Should Return Nothing, Case Sensitive" {
					$result = 'file1.txt' | Invoke-Fzf -Select1 -Exit0 -CaseSensitive -Filter 'FILE1.TXT'
					$result | Should -Be $null
				}

				It "Should Return 1 Item, No Multi" {
					$result = 'file1.txt', 'file2.txt' | Invoke-Fzf -Multi -Select1 -Exit0 -Filter "file1"
					$result | Should -Be 'file1.txt'
				}

				It "Should Return 2 Item, Multi" {
					$result = 'file1.txt', 'file2.txt' | Invoke-Fzf -Multi -Select1 -Exit0 -Filter "file"
					$result.Length | Should -Be 2
					$result[0] | Should -Be 'file1.txt'
					$result[1] | Should -Be 'file2.txt'
				}
			}
		}
	}
}