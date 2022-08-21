set -e
args=$2
dir="${3//\\//}"
file=$1
pushd . > /dev/null
#cd "$dir"
git log --oneline --graph --date=short --color=always --pretty="format:%C(auto)%cd %h%d %s" $(sed s/^..// <<< $1 | cut -d" " -f1)
#popd > /dev/null
