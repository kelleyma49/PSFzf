$ErrorActionPreference = "Stop"

# Force bootstrap of the Nuget PackageManagement Provider; Reference: http://www.powershellgallery.com/GettingStarted?section=Get%20Started 
Get-PackageProvider -Name NuGet -Force -Verbose

# get fzf:
if ($IsLinux -or $IsMacOS) {
  $modules = 'Pester', 'platyPS'
  Invoke-WebRequest https://github.com/junegunn/fzf-bin/releases/download/${env:FZF_VERSION}/fzf-${env:FZF_VERSION}-linux_amd64.tgz -OutFile fzf.tgz -Verbose
  mkdir ./fzf/
  tar -xvf ./fzf.tgz -C ./fzf/
} else {
  $modules = 'platyPS'
  # choco install pester
  
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest https://github.com/junegunn/fzf-bin/releases/download/${env:FZF_VERSION}/fzf-${env:FZF_VERSION}-windows_amd64.zip -OutFile fzf.zip -Verbose
  Expand-Archive fzf.zip
}

$modules | ForEach-Object { 
  Install-Module -Name $_ -Scope CurrentUser -Force -Verbose 
  Import-Module -Name $_ -Verbose
}