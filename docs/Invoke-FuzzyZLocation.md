---
external help file: PSFzf.psm1-help.xml
schema: 2.0.0
---

# Invoke-FuzzyZLocation
## SYNOPSIS
Starts fzf with input from the history saved by ZLocation and sets the current location. Can optionally take a query to directly navigate or pre-fill fzf.

## SYNTAX

```PowerShell
Invoke-FuzzyZLocation [[-Query] <string>]
```

## DESCRIPTION
Allows the user to select a directory from ZLocation's history database and set the current location.
If an optional -Query parameter is provided, the behavior changes:
- If the query uniquely identifies a single directory from ZLocation's history, the shell will navigate directly to that directory.
- If the query matches multiple directories or no directories, fzf will be launched with the query string as the initial filter, allowing the user to interactively select the desired directory.
- If no query is provided, fzf is launched with the full ZLocation history.

## EXAMPLES

### Example 1: Launch Invoke-FuzzyZLocation without a query
	
Launches fzf with input from ZLocation's history database and set the location based on user selection.

```PowerShell
Invoke-FuzzyZLocation
```

### Example 2: Navigate directly to a unique directory

If "MyProject" is a unique match in ZLocation's history:
```PowerShell
Invoke-FuzzyZLocation -Query "MyProject"
# Or using positional parameter
Invoke-FuzzyZLocation MyProject 
```
This command would directly change the current directory to the path associated with "MyProject".

### Example 3: Launch fzf with an initial query

If there are multiple directories containing "Project" in their path in ZLocation's history (e.g., "ProjectA", "ProjectB"):
```PowerShell
Invoke-FuzzyZLocation -Query "Project"
```
This command would open fzf, with "Project" as the initial search query, displaying entries like "ProjectA" and "ProjectB".

## PARAMETERS

### -Query <string>
An optional query string to search for in the ZLocation history.
- If the query matches a single directory in ZLocation's history, the function will navigate directly to that directory.
- If the query results in multiple matches or no matches, fzf will open with the query pre-filled, allowing further interactive filtering.
- If omitted, fzf will open with the full ZLocation history as per the original behavior.

### CommonParameters
This cmdlet does not support common parameters.
## INPUTS

### None 
This cmdlet does not accept any input.
## OUTPUTS

### None
This cmdlet does not generate any output.
## NOTES
This function will be created if [ZLocation](https://github.com/vors/ZLocation) can be found by PowerShell.
## RELATED LINKS
