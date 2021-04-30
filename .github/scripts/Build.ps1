$ErrorActionPreference = "Stop"

$env:DOTNET_CLI_TELEMETRY_OPTOUT=1
#dotnet restore --verbosity detailed
dotnet add package PowerShellStandard.Library --version 5.1.0
dotnet build --configuration Release PSFzf.sln
$dllPaths = Get-ChildItem PSFzf.dll -Recurse
if ($null -eq $dllPaths) {
    throw 'Unable to find PSFzf.dll'
}
Copy-Item $dllPaths[0].FullName . -Force -Verbose

# construct the module file:
./helpers/Join-ModuleFiles.ps1