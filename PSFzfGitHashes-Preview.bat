@echo off
echo %2 | "%~1\usr\bin\grep.exe" -o "[a-f0-9]\{7,\}" | "%~1\usr\bin\xargs.exe" git show --color=always 