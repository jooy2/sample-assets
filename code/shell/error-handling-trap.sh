#!/usr/bin/env bash
# set -euo pipefail, trap, and the cleanup that survives a failure.

# -e   exit on an unhandled non-zero status
# -u   treat an unset variable as an error
# -o pipefail  a pipeline fails if any stage does, not only the last
set -euo pipefail

workspace=$(mktemp -d "${TMPDIR:-/tmp}/sample-assets-XXXXXX")

# EXIT runs on any exit; ERR only on a failing command; INT and TERM on
# signals. Quote the handler so $workspace is read when it fires.
cleanup() {
  local status=$?
  rm -rf "$workspace"
  ((status == 0)) && echo "cleaned up after a clean exit" || echo "cleaned up after status $status"
}
trap cleanup EXIT
trap 'echo "failed at line $LINENO: $BASH_COMMAND" >&2' ERR
trap 'echo "interrupted" >&2; exit 130' INT TERM

echo "workspace: ${workspace##*/}"

# Without pipefail, this pipeline would report success.
if ! false | cat; then
  echo "pipefail caught the failure in the first stage"
fi

# -u turns a typo into an error instead of an empty string.
name='Alder Cross'
echo "set: $name"
echo "unset with a default: ${missing:-fallback}"

# Guarding a command that is allowed to fail, so -e does not end the script.
if ! grep -q 'Vellin' <<< "$name"; then
  echo "grep found nothing, and the script carried on"
fi

status=0
grep -q 'Vellin' <<< "$name" || status=$?
echo "captured status: $status"

# `|| true` is the blunt version of the same thing.
false || true
echo "still running"

# A function that reports failure the normal way: a non-zero return.
parse_zone() {
  local raw=$1
  [[ $raw =~ ^[0-9]+$ ]] || { echo "'$raw' is not a number" >&2; return 2; }
  ((raw >= 1 && raw <= 6)) || { echo "zone $raw is outside 1-6" >&2; return 3; }
  echo "$raw"
}

for candidate in 3 9 east; do
  if zone=$(parse_zone "$candidate" 2>/dev/null); then
    printf '%-6s -> zone %s\n' "$candidate" "$zone"
  else
    printf '%-6s -> rejected with status %d\n' "$candidate" "$?"
  fi
done

# A subshell keeps a `cd` or a variable change from leaking out.
(
  cd "$workspace"
  echo "inside the subshell: ${PWD##*/}"
)
echo "outside it: still in ${PWD##*/}"

# die() is the usual helper for an unrecoverable problem.
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
[[ -d $workspace ]] || die "the workspace vanished"

echo "finished"
