param(
    [switch]$AllBranches,
    [switch]$Branches
)
function branches() {
    param($All = "")
    $all = git branch --sort=committerdate --sort=HEAD --format='%(HEAD) %(color:yellow)%(refname:short) %(color:green)(%(committerdate:relative))\t%(color:blue)%(subject)%(color:reset)' --color=always | `
        ForEach-Object {
        $split = $_.Split("\t");
        [PSCustomObject]@{
            branch = $split[0]
            info   = $split[1]
        }
    }
    $PSStyle.OutputRendering = "ANSI"
    $all | format-table -HideTableHeaders | Out-String
    $all | Out-File ~/crap-ps.txt -Append
}

if ($AllBranches) {
    "CTRL-A (show all branches)`n"
    branches -All "-a"
}
elseif ($Branches) {
    "`n"
    branches
}