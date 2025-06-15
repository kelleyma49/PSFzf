# Can't use named parameters
$command = $args[0]
$parameter = $args[1]
$parameter = $parameter.replace('-', '')

$AnsiCompatible = [bool]($env:WT_Session) -or [bool]($env:TERM_PROGRAM -eq "WezTerm")
$IsWindowsCheck = ($PSVersionTable.PSVersion.Major -le 5) -or $IsWindows
$ansiCompatible = $script:AnsiCompatible -or (-not $script:IsWindowsCheck)

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
    if ($ansiCompatible -and $(Get-Command bat -ErrorAction Ignore)) {
        Get-Help -Name $Command -Parameter $parameter | bat --no-config --language=man --color always --style=plain
    }
    else {
        Get-Help -Name $Command -Parameter $parameter
    }
}
