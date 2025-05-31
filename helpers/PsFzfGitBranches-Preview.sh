set -e
git log --oneline --graph --date=short --color=always --pretty='format:%C(auto)%cd %h%d %s' $(cut -c1- <<< $1 | cut -d' ' -f1) --
