#!/usr/bin/env bash
# A small backup script: archive a directory, keep the newest N, and report
# what was removed. The shape most maintenance scripts end up in.

set -euo pipefail

KEEP=${KEEP:-3}
readonly KEEP

usage() {
  cat <<'USAGE'
usage: backup-rotate.sh [-k COUNT] [-n] SOURCE_DIR BACKUP_DIR

  -k COUNT  how many archives to keep (default 3, or $KEEP)
  -n        dry run: say what would happen, change nothing
USAGE
}

keep=$KEEP
dry_run=0

while getopts ':k:nh' option; do
  case $option in
    k) keep=$OPTARG ;;
    n) dry_run=1 ;;
    h) usage; exit 0 ;;
    :) echo "-$OPTARG needs an argument" >&2; exit 2 ;;
    \?) echo "unknown option: -$OPTARG" >&2; usage >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

log() { printf '[%(%Y-%m-%dT%H:%M:%S)T] %s\n' -1 "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
run() { if ((dry_run)); then printf '  would run: %s\n' "$*"; else "$@"; fi; }

# Build a demonstration source and destination when none are given, so the
# sample does something on its own.
scratch=''
if (($# < 2)); then
  scratch=$(mktemp -d "${TMPDIR:-/tmp}/sample-assets-XXXXXX")
  trap 'rm -rf "$scratch"' EXIT
  mkdir -p "$scratch/source/datasets" "$scratch/backups"
  printf 'station,line,zone\nAlder Cross,Amber,2\n' > "$scratch/source/datasets/stations.csv"
  printf 'a note\n' > "$scratch/source/README.md"
  set -- "$scratch/source" "$scratch/backups"
  log "no arguments given, using a temporary workspace"
fi

source_dir=$1
backup_dir=$2

[[ -d $source_dir ]] || die "$source_dir is not a directory"
[[ $keep =~ ^[0-9]+$ ]] && ((keep > 0)) || die "-k needs a positive number, got '$keep'"

mkdir -p "$backup_dir"

log "source  $source_dir"
log "backups $backup_dir (keeping $keep)"

# Make a few archives, so the rotation below has something to work on.
for offset in 3 2 1 0; do
  stamp=$(printf '2025110%d-0900' "$((5 - offset))")
  archive="$backup_dir/$(basename "$source_dir")-$stamp.tar.gz"

  if [[ -e $archive ]]; then
    log "skipping $stamp, it already exists"
    continue
  fi

  run tar -czf "$archive" -C "$(dirname "$source_dir")" "$(basename "$source_dir")"
  ((dry_run)) || log "created $(basename "$archive") ($(wc -c < "$archive" | tr -d ' ') bytes)"
done

# Rotate: list newest first, then remove everything past the keep count.
mapfile -t archives < <(find "$backup_dir" -maxdepth 1 -name '*.tar.gz' -type f | sort -r)

log "found ${#archives[@]} archive(s)"

if ((${#archives[@]} > keep)); then
  for archive in "${archives[@]:keep}"; do
    log "removing $(basename "$archive")"
    run rm -f "$archive"
  done
else
  log "nothing to rotate"
fi

remaining=$(find "$backup_dir" -maxdepth 1 -name '*.tar.gz' -type f | wc -l | tr -d ' ')
log "$remaining archive(s) left"

((dry_run)) && log "dry run: nothing was changed"
exit 0
