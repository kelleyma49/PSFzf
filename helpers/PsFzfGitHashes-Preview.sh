set -e
hash=$1

if [[ -n $3 ]]; then
    args=$2
    dir="${3//\\//}"
else
    args=""
    dir="${2//\\//}"
fi

pushd . > /dev/null
cd "$dir"
echo $hash | grep -o "[a-f0-9]\{7,\}"  -m 1  | head -1 | xargs git show ${args:+$args}
popd > /dev/null
