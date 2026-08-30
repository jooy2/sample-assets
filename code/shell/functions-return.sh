#!/usr/bin/env bash
# Functions: arguments, exit status, output, and local scope.

set -euo pipefail

# `return` sets the exit status, which is 0-255 and means success/failure.
is_valid_zone() {
  local zone=$1
  [[ $zone =~ ^[0-9]+$ ]] || return 1
  ((zone >= 1 && zone <= 6))
}

# A value is returned by printing it and capturing the output.
fare_for() {
  local zones=$1
  local base=${2:-2.40}
  awk -v base="$base" -v zones="$zones" 'BEGIN { printf "%.2f", base + zones * 0.85 }'
}

# local keeps a variable inside the function; without it, everything is global.
counter=0
bump() {
  local counter=100 # shadows the global
  ((counter++))
  echo "inside: $counter"
}

# Assigning to a caller's variable through a nameref avoids a subshell.
split_name() {
  local -n first_ref=$1
  local -n last_ref=$2
  local full=$3
  first_ref=${full%% *}
  last_ref=${full##* }
}

# A function can take a callback by name.
each_zone() {
  local callback=$1
  local zone
  for zone in {1..3}; do
    "$callback" "$zone"
  done
}

describe_zone() {
  echo "  zone $1 is $([[ $1 -le 2 ]] && echo central || echo outer)"
}

for candidate in 3 9 east; do
  if is_valid_zone "$candidate"; then
    echo "$candidate is a valid zone, fare $(fare_for "$candidate")"
  else
    echo "$candidate is not a valid zone"
  fi
done

bump
echo "outside: $counter (untouched by the local)"

split_name first last "Imogen Hawthorne"
echo "first=$first last=$last"

each_zone describe_zone

# Recursion works, with the usual caveats about depth.
factorial() {
  local n=$1
  ((n <= 1)) && { echo 1; return; }
  echo $((n * $(factorial $((n - 1)))))
}
echo "10! = $(factorial 10)"

# Writing diagnostics to stderr keeps them out of a captured value.
warn() { printf 'warning: %s\n' "$*" >&2; }
captured=$(warn "this goes to the terminal, not into the variable"; echo value)
echo "captured=[$captured]"

# `declare -f` shows a function's definition; `unset -f` removes it.
echo "defined functions: $(declare -F | wc -l | tr -d ' ')"
