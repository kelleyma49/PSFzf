[CmdletBinding()]
param ($DirName,$FileName)

if ([System.IO.Path]::IsPathRooted($FileName)) {
    $path = $FileName
} else {
    $path = Join-Path $DirName $FileName
}
if (Test-Path $path -PathType Container) {
    Get-ChildItem $path
} 
elseif (Test-Path $path -PathType leaf) {
    if (Get-Command bat) {
        bat --style=numbers,changes --color always $path
    } else {
        Get-Content $path
    }
}
