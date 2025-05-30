[CmdletBinding()]
param ($DirName, $Item)

# trim quote strings:
$DirName = $DirName.Trim("'").Trim('"')
$Item = $Item.Trim("'").Trim('"')

$RunningInWindowsTerminal = [bool]($env:WT_Session)
$IsWindowsCheck = ($PSVersionTable.PSVersion.Major -le 5) -or $IsWindows
$ansiCompatible = $script:RunningInWindowsTerminal -or (-not $script:IsWindowsCheck)

if ([System.IO.Path]::IsPathRooted($Item)) {
    $path = $Item
}
else {
    $path = Join-Path $DirName $Item
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
elseif (($cmdResults = Get-Command $Item -ErrorAction Ignore)) {
    if ($cmdResults) {
        if ($cmdResults.CommandType -ne 'Application') {
            if ($ansiCompatible -and $(Get-Command bat -ErrorAction Ignore)) {
                Get-Help $Item | bat --no-config --language=markdown --color always --style=plain
            }
            else {

            }

        }
        else {
            # just output application location:
            $cmdResults.Source
        }
    }
}
