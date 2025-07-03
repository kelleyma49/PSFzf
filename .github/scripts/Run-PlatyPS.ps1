# Import PlatyPS module
Import-Module platyPS -ErrorAction Stop

$ErrorActionPreference = "Stop"

# Define paths
$markdownPath = "./docs"
$tempOutputPath = "./temp_help_output" # Using a more descriptive temporary folder name

# Create temporary output directory
if (-not (Test-Path $tempOutputPath)) {
    New-Item -ItemType Directory -Path $tempOutputPath -Force | Out-Null
}

try {
    # Attempt to generate external help files
    # This command assumes that 'docs/' contains markdown files that PlatyPS can process
    # and that the module manifest is discoverable by PlatyPS or not strictly needed for validation intent.
    # For robust validation, one might need to specify the module manifest path if docs are tied to a specific module.
    # However, the goal here is to "see if platyps can generate the documentation", implying a test of the markdown files themselves.
    Get-ChildItem -Path $markdownPath -Filter *.md | New-ExternalHelp -OutputPath $tempOutputPath -Force -Verbose

    # Check if the command was successful.
    # New-ExternalHelp might not set $? to $false on logical errors if it completes the cmdlet execution.
    # A more robust check would be to see if any XML files were generated or if specific errors were logged.
    # For now, we rely on $? and -ErrorAction Stop for catching terminating errors.
    # If specific non-terminating errors need to be caught, more complex error handling would be needed.

    # A simple check for generated files (optional, but good for validation)
    if ((Get-ChildItem -Path $tempOutputPath -Filter *.xml).Count -eq 0) {
        Write-Error "PlatyPS New-ExternalHelp did not generate any help files. Potential issue with markdown or command parameters."
        exit 1
    }

    Write-Host "PlatyPS New-ExternalHelp validation successful. Help files generated in $tempOutputPath."
}
catch {
    Write-Error "PlatyPS New-ExternalHelp failed: $($_.Exception.Message)"
    exit 1
}
finally {
    # Clean up temporary output directory
    if (Test-Path $tempOutputPath) {
        Remove-Item -Path $tempOutputPath -Recurse -Force
    }
}

Write-Host "PlatyPS script finished."
