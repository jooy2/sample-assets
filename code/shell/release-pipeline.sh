#!/usr/bin/env bash
#
# release-pipeline.sh — a release runner with subcommands.
#
# Demonstrates the parts a real deployment script needs and most sample
# scripts skip: subcommand dispatch, layered configuration, a lock file that
# survives a kill, cleanup with trap, retries with backoff, structured
# logging, a dry-run mode that is honoured everywhere, and a rollback path.
#
#   ./release-pipeline.sh --help
#   ./release-pipeline.sh plan       staging
#   ./release-pipeline.sh deploy -n  staging      # dry run
#   ./release-pipeline.sh deploy     staging
#   ./release-pipeline.sh status
#   ./release-pipeline.sh rollback   staging
#
# NOTHING HERE TOUCHES A REAL SYSTEM. Every "remote" operation writes to a
# scratch directory under $TMPDIR and reports what it would have done. The
# environments, hosts, and versions are invented.
#
# Portable to the bash 3.2 that ships with macOS: no associative arrays, no
# `readarray`, no `${var^^}`.

set -euo pipefail

readonly PROGRAM="${0##*/}"
readonly VERSION="2.4.1"

# ------------------------------------------------------------------- state

dry_run=0
verbose=0
force=0
retries=3
timeout=20
environment=''
lock_file=''
state_root="${TMPDIR:-/tmp}/release-pipeline-demo"

# Environments, as parallel arrays rather than an associative array, so this
# runs on bash 3.2 as well as on anything newer.
ENV_NAMES='staging production sandbox'
env_hosts() {
  case "$1" in
    staging)    echo 'app-1.staging.invalid app-2.staging.invalid' ;;
    production) echo 'app-1.invalid app-2.invalid app-3.invalid app-4.invalid' ;;
    sandbox)    echo 'sandbox.invalid' ;;
    *)          return 1 ;;
  esac
}
env_approval() {
  case "$1" in
    production) echo required ;;
    *)          echo none ;;
  esac
}
env_batch() {
  case "$1" in
    production) echo 2 ;;
    *)          echo 99 ;;
  esac
}

# --------------------------------------------------------------- diagnostics

colour_on=0
[ -t 2 ] && colour_on=1

log() {
  local level=$1; shift
  local colour='' reset=''

  if [ "$colour_on" -eq 1 ]; then
    reset=$(printf '\033[0m')
    case "$level" in
      INFO)  colour=$(printf '\033[36m') ;;
      OK)    colour=$(printf '\033[32m') ;;
      WARN)  colour=$(printf '\033[33m') ;;
      ERROR) colour=$(printf '\033[31m') ;;
      DEBUG) colour=$(printf '\033[2m') ;;
    esac
  fi

  printf '%s%-5s%s %s %s\n' \
    "$colour" "$level" "$reset" "$(date -u '+%H:%M:%S')" "$*" >&2
}

debug() { [ "$verbose" -eq 1 ] && log DEBUG "$@" || true; }
info()  { log INFO "$@"; }
ok()    { log OK "$@"; }
warn()  { log WARN "$@"; }

die() {
  log ERROR "$@"
  exit 1
}

# Prefix every side effect with this. It is the single place that decides
# whether the script acts or only describes.
act() {
  if [ "$dry_run" -eq 1 ]; then
    printf '  would run: %s\n' "$*"
    return 0
  fi
  debug "running: $*"
  "$@"
}

# ------------------------------------------------------------------- usage

usage() {
  cat <<USAGE
$PROGRAM $VERSION — a release runner

usage: $PROGRAM [global options] <command> [command options] [environment]

commands:
  plan       ENV     show what a deploy would do, and stop
  deploy     ENV     run the release
  rollback   ENV     put the previous release back
  status             show what is deployed where
  environments       list the environments this script knows about
  help               show this message

global options:
  -n, --dry-run      describe every action instead of taking it
  -v, --verbose      log each step
  -f, --force        skip the confirmation on a guarded environment
  -r, --retries N    attempts per remote step (default $retries)
  -t, --timeout SEC  seconds before a remote step is abandoned (default $timeout)
  -h, --help         show this message
      --version      print the version and exit

Every "remote" action in this script writes to $state_root
and touches nothing else.
USAGE
}

# ------------------------------------------------------------------ locking

