#!/usr/bin/env bash
# for, while, until, case, and the test syntax that goes with them.

set -euo pipefail

# for over a list, a range, and an array.
for line in Amber Cobalt Emerald; do
  printf '%s ' "$line"
done
echo

for zone in {1..5}; do
  printf 'zone %d ' "$zone"
done
echo

for even in {0..10..2}; do
  printf '%d ' "$even"
done
echo

# C-style for, when an index is what you need.
for ((index = 0; index < 3; index++)); do
  printf 'index %d ' "$index"
done
echo

stations=("Alder Cross" "Quill Wharf" "Saltwick Halt")
for station in "${stations[@]}"; do
  echo "  $station"
done

# while reads a stream line by line. IFS= and -r keep the line intact.
printf 'Alder Cross,Amber,2\nQuill Wharf,Cobalt,3\n' | while IFS=, read -r name line zone; do
  echo "  $name is on $line in zone $zone"
done

# until is while's opposite.
countdown=3
until ((countdown == 0)); do
  printf '%d... ' "$countdown"
  ((countdown--))
done
echo 'go'

# [[ ]] is the bash test: no word splitting, and it understands patterns.
value="Alder Cross"
if [[ -n $value && $value == Alder* ]]; then
  echo "[[ ]] matched a glob"
fi

if [[ $value =~ ^([A-Z][a-z]+)\ ([A-Z][a-z]+)$ ]]; then
  echo "regex captured: ${BASH_REMATCH[1]} / ${BASH_REMATCH[2]}"
fi

# (( )) is arithmetic, and its exit status follows the C convention.
zone=5
if ((zone > 4)); then
  echo "zone $zone is an outer zone"
fi

# File tests.
[[ -f $0 ]] && echo "this script is a regular file"
[[ -d /tmp ]] && echo "/tmp is a directory"
[[ -x $0 ]] || echo "this script is not marked executable"

# case matches patterns, and ;;& falls through to keep testing.
for input in Amber 42 ''; do
  case $input in
    '') echo "empty" ;;
    [0-9]*) echo "$input starts with a digit" ;;
    Amber | Cobalt) echo "$input is a line name" ;;
    *) echo "$input is something else" ;;
  esac
done

# break and continue take a level, for nested loops.
for outer in 1 2 3; do
  for inner in a b c; do
    [[ $inner == b ]] && continue
    [[ $outer == 3 ]] && break 2
    printf '%s%s ' "$outer" "$inner"
  done
done
echo
