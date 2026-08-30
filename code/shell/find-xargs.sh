#!/usr/bin/env bash
# find for locating files, xargs for turning the results into arguments.

set -euo pipefail

workspace=$(mktemp -d "${TMPDIR:-/tmp}/sample-assets-XXXXXX")
trap 'rm -rf "$workspace"' EXIT

mkdir -p "$workspace"/datasets/{csv,json} "$workspace/code/python" "$workspace/.hidden"
printf 'station,line,zone\n' > "$workspace/datasets/csv/stations.csv"
printf 'order_id,total\n' > "$workspace/datasets/csv/orders.csv"
printf '[]\n' > "$workspace/datasets/json/stations.json"
printf 'print("hello")\n' > "$workspace/code/python/hello.py"
printf 'temporary\n' > "$workspace/code/python/scratch.tmp"
printf 'a file with a space\n' > "$workspace/datasets/csv/with space.csv"
printf 'hidden\n' > "$workspace/.hidden/secret.txt"

cd "$workspace"

echo '--- by name and by type ---'
find . -name '*.csv' -type f | sort
echo "directories: $(find . -type d | wc -l | tr -d ' ')"

echo
echo '--- excluding a directory, and combining tests ---'
find . -path './.hidden' -prune -o -type f -name '*.txt' -print
find . -type f \( -name '*.csv' -o -name '*.json' \) | sort

echo
echo '--- by size, depth, and time ---'
find . -type f -size -1k | wc -l | xargs printf 'files under 1k: %s\n'
find . -maxdepth 2 -type d | sort
find . -type f -newer "$workspace/datasets/csv/stations.csv" | wc -l | xargs printf 'newer files: %s\n'

echo
echo '--- acting on each result ---'
# -exec runs the command once per file; + batches them into one call.
find . -name '*.csv' -exec wc -l {} \; | sort -k2
find . -name '*.csv' -exec echo 'batched:' {} +

echo
echo '--- xargs, and why -print0 matters ---'
# A file name with a space breaks a plain pipeline into xargs.
find . -name '*.csv' | xargs -n1 basename 2>/dev/null | sort || true
echo '  ...the file with a space came out wrong above'

# -print0 and -0 use NUL as the separator, which no file name can contain.
find . -name '*.csv' -print0 | xargs -0 -n1 basename | sort

echo
echo '--- xargs with a placeholder, and in parallel ---'
find . -name '*.csv' -print0 | xargs -0 -I{} sh -c 'printf "%s has %s lines\n" "$(basename "$1")" "$(wc -l < "$1" | tr -d " ")"' _ {}
find . -name '*.csv' -print0 | xargs -0 -P4 -n1 wc -c | sort -n | tail -n 2

echo
echo '--- deleting, carefully ---'
find . -name '*.tmp' -type f -print -delete
echo "left: $(find . -type f | wc -l | tr -d ' ') files"

echo
echo '--- a null-safe loop, when the work is more than one command ---'
while IFS= read -r -d '' file; do
  printf '  %-24s %s bytes\n' "${file#./}" "$(wc -c < "$file" | tr -d ' ')"
done < <(find . -name '*.csv' -print0 | sort -z)
