$env:DOTNET_CLI_TELEMETRY_OPTOUT=1
dotnet build --configuration Release --output . .\PSFzf-Binary\PSFzf-Binary.csproj
if (-not (Test-path .\PSFzf.dll -PathType Leaf)) {
    Get-ChildItem . -Recurse 
    throw "Unable to find PSFzf.dll"
}