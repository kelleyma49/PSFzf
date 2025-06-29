param([string]$FzfVersion = '0.62.0' )
$ErrorActionPreference = "Stop"

# Force bootstrap of the Nuget PackageManagement Provider; Reference: http://www.powershellgallery.com/GettingStarted?section=Get%20Started
Get-PackageProvider -Name NuGet -Force -Verbose

# get fzf:
if ($IsLinux -or $IsMacOS) {
  if ($IsLinux) {
    $prefix = 'linux'
  }
  else {
    $prefix = 'darwin'
  }
  Invoke-WebRequest https://github.com/junegunn/fzf/releases/download/v${fzfVersion}/fzf-${fzfVersion}-${prefix}_amd64.tar.gz -OutFile fzf.tgz -Verbose
  mkdir ./fzf/
  tar -xvf ./fzf.tgz -C ./fzf/
}
else {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest https://github.com/junegunn/fzf/releases/download/v${fzfVersion}/fzf-${fzfVersion}-windows_amd64.zip -OutFile fzf.zip -Verbose
  Expand-Archive fzf.zip
}

$modules = @('Pester', $null), @('platyPS', $null), @('PSScriptAnalyzer', $null)
$modules | ForEach-Object {
  $module = $_[0]
  $version = $_[1]
  if ($null -ne $version) {
    Install-Module -Name $module -Scope CurrentUser -RequiredVersion $version -Force -Verbose
  }
  else {
    Install-Module -Name $module -Scope CurrentUser -Force -Verbose
  }
  Import-Module -Name $module -Verbose
}
