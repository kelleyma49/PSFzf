# only deploy from Windows:
if (-not $isLinux) {
    $ErrorActionPreference = "Stop"
    
    $psdir = $env:APPVEYOR_BUILD_FOLDER
    $installdir = join-path $psdir $env:APPVEYOR_PROJECT_NAME
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
    $psdFilePath = Join-Path $installdir ($env:APPVEYOR_PROJECT_NAME + '.psd1')
    $psdTable = Invoke-Expression (Get-Content $psdFilePath  | out-string) 
    $version = $env:APPVEYOR_REPO_TAG_NAME
    if ($version -eq '' -or $null -eq $version) {
      $version = $env:LAST_TAG
    }
    $version = $version.Replace('v','')
    write-host ("publishing version {0}" -f $version)
    $psdTable.ModuleVersion = $version
    New-ModuleManifest $psdFilePath @psdTable
    
    Publish-Module -NugetApiKey $env:POWERSHELLGALLERY_APIKEY -Path $installdir
}