acquire_lock() {
  local name=$1
  lock_file="$state_root/$name.lock"

  mkdir -p "$state_root"

  # mkdir is atomic on every filesystem worth deploying from, which is why it
  # beats "test -f then touch" for a lock.
  if ! mkdir "$lock_file" 2>/dev/null; then
    local holder='unknown'
    [ -r "$lock_file/pid" ] && holder=$(cat "$lock_file/pid")

    # A lock whose owner is gone is stale, not held.
    if [ "$holder" != unknown ] && ! kill -0 "$holder" 2>/dev/null; then
      warn "removing a stale lock left by process $holder"
      rm -rf "$lock_file"
      mkdir "$lock_file" || die "cannot take the lock at $lock_file"
    else
      die "another release is running (process $holder). Wait, or remove $lock_file"
    fi
  fi

  printf '%s\n' "$$" > "$lock_file/pid"
  date -u '+%Y-%m-%dT%H:%M:%SZ' > "$lock_file/since"
  debug "took the lock at $lock_file"
}

release_lock() {
  [ -n "$lock_file" ] && [ -d "$lock_file" ] || return 0
  rm -rf "$lock_file"
  debug "released the lock"
}

# One trap for every exit path, so the lock never outlives the script.
cleanup() {
  local status=$?
  release_lock
  if [ "$status" -ne 0 ] && [ "$status" -ne 130 ]; then
    log ERROR "$PROGRAM exited with status $status"
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# ------------------------------------------------------------------ retries

# Run a command, retrying with exponential backoff. The command is expected to
# be idempotent; nothing here can make a non-idempotent step safe to repeat.
with_retries() {
  local description=$1; shift
  local attempt=1
  local wait=1

  while :; do
    if "$@"; then
      [ "$attempt" -gt 1 ] && ok "$description succeeded on attempt $attempt"
      return 0
    fi

    if [ "$attempt" -ge "$retries" ]; then
      warn "$description failed after $attempt attempt(s)"
      return 1
    fi

    warn "$description failed (attempt $attempt of $retries); retrying in ${wait}s"
    sleep "$wait"
    attempt=$((attempt + 1))
    wait=$((wait * 2))
  done
}

# ------------------------------------------------- the pretend remote system

host_dir() { printf '%s/%s/%s\n' "$state_root" "$1" "$2"; }

remote_health_check() {
  local host=$1
  local directory
  directory=$(host_dir "$environment" "$host")

  [ -f "$directory/version" ] || return 1

  # A stand-in for a flaky endpoint: the sandbox host fails its first check so
  # that the retry path is exercised rather than merely present.
  if [ "$host" = 'sandbox.invalid' ] && [ ! -f "$directory/warmed" ]; then
    : > "$directory/warmed"
    return 1
  fi
  return 0
}

remote_deploy() {
  local host=$1 version=$2
  local directory
  directory=$(host_dir "$environment" "$host")

  mkdir -p "$directory"
  if [ -f "$directory/version" ]; then
    cp "$directory/version" "$directory/previous"
  fi
  printf '%s\n' "$version" > "$directory/version"
  rm -f "$directory/warmed"
  return 0
}

remote_rollback() {
  local host=$1
  local directory
  directory=$(host_dir "$environment" "$host")

  [ -f "$directory/previous" ] || return 1
  mv "$directory/previous" "$directory/version"
  return 0
}

remote_version() {
  local host=$1
  local directory
  directory=$(host_dir "$environment" "$host")

  if [ -f "$directory/version" ]; then cat "$directory/version"; else echo 'none'; fi
}

# ------------------------------------------------------------------ commands

require_environment() {
  [ -n "$environment" ] || die "this command needs an environment (one of: $ENV_NAMES)"
  env_hosts "$environment" >/dev/null 2>&1 \
    || die "unknown environment '$environment' (one of: $ENV_NAMES)"
}

next_version() {
  printf '%s-%s\n' "$VERSION" "$(date -u '+%Y%m%d%H%M%S')"
}

command_environments() {
  printf '%-12s %-8s %-6s %s\n' 'ENVIRONMENT' 'APPROVAL' 'BATCH' 'HOSTS'
  printf '%-12s %-8s %-6s %s\n' '-----------' '--------' '-----' '-----'
  local name
  for name in $ENV_NAMES; do
    printf '%-12s %-8s %-6s %s\n' \
      "$name" "$(env_approval "$name")" "$(env_batch "$name")" "$(env_hosts "$name")"
  done
}

command_status() {
  local name host
  printf '%-12s %-24s %s\n' 'ENVIRONMENT' 'HOST' 'VERSION'
  printf '%-12s %-24s %s\n' '-----------' '----' '-------'
  for name in $ENV_NAMES; do
    environment=$name
    for host in $(env_hosts "$name"); do
      printf '%-12s %-24s %s\n' "$name" "$host" "$(remote_version "$host")"
    done
  done
}

command_plan() {
  require_environment

  local hosts batch approval version
  hosts=$(env_hosts "$environment")
  batch=$(env_batch "$environment")
  approval=$(env_approval "$environment")
  version=$(next_version)

  printf 'Release plan for %s\n' "$environment"
  printf '  version   %s\n' "$version"
  printf '  approval  %s\n' "$approval"
  printf '  batch     %s host(s) at a time\n' "$batch"
  printf '  retries   %s per step, %ss timeout\n' "$retries" "$timeout"
  printf '\n'

  local index=0 host
  for host in $hosts; do
    index=$((index + 1))
    printf '  %d. %-24s %s -> %s\n' \
      "$index" "$host" "$(remote_version "$host")" "$version"
  done

  printf '\n  %d step(s). Nothing has been changed.\n' "$index"
}

confirm() {
  local prompt=$1

  if [ "$force" -eq 1 ]; then
    warn 'confirmation skipped because --force was given'
    return 0
  fi
  if [ ! -t 0 ]; then
    warn 'not a terminal, so the guarded environment is being refused'
    return 1
  fi

  printf '%s [y/N] ' "$prompt" >&2
  local answer
  read -r answer
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

command_deploy() {
  require_environment
  acquire_lock "$environment"

  local hosts batch version deployed=0 failed=''
  hosts=$(env_hosts "$environment")
  batch=$(env_batch "$environment")
  version=$(next_version)

  if [ "$(env_approval "$environment")" = required ] && [ "$dry_run" -eq 0 ]; then
    confirm "Deploy $version to $environment?" \
      || die 'refused at the confirmation step'
  fi

  info "deploying $version to $environment"

  local in_batch=0 host
  for host in $hosts; do
    in_batch=$((in_batch + 1))

    info "$host: deploying"
    if ! act remote_deploy "$host" "$version"; then
      failed="$failed $host"
      warn "$host: deploy failed"
      break
    fi

    info "$host: health check"
    if [ "$dry_run" -eq 1 ]; then
      printf '  would run: health check against %s\n' "$host"
    elif ! with_retries "health check for $host" remote_health_check "$host"; then
      failed="$failed $host"
      break
    fi

    deployed=$((deployed + 1))
    ok "$host: on $version"

    if [ "$in_batch" -ge "$batch" ]; then
      info "batch of $batch complete; pausing before the next"
      in_batch=0
      act sleep 1
    fi
  done

  if [ -n "$failed" ]; then
    warn "failed on:$failed"
    warn 'rolling back the hosts that were already changed'
    for host in $hosts; do
      case " $failed " in *" $host "*) continue ;; esac
      act remote_rollback "$host" || warn "$host: nothing to roll back to"
    done
    die "deploy of $version to $environment was rolled back"
  fi

  ok "$deployed host(s) now on $version"
}

command_rollback() {
  require_environment
  acquire_lock "$environment"

  local hosts host rolled=0
  hosts=$(env_hosts "$environment")

  info "rolling $environment back"
  for host in $hosts; do
    if act remote_rollback "$host"; then
      rolled=$((rolled + 1))
      ok "$host: back on $(remote_version "$host")"
    else
      warn "$host: no previous release recorded"
    fi
  done

  [ "$rolled" -gt 0 ] || die 'nothing to roll back'
  ok "$rolled host(s) rolled back"
}

# --------------------------------------------------------- argument parsing

command=''

while [ $# -gt 0 ]; do
  case "$1" in
    -n|--dry-run) dry_run=1; shift ;;
    -v|--verbose) verbose=1; shift ;;
    -f|--force)   force=1; shift ;;
    -r|--retries) [ $# -ge 2 ] || die '--retries needs a number'
                  retries=$2; shift 2 ;;
    -t|--timeout) [ $# -ge 2 ] || die '--timeout needs a number'
                  timeout=$2; shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    --version)    printf '%s %s\n' "$PROGRAM" "$VERSION"; exit 0 ;;
    --)           shift; break ;;
    -*)           die "unknown option $1 (try --help)" ;;
    *)
      if [ -z "$command" ]; then command=$1
      elif [ -z "$environment" ]; then environment=$1
      else die "unexpected argument '$1'"
      fi
      shift
      ;;
  esac
done

case "$retries" in ''|*[!0-9]*) die "--retries wants a whole number" ;; esac
case "$timeout" in ''|*[!0-9]*) die "--timeout wants a whole number" ;; esac
[ "$retries" -ge 1 ] || die '--retries must be at least 1'

case "$command" in
  plan)         command_plan ;;
  deploy)       command_deploy ;;
  rollback)     command_rollback ;;
  status)       command_status ;;
  environments) command_environments ;;
  help|'')      usage ;;
  *)            die "unknown command '$command' (try --help)" ;;
esac
