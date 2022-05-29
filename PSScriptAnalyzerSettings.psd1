# borrowed from https://devblogs.microsoft.com/powershell/using-psscriptanalyzer-to-check-powershell-version-compatibility/
@{
    Rules = @{
        PSUseCompatibleSyntax = @{
            Enable         = $true

            # List the targeted versions of PowerShell here
            TargetVersions = @(
                '5.1',
                '6.2'
                '7.0'
            )
        }
    }
}