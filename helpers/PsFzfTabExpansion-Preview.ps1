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
    # if .git folder, try to show the output of 'git log'
    if ((Get-Item $path).Name -eq '.git') {
        if ((Get-Command git -ErrorAction Ignore)) {
            Push-Location $path/..
            if ($ansiCompatible) {
                git log --color=always -1 2> $null
            }
            else {
                git log -1 2> $null
            }
            Pop-Location
        }
    } else {
        Get-ChildItem $path
    }
}
# is file?
elseif (Test-Path $path -PathType leaf) {
    # use bat (https://github.com/sharkdp/bat) if it's available:
    if ($ansiCompatible -and $(Get-Command bat -ErrorAction Ignore)) {
        bat "--style=numbers,changes" --color always $path
    }
    else {
        Get-Content $path
    }
}
# PowerShell command?
elseif (($cmdResults = Get-Command $Item -ErrorAction Ignore)) {
    if ($cmdResults) {
        if ($cmdResults.CommandType -ne 'Application') {
            Get-Help $Item
        }
        else {
            # just output application location:
            $cmdResults.Source
        }
    }
}
