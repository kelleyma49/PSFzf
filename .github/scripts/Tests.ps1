$ErrorActionPreference = "Stop"

# make sure fzf is in our path:
$env:PATH = '{0}{1}{2}' -f $env:PATH,[IO.Path]::PathSeparator,"./fzf"

$testResultsFile = "./TestsResults.xml"
$config = New-PesterConfiguration
$config.Run.Path = './PSFzf.tests.ps1'
$config.Run.PassThru = $true
$config.TestResult.Enabled = $true
$config.TestResult.OutputFormat = 'NUnitXml'
$config.TestResult.OutputPath = $testResultsFile
$res = Invoke-Pester -Configuration $config
#(New-Object 'System.Net.WebClient').UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", (Resolve-Path $testResultsFile))
if ($res.FailedCount -gt 0) { 
  throw "$($res.FailedCount) tests failed."
}

Invoke-ScriptAnalyzer -Path ./PSFzf.psm1 -Settings ./PSScriptAnalyzerSettings.psd1