function GetProcessesList()
{
    Get-Process | `
    Where-Object { ![string]::IsNullOrEmpty($_.ProcessName) } | `
    ForEach-Object {
        $pmSize = $_.PM/1MB
        $cpu = $_.CPU
        # make sure we display a value so we can correctly parse selections:
        if ($null -eq $cpu) {
            $cpu = 0.0
        }
        "{0,-8:n2} {1,-8:n2} {2,-8} {3}" -f $pmSize, $cpu,$_.Id,$_.ProcessName }
}

GetProcessesList