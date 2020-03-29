@echo off
git log --oneline --graph --date=short --color=always --pretty="format:%%C(auto)%%cd %%h%%d %%s" %2