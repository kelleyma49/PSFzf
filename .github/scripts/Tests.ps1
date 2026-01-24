$ErrorActionPreference = "Stop"

# make sure fzf is in our path:
$env:PATH = '{0}{1}{2}' -f $env:PATH,[IO.Path]::PathSeparator,"./fzf"

$testResultsFile = "./TestsResults.xml"
$coverageFile = "./coverage.xml"
$config = New-PesterConfiguration
$config.Run.Path = './PSFzf.tests.ps1'
$config.Run.PassThru = $true
$config.TestResult.Enabled = $true
$config.TestResult.OutputFormat = 'NUnitXml'
$config.TestResult.OutputPath = $testResultsFile
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = './PSFzf.psm1'
$config.CodeCoverage.OutputFormat = 'JaCoCo'
$config.CodeCoverage.OutputPath = $coverageFile
$res = Invoke-Pester -Configuration $config

# Display code coverage summary
Write-Host ""
Write-Host "Code Coverage Summary:" -ForegroundColor Cyan
Write-Host "  Covered Lines: $($res.CodeCoverage.CoveragePercent)%" -ForegroundColor Green
Write-Host "  Commands Analyzed: $($res.CodeCoverage.CommandsAnalyzedCount)"
Write-Host "  Commands Executed: $($res.CodeCoverage.CommandsExecutedCount)"
Write-Host "  Commands Missed: $($res.CodeCoverage.CommandsMissedCount)"
Write-Host "  Coverage Report: $coverageFile"
Write-Host ""

#(New-Object 'System.Net.WebClient').UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", (Resolve-Path $testResultsFile))
if ($res.FailedCount -gt 0) { 
  throw "$($res.FailedCount) tests failed."
}

Invoke-ScriptAnalyzer -Path ./PSFzf.psm1 -Settings ./PSScriptAnalyzerSettings.psd1