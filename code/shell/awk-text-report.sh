#!/usr/bin/env bash
# awk for turning delimited text into a report: fields, conditions,
# accumulators, and END blocks.

set -euo pipefail

workspace=$(mktemp -d "${TMPDIR:-/tmp}/sample-assets-XXXXXX")
trap 'rm -rf "$workspace"' EXIT

cat > "$workspace/stations.csv" <<'ROWS'
station,line,zone,platforms,step_free
Alder Cross,Amber,2,2,true
Quill Wharf,Cobalt,3,4,false
Saltwick Halt,Amber,5,1,true
Nether Gate,Emerald,2,3,true
Bramble Fields,Cobalt,4,2,false
Vellin Halt,Slate,4,2,true
ROWS

data=$workspace/stations.csv

echo '--- picking fields ---'
awk -F, 'NR > 1 { print $1 " is on the " $2 " line" }' "$data"

echo
echo '--- filtering with a condition ---'
awk -F, 'NR > 1 && $3 <= 2 { print $1 }' "$data"
awk -F, '$5 == "true" && NR > 1 { count++ } END { print count " step-free stations" }' "$data"

echo
echo '--- accumulating, and an END block ---'
awk -F, '
  NR == 1 { next }                 # skip the header
  { platforms += $4; zones += $3; n++ }
  END {
    printf "%d stations, %d platforms, average zone %.2f\n", n, platforms, zones / n
  }
' "$data"

echo
echo '--- grouping with an associative array ---'
awk -F, '
  NR > 1 { count[$2]++; platforms[$2] += $4 }
  END {
    for (line in count)
      printf "  %-8s %d stations, %d platforms\n", line, count[line], platforms[line]
  }
' "$data" | sort

echo
echo '--- a formatted report ---'
awk -F, '
  BEGIN { printf "%-16s %-8s %5s %10s\n", "STATION", "LINE", "ZONE", "PLATFORMS" }
  NR > 1 { printf "%-16s %-8s %5d %10d\n", $1, $2, $3, $4 }
  END { printf "%-16s %-8s %5s %10s\n", "", "", "", "---" }
' "$data"

echo
echo '--- min, max, and a running total ---'
awk -F, '
  NR == 1 { next }
  NR == 2 { min = max = $3 }
  { if ($3 < min) min = $3; if ($3 > max) max = $3; total += $3 }
  END { print "zones run from " min " to " max ", summing to " total }
' "$data"

echo
echo '--- passing a variable in, and changing the separator ---'
awk -F, -v threshold=3 'NR > 1 && $3 > threshold { print $1 " is beyond zone " threshold }' "$data"
awk -F, -v OFS=' | ' 'NR > 1 { print $1, $2, $3 }' "$data" | head -n 3

echo
echo '--- regular expressions and built-in functions ---'
awk -F, '$1 ~ /^[A-Z][a-z]+ (Cross|Wharf|Halt)$/ { print $1 }' "$data"
awk -F, 'NR > 1 { print toupper(substr($1, 1, 1)) tolower(substr($1, 2)), length($1) }' "$data" | head -n 3
awk -F, 'NR > 1 { gsub(/ /, "-", $1); print tolower($1) ".csv" }' "$data" | head -n 3

echo
echo '--- awk as a whole pipeline stage ---'
cut -d, -f2 "$data" | tail -n +2 | sort | uniq -c |
  awk '{ printf "%-8s %s\n", $2, sprintf("%" $1 "s", "") }' | tr ' ' '#'
