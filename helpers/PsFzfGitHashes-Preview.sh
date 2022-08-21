set -e
args=$2
dir="${3//\\//}"
hash=$1

pushd . > /dev/null
cd "$dir"
echo $hash | grep -o "[a-f0-9]\{7,\}" | xargs git show $args
popd > /dev/null
