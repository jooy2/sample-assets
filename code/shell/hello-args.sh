#!/usr/bin/env bash
# Positional parameters, defaults, and the special variables around them.

set -euo pipefail

echo "script:    $0"
echo "basename:  ${0##*/}"
echo "count:     $#"
echo "all (\$*): $*"
echo "all (\$@): $@"

# "$@" keeps each argument separate; "$*" joins them into one word.
printf 'each argument on its own line:\n'
for argument in "$@"; do
  printf '  [%s]\n' "$argument"
done

# ${1:-default} substitutes when the parameter is unset or empty.
name=${1:-world}
greeting=${2:-Hello}
echo "${greeting}, ${name}!"

# ${1:?message} exits with the message when the parameter is missing.
# Uncomment to see it: set -- ; : "${1:?a name is required}"

# shift drops the first parameter and renumbers the rest.
set -- alpha beta gamma
echo "before shift: \$1=$1 \$#=$#"
shift
echo "after shift:  \$1=$1 \$#=$#"

# The last exit status, and this shell's process id.
true
echo "status of true:  $?"
if ! false; then
  echo "status of false: 1 (checked with if, not with \$?)"
fi
echo "pid:             $$"

# An array is the safe way to build up a command line.
command=(printf '%s=%s\n')
command+=(zone 2)
"${command[@]}"

# "$@" inside a function refers to the function's own arguments.
show_args() {
  echo "the function got $# argument(s): $*"
}
show_args one "two words" three
