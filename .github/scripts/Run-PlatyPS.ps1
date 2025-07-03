# Get all markdown files in the docs directory
$markdownFiles = Get-ChildItem -Path ./docs -Filter *.md

# Test the markdown files using PlatyPS
$testResults = Test-Markdown -Path $markdownFiles

# Check if there are any errors
if ($testResults.ErrorCount -gt 0) {
    Write-Error "PlatyPS found errors in the documentation."
    exit 1
} else {
    Write-Host "PlatyPS validation successful."
}
