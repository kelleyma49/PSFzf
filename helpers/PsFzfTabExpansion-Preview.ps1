[CmdletBinding()]
param ($DirName, $Item)

# Extract fields from NUL-separated item (CompletionText\0ListItemText\0ToolTip)
$fields = $Item -split "`0"
$ItemText = if ($fields.Length -gt 0) { $fields[0] } else { $Item }
$ToolTip = if ($fields.Length -gt 2) { $fields[2] } else { "" }

# trim quote strings:
$DirName = $DirName.Trim("'").Trim('"')
$ItemText = $ItemText.Trim("'").Trim('"')

$IsWindowsCheck = ($PSVersionTable.PSVersion.Major -le 5) -or $IsWindows
$ansiCompatible = [bool]($env:WT_Session) -or [bool]($env:TERM_PROGRAM -eq "WezTerm") -or (-not $script:IsWindowsCheck)

# Display ToolTip if available
if (-not [string]::IsNullOrWhiteSpace($ToolTip)) {
    Write-Output "ToolTip:"
    Write-Output $ToolTip
    Write-Output ""
    Write-Output "---"
    Write-Output ""
}

if ([System.IO.Path]::IsPathRooted($ItemText)) {
    $path = $ItemText
}
else {
    $path = Join-Path $DirName $ItemText
}
# is directory?
if (Test-Path $path -PathType Container) {
    Get-ChildItem $path

    if (Get-Command git -ErrorAction Ignore) {
        Write-Output "" # extra separator before git status
        Push-Location $path
        if ($ansiCompatible -and $(Get-Command bat -ErrorAction Ignore)) {
            git log -1 2> $null | bat --no-config "--style=changes" --color always
        }
        else {
            git log -1 2> $null
        }
        Pop-Location
    }
}
# is file?
elseif (Test-Path $path -PathType leaf) {
    # use bat (https://github.com/sharkdp/bat) if it's available:
    if ($ansiCompatible -and $(Get-Command bat -ErrorAction Ignore)) {
        bat --no-config "--style=numbers,changes" --color always $path
    }
    else {
        Get-Content $path
    }
}
# PowerShell command?
elseif (($cmdResults = Get-Command $ItemText -ErrorAction Ignore)) {
    if ($cmdResults) {
        if ($cmdResults.CommandType -ne 'Application') {
            if ($ansiCompatible -and $(Get-Command bat -ErrorAction Ignore)) {
                Get-Help $ItemText | bat --no-config --language=man --color always --style=plain
            }
            else {
                Get-Help $ItemText
            }

        }
        else {
            # just output application location:
            $cmdResults.Source
        }
    }
}
