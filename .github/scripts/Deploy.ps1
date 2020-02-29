$ErrorActionPreference = "Stop"
Write-Host "Triggered from ${env:GITHUB_REF}"
    
$psdir = $env:GITHUB_WORKSPACE
$installdir = join-path $psdir 'PSFzf'
new-item $installdir -ItemType Directory -verbose
copy-item $psdir\*.ps* $installdir -verbose
copy-item $psdir\PSFzf.dll $installdir -verbose

# generate documentation:
$docdir = Join-Path $installdir 'en-US'
new-item $docdir -ItemType Directory
Import-Module platyPS
platyPS\New-ExternalHelp (Join-Path $psdir 'docs') -Force -OutputPath $docdir
copy-item $psdir\en-US\*.txt $docdir -verbose

# get contents of current psd, update version and save it back out in the publish directory:
$psdFilePath = Join-Path $installdir 'PSFzf.psd1'
$psdTable = Invoke-Expression (Get-Content $psdFilePath  | out-string) 
$version = $env:GITHUB_REF
if ($version -eq '' -or $null -eq $version) {
  throw 'Version not found in $GITHUB_REF'
}
$version = $version.Split('/')[-1].Replace('v','')
$psdTable.ModuleVersion = $version

$isPrerelease = "${env:GITHUB_PRERELEASE}" -eq 'true' 
if ($isPrerelease) {
  $psdTable.PrivateData = @{
    PSData = @{
        Prerelease = 'alpha'
    }
  }
  write-host ("publishing prerelease version {0}-alpha" -f $version)  
} else {
  write-host ("publishing version {0}" -f $version)
}

New-ModuleManifest $psdFilePath @psdTable

Publish-Module -NugetApiKey $env:POWERSHELLGALLERY_APIKEY -Path $installdir
