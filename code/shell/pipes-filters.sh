#!/usr/bin/env bash
# Pipelines, redirection, and the text filters that do the work.

set -euo pipefail

data=$(cat <<'ROWS'
Alder Cross,Amber,2,2
Quill Wharf,Cobalt,3,4
Saltwick Halt,Amber,5,1
Nether Gate,Emerald,2,3
Bramble Fields,Cobalt,4,2
Vellin Halt,Slate,4,2
ROWS
)

echo '--- cut, sort, uniq ---'
cut -d, -f2 <<< "$data" | sort | uniq -c | sort -rn

echo '--- grep, wc ---'
grep -c Amber <<< "$data" | xargs printf 'Amber stations: %s\n'
grep -v Cobalt <<< "$data" | wc -l | xargs printf 'not on Cobalt: %s\n'
grep -E '^[A-Z][a-z]+ (Cross|Wharf)' <<< "$data" | cut -d, -f1

echo '--- sort by a field, numerically ---'
sort -t, -k3 -n <<< "$data" | head -n 3

echo '--- tr, sed, awk in one pipeline ---'
cut -d, -f1 <<< "$data" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/$/.csv/'

echo '--- head and tail ---'
head -n 2 <<< "$data"
echo '...'
tail -n 2 <<< "$data"
sed -n '3,4p' <<< "$data" | sed 's/^/line 3-4: /'

echo '--- paste, join, column ---'
paste -d' ' <(cut -d, -f1 <<< "$data") <(cut -d, -f3 <<< "$data") | head -n 3
column -t -s, <<< "$data" | head -n 3

echo '--- redirection ---'
workspace=$(mktemp -d "${TMPDIR:-/tmp}/sample-assets-XXXXXX")
trap 'rm -rf "$workspace"' EXIT

# > truncates, >> appends, 2> takes stderr, &> takes both, < reads.
printf 'first\n' > "$workspace/out.txt"
printf 'second\n' >> "$workspace/out.txt"
{ echo 'to stdout'; echo 'to stderr' >&2; } > "$workspace/stdout.txt" 2> "$workspace/stderr.txt"

echo "out.txt has $(wc -l < "$workspace/out.txt" | tr -d ' ') lines"
echo "stderr.txt says: $(cat "$workspace/stderr.txt")"

# 2>&1 sends stderr where stdout is already going; order matters.
{ echo 'both'; echo 'streams' >&2; } > "$workspace/combined.txt" 2>&1
echo "combined.txt has $(wc -l < "$workspace/combined.txt" | tr -d ' ') lines"

# /dev/null throws output away.
grep 'nothing here' <<< "$data" > /dev/null 2>&1 || echo 'grep found nothing, quietly'

# tee writes to a file and passes the stream along.
cut -d, -f1 <<< "$data" | tee "$workspace/names.txt" | wc -l | xargs printf 'tee wrote %s names\n'

# A pipeline's exit statuses are in PIPESTATUS.
false | true
echo "PIPESTATUS: ${PIPESTATUS[*]}"

# xargs turns a stream into arguments, -I places each one.
cut -d, -f1 <<< "$data" | head -n 2 | xargs -I{} printf 'station: %s\n' '{}'
