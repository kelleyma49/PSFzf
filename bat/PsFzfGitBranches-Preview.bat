@echo off
git log --oneline --graph --date=short %3 --pretty="format:%%C(auto)%%cd %%h%%d %%s" %2