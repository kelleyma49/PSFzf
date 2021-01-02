$ErrorActionPreference = "Stop"
Write-Host "Triggered from ${env:GITHUB_REF}"
    
$psdir = $env:GITHUB_WORKSPACE
$installdir = Join-Path $psdir 'PSFzf'
new-item $installdir -ItemType Directory -verbose

new-item $(Join-Path $installdir 'helpers') -ItemType Directory -verbose
copy-item $(Join-Path $psdir 'helpers' '*.*') $(Join-Path $installdir 'helpers') -verbose
copy-item $(Join-Path $psdir '*.ps*') $installdir -verbose
copy-item $(Join-Path $psdir 'PSFzf.dll') $installdir -verbose

# generate documentation:
$docdir = Join-Path $installdir 'en-US'
new-item $docdir -ItemType Directory
Import-Module platyPS
platyPS\New-ExternalHelp (Join-Path $psdir 'docs') -Force -OutputPath $docdir
copy-item $(Join-Path $psdir 'en-US' '*.txt') $docdir -verbose

# get contents of current psd, update version and save it back out in the publish directory:
$psdFilePath = Join-Path $installdir 'PSFzf.psd1'

# update prerelease:
$isPrerelease = "${env:GITHUB_PRERELEASE}" -eq 'true'
if ($isPrerelease) {
  $psdStr = Get-Content $psdFilePath | Out-String
  $psdStr = $psdStr.Replace('# Prerelease =','  Prerelease =')
  Set-Content -Path $psdFilePath -Value $psdStr
}

$version = $env:GITHUB_REF
if ($version -eq '' -or $null -eq $version) {
  throw 'Version not found in $GITHUB_REF'
}
$version = $version.Split('/')[-1].Replace('v','')
Update-ModuleManifest $psdFilePath -ModuleVersion $version

if ($isPrerelease) {
  write-host ("publishing prerelease version {0}-alpha" -f $version)  
} else {
  write-host ("publishing version {0}" -f $version)
}
Publish-Module -NugetApiKey $env:POWERSHELLGALLERY_APIKEY -Path $installdir -Verbose
