param(
    [switch]$AllBranches,
    [switch]$Branches
)
function branches() {
    param($All="")
    $all = git branch $All --sort=committerdate --sort=HEAD --format='%(HEAD) %(color:yellow)%(refname:short) %(color:green)(%(committerdate:relative))\t%(color:blue)%(subject)%(color:reset)' --color=always | `
    % {
        $crap= $_.Split('\t');
        [PSCustomObject]@{
            branch = $crap[0]
            info = $crap[1]
        }
    }
    $PSStyle.OutputRendering = "ANSI"
    $all | format-table -HideTableHeaders | Out-String
}

if ($AllBranches) {
    "CTRL-O (open in browser) / CTRL-A (show all branches)`n"
    branches -All "-a"
} elseif ($Branches) {
    "CTRL-O (open in browser)`n"
    branches
}