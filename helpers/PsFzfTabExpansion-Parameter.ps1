# Can't use named parameters
$command = $args[0]
$parameter = $args[1]
$parameter = $parameter.replace('-', '')

if ([System.Management.Automation.Cmdlet]::CommonParameters.Contains($parameter)) {
    $tempFile = New-TemporaryFile
    Get-Help about_CommonParameters | out-file $tempFile
    $found = Get-Content $tempFile | select-string ('^' + $parameter + '$') -Context 0, 20 -AllMatches:$false
    if ($null -ne $found) {
        Write-Output $found[0] | ForEach-Object { $_ -replace ("^> $parameter", "`n-$parameter (common parameter)") }
    }
    Remove-Item $tempFile -ErrorAction SilentlyContinue
}
else {
    Get-Help -Name $Command -Parameter $parameter
}
