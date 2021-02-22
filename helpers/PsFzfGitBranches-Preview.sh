set -e
args=$2
dir="${3//\\//}"
file=$1
pushd . > /dev/null
cd "$dir"
git log --oneline --graph --date=short $args --pretty="format:%C(auto)%cd %h%d %s" $file
popd > /dev/null
