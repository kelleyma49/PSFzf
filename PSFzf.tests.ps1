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
Import-Module $PSScriptRoot\PsFzf.psm1 -ErrorAction Stop

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
