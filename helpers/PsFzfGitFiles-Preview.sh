set -e
file=$1

if [[ -n $3 ]]; then
    args=$2
    dir="${3//\\//}"
else
    args=""
    dir="${2//\\//}"
fi

pushd . > /dev/null
cd "$dir"
if [ ! -e "$file" ]; then
    echo "$file deleted"
elif git ls-files --error-unmatch "$1" > /dev/null 2>&1; then
    git diff --no-ext-diff ${args:+$args} HEAD -- $file | head -500
else
    echo "$file added"
fi
popd > /dev/null
