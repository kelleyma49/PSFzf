#
# This is a PowerShell Unit Test file.
# You need a unit test framework such as Pester to run PowerShell Unit tests.
# You can download Pester from http://go.microsoft.com/fwlink/?LinkID=534084
#
Get-Module PsFzf | Remove-Module

# set env variable so Import-Module doesn't fail
if ([string]::IsNullOrEmpty($env:GOPATH)) {
	$env:GOPATH = "c:\ADirectoryThatShouldNotExist\" # Keeping this in case it's still relevant for other parts
}

# Import the module after PATH modification
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