#!/usr/bin/env bash
# A command line interface with getopts: short options, a usage message,
# and a hand-rolled pass for long options.

set -euo pipefail

verbose=0
repeat=1
output=''
dry_run=0

usage() {
  cat <<'USAGE'
usage: getopts-cli.sh [-v] [-n COUNT] [-o FILE] [--dry-run] NAME...

  -v          verbose: log what is happening to stderr
  -n COUNT    repeat the greeting COUNT times (default 1)
  -o FILE     write to FILE instead of standard output
  -h          show this message
  --dry-run   print what would happen, without doing it
USAGE
}

log() { ((verbose)) && printf '[%s] %s\n' "${0##*/}" "$*" >&2 || true; }

# getopts handles only short options, so long ones are peeled off first.
arguments=()
for argument in "$@"; do
  case $argument in
    --dry-run) dry_run=1 ;;
    --help) usage; exit 0 ;;
    --*) printf 'unknown option: %s\n' "$argument" >&2; usage >&2; exit 2 ;;
    *) arguments+=("$argument") ;;
  esac
done
set -- "${arguments[@]+"${arguments[@]}"}"

# A leading colon puts getopts into silent mode, so this script reports the
# errors itself.
while getopts ':vn:o:h' option; do
  case $option in
    v) verbose=1 ;;
    n) repeat=$OPTARG ;;
    o) output=$OPTARG ;;
    h) usage; exit 0 ;;
    :) printf -- '-%s needs an argument\n' "$OPTARG" >&2; exit 2 ;;
    \?) printf -- 'unknown option: -%s\n' "$OPTARG" >&2; usage >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

# Whatever is left over is positional.
if (($# == 0)); then
  set -- "Alder Cross" # a default, so the sample does something on its own
fi

[[ $repeat =~ ^[0-9]+$ ]] || { echo "-n needs a number, got '$repeat'" >&2; exit 2; }

log "verbose=$verbose repeat=$repeat output=${output:-<stdout>} dry_run=$dry_run"
log "$# name(s) to greet"

emit() {
  if ((dry_run)); then
    printf 'would write: %s\n' "$*"
  elif [[ -n $output ]]; then
    printf '%s\n' "$*" >> "$output"
  else
    printf '%s\n' "$*"
  fi
}

for ((round = 0; round < repeat; round++)); do
  for name in "$@"; do
    emit "Hello, $name!"
  done
done

[[ -n $output ]] && log "wrote to $output"
exit 0
