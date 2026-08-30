#!/usr/bin/env bash
# <(...) and >(...) make a command look like a file, which avoids a
# temporary file and keeps a while loop out of a subshell.

set -euo pipefail

echo '--- comparing two commands without temporary files ---'
diff <(printf 'Amber\nCobalt\nEmerald\n') <(printf 'Amber\nCrimson\nEmerald\n') || true

echo
echo '--- the subshell trap ---'
# A pipeline runs the while loop in a subshell, so the count is lost.
count=0
printf 'a\nb\nc\n' | while read -r _; do ((count++)); done
echo "after a pipeline: count=$count"

# Redirecting from a process substitution keeps the loop in this shell.
count=0
while read -r _; do ((count++)); done < <(printf 'a\nb\nc\n')
echo "after <(...):     count=$count"

echo
echo '--- reading two streams at once ---'
exec 3< <(printf 'Alder Cross\nQuill Wharf\n')
exec 4< <(printf '2\n3\n')
while read -r name <&3 && read -r zone <&4; do
  printf '  %-14s zone %s\n' "$name" "$zone"
done
exec 3<&- 4<&-

echo
echo '--- writing to a process ---'
# >(...) sends output into a command's standard input.
printf 'Alder Cross\nQuill Wharf\nSaltwick Halt\n' \
  | tee >(wc -l | xargs printf 'counted %s lines\n' >&2) \
  | tr '[:lower:]' '[:upper:]'

echo
echo '--- what the shell actually substitutes ---'
echo "a process substitution looks like: $(echo <(true))"

echo
echo '--- joining sorted streams ---'
join -t, \
  <(printf 'ST-001,Alder Cross\nST-002,Quill Wharf\nST-003,Saltwick Halt\n' | sort -t, -k1,1) \
  <(printf 'ST-001,2\nST-002,3\nST-003,5\n' | sort -t, -k1,1)

echo
echo '--- feeding a here-string and a here-document ---'
# <<< is a here-string, the smallest version of the same idea.
tr ',' '\n' <<< 'Amber,Cobalt,Emerald' | sed 's/^/  /'

# mapfile plus a process substitution fills an array in the current shell.
mapfile -t lines < <(printf 'Amber\nCobalt\nEmerald\n')
echo "array holds ${#lines[@]}: ${lines[*]}"

# A named pipe does the same thing when a real path is needed.
workspace=$(mktemp -d "${TMPDIR:-/tmp}/sample-assets-XXXXXX")
trap 'rm -rf "$workspace"' EXIT
mkfifo "$workspace/pipe"
printf 'through a fifo\n' > "$workspace/pipe" &
read -r message < "$workspace/pipe"
wait
echo "fifo delivered: $message"
