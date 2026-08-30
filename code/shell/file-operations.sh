#!/usr/bin/env bash
# Creating, reading, testing, and cleaning up files and directories.

set -euo pipefail

workspace=$(mktemp -d "${TMPDIR:-/tmp}/sample-assets-XXXXXX")
trap 'rm -rf "$workspace"' EXIT

echo "workspace: $workspace"

mkdir -p "$workspace/datasets/csv"
file="$workspace/datasets/csv/stations.csv"

# Writing: > truncates, >> appends, and a heredoc writes a block.
cat > "$file" <<'ROWS'
station,line,zone
Alder Cross,Amber,2
Quill Wharf,Cobalt,3
Saltwick Halt,Amber,5
ROWS

echo 'Nether Gate,Emerald,2' >> "$file"

printf 'wrote %s bytes\n' "$(wc -c < "$file" | tr -d ' ')"

# Reading: whole file, first lines, last lines, one line at a time.
echo "header: $(head -n 1 "$file")"
echo "last:   $(tail -n 1 "$file")"
echo "lines:  $(wc -l < "$file" | tr -d ' ')"

while IFS=, read -r name line zone; do
  [[ $name == station ]] && continue
  [[ $line == Amber ]] && echo "  Amber: $name (zone $zone)"
done < "$file"

# File tests.
[[ -e $file ]] && echo "exists"
[[ -f $file ]] && echo "is a regular file"
[[ -s $file ]] && echo "is not empty"
[[ -r $file && -w $file ]] && echo "readable and writable"
[[ -d $workspace/datasets ]] && echo "datasets is a directory"
[[ -e $workspace/missing.csv ]] || echo "missing.csv is not there"

# Copying, moving, and linking.
cp "$file" "$workspace/backup.csv"
mv "$workspace/backup.csv" "$workspace/stations-backup.csv"
ln -s "$file" "$workspace/current.csv"

echo "symlink points at: $(readlink "$workspace/current.csv")"
[[ -L $workspace/current.csv ]] && echo "and is a symlink"

# Listing and finding.
echo "top level: $(ls "$workspace" | tr '\n' ' ')"
echo "csv files: $(find "$workspace" -name '*.csv' -type f | wc -l | tr -d ' ')"
echo "total size: $(du -sh "$workspace" | cut -f1)"

# Permissions.
chmod 640 "$file"
echo "mode: $(ls -l "$file" | cut -c1-10)"

# Temporary files clean up with the same trap.
scratch=$(mktemp "$workspace/scratch-XXXXXX")
echo 'temporary' > "$scratch"
echo "scratch file: ${scratch##*/}"

# Removing: -f ignores what is not there, -r goes into directories.
rm -f "$workspace/never-existed.csv"
rm "$workspace/stations-backup.csv"
echo "after cleanup: $(ls "$workspace" | tr '\n' ' ')"

echo "the trap removes the workspace on exit"
