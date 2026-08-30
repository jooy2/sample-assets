#!/usr/bin/env bash
# Here-documents and here-strings: multi-line text without a file.

set -euo pipefail

station='Alder Cross'
zone=2

echo '--- interpolating ---'
cat <<REPORT
Station: $station
Zone:    $zone
Fare:    $(printf '%.2f' "$((240 + zone * 85))e-2")
REPORT

echo
echo '--- literal, with the delimiter quoted ---'
cat <<'REPORT'
Nothing here is expanded: $station, $(date), `hostname`, ${HOME}
REPORT

echo
echo '--- stripping leading tabs with <<- ---'
if true; then
	cat <<-REPORT
		This block is indented in the source
		but the leading tabs are stripped.
		Only tabs, though, not spaces.
	REPORT
fi

echo
echo '--- a here-string ---'
tr ',' '\n' <<< 'Amber,Cobalt,Emerald' | sed 's/^/  /'
read -r first _ <<< "$station"
echo "first word: $first"
grep -c 'a' <<< "$station" | xargs printf "lines containing 'a': %s\n"

echo
echo '--- capturing a here-document into a variable ---'
usage=$(cat <<'USAGE'
usage: here-documents.sh [-v] NAME
  -v  be verbose
USAGE
)
echo "$usage"
echo "the usage text is ${#usage} characters"

echo
echo '--- writing a file ---'
workspace=$(mktemp -d "${TMPDIR:-/tmp}/sample-assets-XXXXXX")
trap 'rm -rf "$workspace"' EXIT

cat > "$workspace/stations.csv" <<'ROWS'
station,line,zone
Alder Cross,Amber,2
Quill Wharf,Cobalt,3
ROWS

echo "wrote $(wc -l < "$workspace/stations.csv" | tr -d ' ') lines"

# Appending, and building a config file from variables.
cat >> "$workspace/stations.csv" <<ROWS
Saltwick Halt,Amber,5
$station,Amber,$zone
ROWS
cat "$workspace/stations.csv"

echo
echo '--- feeding a command that reads stdin ---'
awk -F, 'NR > 1 { total += $3 } END { printf "  zones add up to %d\n", total }' <<ROWS
station,line,zone
Alder Cross,Amber,2
Quill Wharf,Cobalt,3
Saltwick Halt,Amber,5
ROWS

# Two here-documents on one line, read in order.
cat <<'FIRST' <<'SECOND'
never printed: only the last redirection of stdin wins
FIRST
this is what cat reads
SECOND
