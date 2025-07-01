# PSConsoleReadLineWrappers.ps1

function Get-PSConsoleReadLineBufferState {
    [CmdletBinding()]
    param()

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    return @{ Line = $line; Cursor = $cursor }
}

function Insert-PSConsoleReadLineText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $TextToInsert
    )

    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($TextToInsert)
}

function Replace-PSConsoleReadLineText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int] $Start,
        [Parameter(Mandatory = $true)]
        [int] $Length,
        [Parameter(Mandatory = $true)]
        [string] $ReplacementText
    )

    [Microsoft.PowerShell.PSConsoleReadLine]::Replace($Start, $Length, $ReplacementText)
}

function Invoke-PSConsoleReadLinePrompt {
    [CmdletBinding()]
    param()

    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
}

function Invoke-PSConsoleReadLineAcceptLine {
    [CmdletBinding()]
    param()

    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}