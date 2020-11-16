[CmdletBinding()]
param ($DirName,$Item)

if ([System.IO.Path]::IsPathRooted($Item)) {
    $path = $Item
} else {
    $path = Join-Path $DirName $Item
}
# is directory?
if (Test-Path $path -PathType Container) {
    Get-ChildItem $path
} 
# is file?
elseif (Test-Path $path -PathType leaf) {
    $RunningInWindowsTerminal = [bool]($env:WT_Session)
    $IsWindowsCheck = ($PSVersionTable.PSVersion.Major -le 5) -or $IsWindows

    # use bat (https://github.com/sharkdp/bat) if it's available:
    $checkBat = $script:RunningInWindowsTerminal -or (-not $script:IsWindowsCheck)
    if ($checkBat -and $(Get-Command bat -ErrorAction SilentlyContinue)) {
        bat --style=numbers,changes --color always $path
    } else {
        Get-Content $path
    }
}
# PowerShell command 
elseif (Get-Command $Item -ErrorAction SilentlyContinue) {
    Get-Help $Item
}
