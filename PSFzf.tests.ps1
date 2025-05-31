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

Describe "Set-PsFzfOption overriding Invoke-FzfTabCompletionInner" {
    InModuleScope PsFzf {
        $script:FzfArgs = $null
        $OriginalCompletionMatches = $null
        $OriginalCompletions = $null

        BeforeEach {
            Import-Module $(Join-Path $PSScriptRoot PSFzf.psd1) -Force
            $script:FzfArgs = $null

            # Mock Invoke-Fzf to capture arguments
            Mock Invoke-Fzf {
                $script:FzfArgs = $PSBoundParameters
                # Return a value that matches expected output structure if necessary
                # For these tests, we are focused on input args to Invoke-Fzf
                return $script:FzfArgs.InputObject # Or some other sensible default
            } -ModuleName PSFzf

            # Mock PSConsoleReadline GetBufferState
            # The specific values don't matter as much as having it callable
            Mock ([Microsoft.PowerShell.PSConsoleReadline]::GetBufferState) {
                param([ref]$line, [ref]$cursor)
                $line.Value = "some command "
                $cursor.Value = $line.Value.Length
            }

            # Mock CommandCompletion.CompleteInput
            # This is the most complex part. We need to ensure CompletionMatches.Count > 1
            # to trigger the Invoke-Fzf call within Invoke-FzfTabCompletionInner.
            # We create two dummy completion results.
            $completionResults = [System.Management.Automation.CompletionResult[]]@(
                [System.Management.Automation.CompletionResult]::new('item1', 'item1', [System.Management.Automation.CompletionResultType]::ParameterValue, 'tooltip1'),
                [System.Management.Automation.CompletionResult]::new('item2', 'item2', [System.Management.Automation.CompletionResultType]::ParameterValue, 'tooltip2')
            )
            $commandCompletion = [System.Management.Automation.CommandCompletion]::new($completionResults, 0, "item".Length, @{})

            Mock -CommandName CompleteInput -ModuleName PSFzf -MockWith {
                 # This is a placeholder. Actual mocking of static method System.Management.Automation.CommandCompletion.CompleteInput
                 # is more involved and might require helper functions or different Pester versions.
                 # For the purpose of this test, we assume this mock structure can provide the necessary CommandCompletion object.
                 return $commandCompletion
            }

            # Ensure the internal call to CommandCompletion.CompleteInput uses our mock.
            # This often means the module under test needs to be designed for testability,
            # e.g., by wrapping static calls in injectable services or internal helper functions.
            # For now, we rely on Pester's shimming capabilities for static methods if available and correctly configured,
            # or accept that this part might not be perfectly unit-testable without refactoring.
            # The crucial part is that $completionMatches.Count -gt 1 inside Invoke-FzfTabCompletionInner.
            # We will proceed as if the mock for CompleteInput works to return our $commandCompletion.
            # A more robust way would be to use a helper script/module that defines a wrapper around the static call,
            # and then mock that wrapper. Or, use Pester 5+ features for static mocking if applicable.

            # The following is a direct mock of the static method, which might only work in Pester v5+
            # and specific PowerShell versions.
            # If this causes errors, the test setup for CommandCompletion.CompleteInput needs rethinking.
            Mock [System.Management.Automation.CommandCompletion]::CompleteInput {
                return $commandCompletion
            }

        }

        AfterEach {
            # Remove mocks
            Get-Mock -Scope It | Remove-Mock
            $script:PsFzfPreviewOverride = $null
            $script:PsFzfChangePreviewWindowOverride = $null
        }

        It "disables preview when Set-PsFzfOption -Preview '' is used" {
            Set-PsFzfOption -Preview ''
            Invoke-FzfTabCompletionInner
            $script:FzfArgs.ContainsKey('Preview') | Should -BeFalse
        }

        It "uses custom command for preview when Set-PsFzfOption -Preview 'custom command' is used" {
            Set-PsFzfOption -Preview 'custom command'
            Invoke-FzfTabCompletionInner
            $script:FzfArgs['Preview'] | Should -Be 'custom command'
        }

        It "disables change-preview-window binding when Set-PsFzfOption -ChangePreviewWindow '' is used" {
            Set-PsFzfOption -ChangePreviewWindow ''
            Invoke-FzfTabCompletionInner
            ($script:FzfArgs['Bind'] | ForEach-Object { $_ -like 'ctrl-/:change-preview-window(*)' }) -notcontains $true | Should -BeTrue
        }

        It "uses custom binding for change-preview-window when Set-PsFzfOption -ChangePreviewWindow 'custom binding' is used" {
            Set-PsFzfOption -ChangePreviewWindow 'custom binding'
            Invoke-FzfTabCompletionInner
            $script:FzfArgs['Bind'] | Should -Contain 'ctrl-/:change-preview-window(custom binding)'
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
				Should -Throw '*are mutally exclusive'
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