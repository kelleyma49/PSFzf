# Can't use named parameters
$command = $args[0]
$parameter = $args[1]

# Extract fields from NUL-separated parameter (CompletionText\0ListItemText\0ToolTip)
$fields = $parameter -split "`0"
$parameterText = if ($fields.Length -gt 0) { $fields[0] } else { $parameter }
$ToolTip = if ($fields.Length -gt 2) { $fields[2] } else { "" }

$parameterText = $parameterText.replace('-', '')

$AnsiCompatible = [bool]($env:WT_Session) -or [bool]($env:TERM_PROGRAM -eq "WezTerm")
$IsWindowsCheck = ($PSVersionTable.PSVersion.Major -le 5) -or $IsWindows
$ansiCompatible = $script:AnsiCompatible -or (-not $script:IsWindowsCheck)

# Display ToolTip if available
if (-not [string]::IsNullOrWhiteSpace($ToolTip)) {
    Write-Output "ToolTip:"
    Write-Output $ToolTip
    Write-Output ""
    Write-Output "---"
    Write-Output ""
}

if ([System.Management.Automation.Cmdlet]::CommonParameters.Contains($parameterText)) {
    $tempFile = New-TemporaryFile
    Get-Help about_CommonParameters | out-file $tempFile
    $found = Get-Content $tempFile | select-string ('^' + $parameterText + '$') -Context 0, 20 -AllMatches:$false
    if ($null -ne $found) {
        Write-Output $found[0] | ForEach-Object { $_ -replace ("^> $parameterText", "`n-$parameterText (common parameter)") }
    }
    Remove-Item $tempFile -ErrorAction SilentlyContinue
}
else {
    if ($ansiCompatible -and $(Get-Command bat -ErrorAction Ignore)) {
        Get-Help -Name $Command -Parameter $parameterText | bat --no-config --language=man --color always --style=plain
    }
    else {
        Get-Help -Name $Command -Parameter $parameterText
    }
}
