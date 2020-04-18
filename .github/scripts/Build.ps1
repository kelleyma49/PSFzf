$ErrorActionPreference = "Stop"

$env:DOTNET_CLI_TELEMETRY_OPTOUT=1
dotnet build --configuration Release PSFzf.sln
$dllPaths = Get-ChildItem PSFzf.dll -Recurse
if ($null -eq $dllPaths) {
    throw 'Unable to find PSFzf.dll'
}
Copy-Item $dllPaths[0].FullName . -Force -Verbose

& (Join-Path $PSScriptRoot 'helpers' 'Join-ModuleFiles.ps1')  