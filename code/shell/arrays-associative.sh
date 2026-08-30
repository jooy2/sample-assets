#!/usr/bin/env bash
# Indexed arrays and associative arrays (bash 4 and later).

set -euo pipefail

# An indexed array. Quote "${array[@]}" or elements with spaces break apart.
stations=("Alder Cross" "Quill Wharf" "Saltwick Halt")
stations+=("Nether Gate")

echo "count: ${#stations[@]}"
echo "first: ${stations[0]}"
echo "last:  ${stations[-1]}"
echo "all:   ${stations[*]}"
echo "slice: ${stations[*]:1:2}"
echo "indices: ${!stations[*]}"

for station in "${stations[@]}"; do
  echo "  [$station]"
done

# Without the quotes, each word becomes an element of its own.
echo 'unquoted expansion splits on spaces:'
for word in ${stations[@]}; do
  printf '  [%s]\n' "$word"
done

# Building an array from a command's output, one line per element.
mapfile -t lines < <(printf 'Amber\nCobalt\nEmerald\n')
echo "mapfile read ${#lines[@]}: ${lines[*]}"

# Splitting a string on a delimiter.
IFS=, read -ra fields <<< "Alder Cross,Amber,2,true"
echo "fields: ${#fields[@]}, third is ${fields[2]}"

# Removing and replacing elements.
unset 'stations[1]'
echo "after unset: ${stations[*]} (indices ${!stations[*]}, note the gap)"
stations=("${stations[@]}") # reindex
echo "reindexed: ${!stations[*]}"

# An associative array is a hash. It must be declared first.
declare -A zones=(
  ["Alder Cross"]=2
  ["Quill Wharf"]=3
  ["Saltwick Halt"]=5
)
zones["Nether Gate"]=2

echo "Quill Wharf is in zone ${zones["Quill Wharf"]}"
echo "keys: ${!zones[*]}"
echo "values: ${zones[*]}"
echo "count: ${#zones[@]}"

for name in "${!zones[@]}"; do
  printf '  %-15s zone %s\n' "$name" "${zones[$name]}"
done

# Membership: the +set form tells "absent" from "present but empty", and
# works on every bash. Since 4.2 there is also [[ -v zones[$key] ]].
key='Alder Cross'
if [[ -n ${zones[$key]+set} ]]; then
  echo "$key is on the network"
fi
if [[ -z ${zones[Vellin Halt]+set} ]]; then
  echo "Vellin Halt is not"
fi
echo "missing key: ${zones["Vellin Halt"]:-unknown}"

unset 'zones["Saltwick Halt"]'
echo "after unset: ${#zones[@]} entries"

# Counting with an associative array.
declare -A tally=()
for character in $(echo mississippi | fold -w1); do
  tally[$character]=$(( ${tally[$character]:-0} + 1 ))
done
for character in "${!tally[@]}"; do
  printf '  %s=%d\n' "$character" "${tally[$character]}"
done | sort
