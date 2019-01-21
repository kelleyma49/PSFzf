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
				Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor) | Should Be $null
				$leftCursor | Should Be 0
				$rightCursor | Should Be 0
			}

			It "Should Return Nothing with Spaces Cursor at Beginning" {
				$line = " " ; $cursor = 0
				$leftCursor = $rightCursor = $null
				Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor) | Should Be " "
				$leftCursor | Should Be 0
				$rightCursor | Should Be 0
			}

			It "Should Return Nothing with Spaces Cursor at End" {
				$line = " " ; $cursor = 1
				$leftCursor = $rightCursor = $null
				Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor) | Should Be " "
				$leftCursor | Should Be 0
				$rightCursor | Should Be 0
			}

			It "Should Return Path Cursor at Beginning for Single Char" {
				$line = "~" ; $cursor = 0
				$leftCursor = $rightCursor = $null
				Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor) | Should Be "~"
				$leftCursor | Should Be 0
				$rightCursor | Should Be ($line.Length-1)
			}

			It "Should Return Path Cursor at Beginning" {
				$line = "C:\Windows\" ; $cursor = 0
				$leftCursor = $rightCursor = $null
				Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor) | Should Be "c:\Windows\"
				$leftCursor | Should Be 0
				$rightCursor | Should Be ($line.Length-1)
			}

			It "Should Return Path Cursor at End" {
				$line = "C:\Windows\" ; $cursor = $line.Length
				$leftCursor = $rightCursor = $null
				Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor) | Should Be "c:\Windows\"
				$leftCursor | Should Be 0
				$rightCursor | Should Be ($line.Length-1)
			}

			It "Should Return Command and Path Cursor at Beginning" {
				$line = "cd C:\Windows\" ; $cursor = 0
				$leftCursor = $rightCursor = $null
				Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor) | Should Be "cd"
				$leftCursor | Should Be 0
				$rightCursor | Should Be ('cd'.Length-1)
			}

			It "Should Return Command and Path Cursor at End" {
				$line = "cd C:\Windows\" ; $cursor = $line.Length
				$leftCursor = $rightCursor = $null
				Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor) | Should Be "c:\Windows\"
				$leftCursor | Should Be 'cd '.Length
				$rightCursor | Should Be ($line.Length-1)
			}

			It "Should Return Command and Path Cursor at End" {
				$line = "cd C:\Windows\" ; $cursor = $line.Length-1
				$leftCursor = $rightCursor = $null
				Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor) | Should Be "c:\Windows\"
				$leftCursor | Should Be 'cd '.Length
				$rightCursor | Should Be ($line.Length-1)
			}

			It "Should Return Path With Quotes Cursor at Beginning" {
				'"',"'" | ForEach-Object {
					$quote  = $_
					$line = $quote + 'C:\Program Files\' + $quote ; $cursor = 0
					$leftCursor = $rightCursor = $null
					Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor) | Should Be 'C:\Program Files\'
					$leftCursor | Should Be 0
					$rightCursor | Should Be ($line.Length-1)
				}
			}

			It "Should Return Path With Quotes Cursor at End" {
				'"',"'" | ForEach-Object {
					$quote  = $_
					$line = $quote + 'C:\Program Files\' + $quote ; $cursor = 0
					$leftCursor = $rightCursor = $null
					Find-CurrentPath $line $cursor ([ref]$leftCursor) ([ref]$rightCursor) | Should Be 'C:\Program Files\'
					$leftCursor | Should Be 0
					$rightCursor | Should Be ($line.Length-1)
				}
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
				$newObject | Should Not Be $null
			}
		}
	}
}

# CI has problems running fzf under Windows:
if ( $IsLinux ) {
 
Describe "Invoke-Fzf" {
	InModuleScope PsFzf {
		Context "Function Exists" {
			It "Should Return Nothing" {
				$result = '' | Invoke-Fzf -Query 'file1.txt' -Select1 -Exit0 -Filter ' '
				$result | Should Be $null
			}

			It "Should Return 1 Item, 1 Element" {
				$result = 'file1.txt' | Invoke-Fzf -Select1 -Exit0 -Filter 'file1.txt'
				$result | Should Be 'file1.txt'
			}

			It "Should Return 1 Item, Case Insensitive" {
				$result = 'file1.txt' | Invoke-Fzf -Select1 -Exit0 -CaseInsensitive -Filter 'FILE1.TXT'
				$result | Should Be 'file1.txt'
			}

			It "Should Return Nothing, Case Sensitive" {
				$result = 'file1.txt' | Invoke-Fzf -Select1 -Exit0 -CaseSensitive -Filter 'FILE1.TXT'
				$result | Should Be $null
			}

			It "Should Return 1 Item, No Multi" {
				$result = 'file1.txt','file2.txt' | Invoke-Fzf -Multi -Select1 -Exit0 -Filter "file1"
				$result | Should Be 'file1.txt'
			}

			It "Should Return 2 Item, Multi" {
				$result = 'file1.txt','file2.txt' | Invoke-Fzf -Multi -Select1 -Exit0 -Filter "file"
				$result.Length | Should Be 2
				$result[0] | Should Be 'file1.txt'
				$result[1] | Should Be 'file2.txt'
			}

			It "Should Return 2 Item, Multi, Input Reversed" {
				$result = 'file1.txt','file2.txt' | Invoke-Fzf -Multi -Select1 -Exit0 -Filter "file" -ReverseInput
				$result.Length | Should Be 2
				$result[0] | Should Be 'file2.txt'
				$result[1] | Should Be 'file1.txt'
			}
		}
	}
}
}