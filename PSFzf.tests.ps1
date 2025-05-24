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

# Initialize call trackers for Invoke-FuzzyZLocation tests
$script:setLocationCalls = @()
$script:invokeFzfCalls = @()
$script:writeWarningCalls = @()

Describe "Invoke-FuzzyZLocation" {
    InModuleScope PsFzf {
        BeforeEach {
            $script:setLocationCalls = @()
            $script:invokeFzfCalls = @()
            $script:writeWarningCalls = @()

            # Default Mocks
            Mock Get-ZLocation { return @{'/path/defaultA' = 1; '/path/defaultB' = 2} } -Global | Out-Null
            Mock Set-Location { param($Path) $script:setLocationCalls += $Path } -Global | Out-Null
            
            Mock Invoke-Fzf {
                param(
                    [Parameter(ValueFromPipeline)]
                    $InputObject,
                    $Query,
                    $NoSort
                )
                begin { $collectedInput = @() }
                process { if ($null -ne $InputObject) { $collectedInput += $InputObject } }
                end {
                    $script:invokeFzfCalls += @{ Query = $Query; NoSort = $NoSort; InputPassedToFzf = $collectedInput }
                    # Default: return first item from collected input if any, to simulate selection
                    if ($collectedInput.Count -gt 0) {
                        return $collectedInput[0]
                    }
                    return $null
                }
            } -Global | Out-Null # Changed from -ModuleName PSFzf to -Global
            
            Mock Write-Warning { param($Message) $script:writeWarningCalls += $Message } -Global | Out-Null
        }

        Context "When no query is provided" {
            It "should call Invoke-Fzf without a query, with sorted paths, and Set-Location with the result" {
                Mock Get-ZLocation { return @{'/path/low_freq' = 5; '/path/high_freq' = 10; '/path/mid_freq' = 7} } -Global | Out-Null
                # Invoke-Fzf mock will by default return '/path/high_freq' (first after sort by value desc)
                
                Invoke-FuzzyZLocation
                
                $script:invokeFzfCalls.Count | Should -Be 1
                $script:invokeFzfCalls[0].Query | Should -BeNullOrEmpty
                $script:invokeFzfCalls[0].NoSort | Should -BeTrue # Verify -NoSort is passed
                
                # Expected input to Invoke-Fzf based on sorting by value (frequency/recency)
                $expectedFzfInput = @('/path/high_freq', '/path/mid_freq', '/path/low_freq') 
                $script:invokeFzfCalls[0].InputPassedToFzf | Should -BeExactly $expectedFzfInput
                
                $script:setLocationCalls.Count | Should -Be 1
                $script:setLocationCalls[0] | Should -Be '/path/high_freq' # Because Invoke-Fzf mock returns the first item
            }
        }

        Context "When a query is provided" {
            It "navigates directly if the query uniquely matches a path" {
                Mock Get-ZLocation { return @{'/home/user/projectUnique' = 10; '/tmp/another' = 5; '/home/user/anotherUnique' = 1 } } -Global | Out-Null
                
                Invoke-FuzzyZLocation -Query "projectUnique"
                
                $script:setLocationCalls.Count | Should -Be 1
                $script:setLocationCalls[0] | Should -Be '/home/user/projectUnique'
                $script:invokeFzfCalls.Count | Should -Be 0
            }

            It "calls Invoke-Fzf with the query if multiple paths match" {
                $zLocationData = @{
                    '/user/work/projectA' = 10
                    '/user/dev/projectB' = 5
                    '/opt/other' = 1
                    '/root/projectC' = 12 # Highest frequency, but Invoke-Fzf mock below will return projectA
                }
                Mock Get-ZLocation { return $zLocationData } -Global | Out-Null
                
                # Specific mock for Invoke-Fzf for this test to control its return value
                Mock Invoke-Fzf {
                    param(
                        [Parameter(ValueFromPipeline)]
                        $InputObject,
                        $Query,
                        $NoSort
                    )
                    begin { $collectedInput = @() }
                    process { if ($null -ne $InputObject) { $collectedInput += $InputObject } }
                    end {
                    $script:invokeFzfCalls += @{ Query = $Query; NoSort = $NoSort; InputPassedToFzf = $collectedInput }
                        if ($Query -eq "project") { return '/user/work/projectA' } # Simulate selection
                        return $null
                    }
                } -Global | Out-Null # Changed from -ModuleName PSFzf to -Global

                Invoke-FuzzyZLocation -Query "project"

                $script:invokeFzfCalls.Count | Should -Be 1
                $script:invokeFzfCalls[0].Query | Should -Be "project"
                $script:invokeFzfCalls[0].NoSort | Should -BeTrue
                
                # Input to FZF should still be all paths from ZLocation, sorted by value
                $expectedFzfInput = @('/root/projectC', '/user/work/projectA', '/user/dev/projectB', '/opt/other')
                $script:invokeFzfCalls[0].InputPassedToFzf | Should -BeExactly $expectedFzfInput

                $script:setLocationCalls.Count | Should -Be 1
                $script:setLocationCalls[0] | Should -Be '/user/work/projectA'
            }
            
            It "calls Invoke-Fzf with the query if no paths match" {
                Mock Get-ZLocation { return @{'/user/work/projectA' = 10; '/user/dev/projectB' = 5} } -Global | Out-Null
                # Specific mock for Invoke-Fzf to return null (user cancels)
                Mock Invoke-Fzf {
                    param(
                        [Parameter(ValueFromPipeline)]
                        $InputObject,
                        $Query,
                        $NoSort
                    )
                    begin { $collectedInput = @() }
                    process { if ($null -ne $InputObject) { $collectedInput += $InputObject } }
                    end {
                    $script:invokeFzfCalls += @{ Query = $Query; NoSort = $NoSort; InputPassedToFzf = $collectedInput }
                        return $null 
                    }
                } -Global | Out-Null # Changed from -ModuleName PSFzf to -Global

                Invoke-FuzzyZLocation -Query "nonexistent"

                $script:invokeFzfCalls.Count | Should -Be 1
                $script:invokeFzfCalls[0].Query | Should -Be "nonexistent"
                
                # Input to FZF should still be all paths from ZLocation, sorted
                $expectedFzfInput = @('/user/work/projectA', '/user/dev/projectB')
                $script:invokeFzfCalls[0].InputPassedToFzf | Should -BeExactly $expectedFzfInput

                $script:setLocationCalls.Count | Should -Be 0
            }

            It "navigates directly for unique match with spaces in path and query" {
                Mock Get-ZLocation { return @{'/home/my documents/project Alpha' = 10; '/tmp/another' = 5; '/home/my documents/project Beta' = 1} } -Global | Out-Null
                
                Invoke-FuzzyZLocation -Query "project Alpha" # Query itself might have spaces
                
                $script:setLocationCalls.Count | Should -Be 1
                $script:setLocationCalls[0] | Should -Be '/home/my documents/project Alpha'
                $script:invokeFzfCalls.Count | Should -Be 0
            }
        }
        
        Context "Error Handling" {
            It "should write a warning if Get-ZLocation throws an error" {
                Mock Get-ZLocation { throw "ZLocation Database Error" } -Global | Out-Null
                
                Invoke-FuzzyZLocation -Query "anyquery" # Query or no query, error should be caught
                
                $script:writeWarningCalls.Count | Should -Be 1
                $script:writeWarningCalls[0] | Should -Match "An error occurred in Invoke-FuzzyZLocation: ZLocation Database Error"
                
                # Ensure no navigation attempt was made
                $script:setLocationCalls.Count | Should -Be 0
                $script:invokeFzfCalls.Count | Should -Be 0 
            }

            It "should write a warning if Set-Location throws an error during direct navigation" {
                Mock Get-ZLocation { return @{'/home/user/projectUnique' = 10} } -Global | Out-Null
                Mock Set-Location { param($Path) throw "Set-Location Failed for $Path" } -Global | Out-Null

                Invoke-FuzzyZLocation -Query "projectUnique"

                $script:writeWarningCalls.Count | Should -Be 1
                $script:writeWarningCalls[0] | Should -Match "An error occurred in Invoke-FuzzyZLocation: Set-Location Failed for /home/user/projectUnique"
                $script:setLocationCalls.Count | Should -Be 0 # Set-Location mock throws, so it won't add to list
                $script:invokeFzfCalls.Count | Should -Be 0
            }

            It "should write a warning if Set-Location throws an error after FZF selection" {
                Mock Get-ZLocation { return @{'/path/selected' = 10} } -Global | Out-Null
                Mock Invoke-Fzf { param($Query, $NoSort, [Parameter(ValueFromPipeline)]$InputObject) return '/path/selected' } -Global | Out-Null # Changed from -ModuleName PSFzf to -Global
                Mock Set-Location { param($Path) throw "Set-Location Failed for $Path" } -Global | Out-Null

                Invoke-FuzzyZLocation # No query, FZF selects '/path/selected'

                $script:writeWarningCalls.Count | Should -Be 1
                $script:writeWarningCalls[0] | Should -Match "An error occurred in Invoke-FuzzyZLocation: Set-Location Failed for /path/selected"
                $script:setLocationCalls.Count | Should -Be 0
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