$ErrorActionPreference = "Stop"

# make sure fzf is in our path:
$env:PATH = '{0}{1}{2}' -f $env:PATH,[IO.Path]::PathSeparator,"./fzf"

$testResultsFile = "./TestsResults.xml"
$res = Invoke-Pester -Script ./PSFzf.tests.ps1 -OutputFormat NUnitXml -OutputFile $testResultsFile -PassThru
#(New-Object 'System.Net.WebClient').UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", (Resolve-Path $testResultsFile))
if ($res.FailedCount -gt 0) { 
  throw "$($res.FailedCount) tests failed."
}
