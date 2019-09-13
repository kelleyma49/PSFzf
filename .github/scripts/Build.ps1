$env:DOTNET_CLI_TELEMETRY_OPTOUT=1
dotnet build --configuration Release --output . .\PSFzf-Binary\PSFzf-Binary.csproj
copy-item .\PSFzf-Binary\PSFzf.dll . -verbose
