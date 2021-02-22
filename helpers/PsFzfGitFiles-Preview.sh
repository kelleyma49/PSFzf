set -e
args=$2
dir="${3//\\//}"
file=$1

pushd . > /dev/null
cd "$dir"
git diff $args $file | head -500
popd > /dev/null