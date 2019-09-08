dotnet build --configuration Release --output . .\PSFzf-Binary\PSFzf-Binary.csproj
copy-item .\PSFzf-Binary\PSFzf.dll . -verbose