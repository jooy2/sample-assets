#!/usr/bin/env bash
#
# log-report.sh — summarise a web access log.
#
# Reads combined-format access logs (or the sample built into this file) and
# prints traffic by status class, the busiest paths and clients, response-time
# percentiles, an hourly histogram, and a list of anything worth looking at.
#
#   ./log-report.sh                       report on the built-in sample
#   ./log-report.sh access.log            report on a file
#   gzip -dc access.log.gz | ./log-report.sh -
#   ./log-report.sh --top 20 --slow 500 access.log
#
# Portable: POSIX awk, no GNU-only options, and no bash 4 features, so it runs
# on the bash 3.2 that ships with macOS as well as on Linux.
#
# The log below is invented. No address or host in it is real.

set -euo pipefail

readonly PROGRAM="${0##*/}"

# ------------------------------------------------------------------ defaults

top_count=10
slow_ms=300
show_sample=0
colour=auto

# ---------------------------------------------------------------- utilities

usage() {
  cat <<USAGE
usage: $PROGRAM [options] [FILE|-]

  -n, --top N        show the top N entries in each table (default $top_count)
  -s, --slow MS      treat a response slower than MS as slow (default $slow_ms)
      --sample       print the built-in sample log and exit
      --colour WHEN  always, never, or auto (default auto)
  -h, --help         show this message

With no FILE, or with "-", the report is built from the sample log embedded
in this script.
USAGE
}

die() {
  printf '%s: %s\n' "$PROGRAM" "$*" >&2
  exit 1
}

# Colour only when writing to a terminal, unless told otherwise.
setup_colour() {
  if [ "$colour" = always ] || { [ "$colour" = auto ] && [ -t 1 ]; }; then
    BOLD=$(printf '\033[1m')
    DIM=$(printf '\033[2m')
    RESET=$(printf '\033[0m')
  else
    BOLD='' DIM='' RESET=''
  fi
}

heading() {
  printf '\n%s%s%s\n' "$BOLD" "$*" "$RESET"
  printf '%s%s%s\n' "$DIM" "$(printf '%.0s-' $(seq 1 ${#1}))" "$RESET"
}

# --------------------------------------------------------------- the sample

sample_log() {
  cat <<'LOG'
198.51.100.24 - - [02/Sep/2027:06:14:02 +0000] "GET /timetable HTTP/1.1" 200 8241 "-" "Mozilla/5.0" 84
198.51.100.24 - - [02/Sep/2027:06:14:03 +0000] "GET /assets/app.css HTTP/1.1" 200 14022 "-" "Mozilla/5.0" 12
203.0.113.7 - - [02/Sep/2027:06:22:41 +0000] "GET /timetable HTTP/1.1" 200 8241 "-" "curl/8.4.0" 76
203.0.113.7 - - [02/Sep/2027:06:22:44 +0000] "GET /api/routes HTTP/1.1" 200 2104 "-" "curl/8.4.0" 41
192.0.2.115 - - [02/Sep/2027:07:01:19 +0000] "GET / HTTP/1.1" 200 5120 "-" "Mozilla/5.0" 58
192.0.2.115 - - [02/Sep/2027:07:01:22 +0000] "GET /timetable HTTP/1.1" 200 8241 "-" "Mozilla/5.0" 91
198.51.100.88 - - [02/Sep/2027:07:33:07 +0000] "POST /api/bookings HTTP/1.1" 201 312 "-" "Mozilla/5.0" 412
198.51.100.88 - - [02/Sep/2027:07:33:09 +0000] "GET /bookings/8812 HTTP/1.1" 200 4410 "-" "Mozilla/5.0" 133
203.0.113.201 - - [02/Sep/2027:08:02:55 +0000] "GET /timetable HTTP/1.1" 200 8241 "-" "Mozilla/5.0" 88
203.0.113.201 - - [02/Sep/2027:08:03:12 +0000] "GET /api/routes HTTP/1.1" 200 2104 "-" "Mozilla/5.0" 39
192.0.2.9 - - [02/Sep/2027:08:15:40 +0000] "GET /admin HTTP/1.1" 403 174 "-" "python-requests/2.31" 8
192.0.2.9 - - [02/Sep/2027:08:15:41 +0000] "GET /.env HTTP/1.1" 404 152 "-" "python-requests/2.31" 5
192.0.2.9 - - [02/Sep/2027:08:15:42 +0000] "GET /wp-login.php HTTP/1.1" 404 152 "-" "python-requests/2.31" 4
192.0.2.9 - - [02/Sep/2027:08:15:43 +0000] "GET /.git/config HTTP/1.1" 404 152 "-" "python-requests/2.31" 5
192.0.2.9 - - [02/Sep/2027:08:15:45 +0000] "GET /backup.sql HTTP/1.1" 404 152 "-" "python-requests/2.31" 4
198.51.100.24 - - [02/Sep/2027:08:44:11 +0000] "GET /timetable HTTP/1.1" 200 8241 "-" "Mozilla/5.0" 79
203.0.113.44 - - [02/Sep/2027:09:12:30 +0000] "GET /api/routes HTTP/1.1" 200 2104 "-" "okhttp/4.12" 44
203.0.113.44 - - [02/Sep/2027:09:12:31 +0000] "GET /api/sailings?route=HRB HTTP/1.1" 200 18422 "-" "okhttp/4.12" 622
203.0.113.44 - - [02/Sep/2027:09:12:39 +0000] "GET /api/sailings?route=KSP HTTP/1.1" 200 16210 "-" "okhttp/4.12" 588
198.51.100.150 - - [02/Sep/2027:09:40:02 +0000] "GET /timetable HTTP/1.1" 200 8241 "-" "Mozilla/5.0" 82
198.51.100.150 - - [02/Sep/2027:09:40:18 +0000] "POST /api/bookings HTTP/1.1" 500 88 "-" "Mozilla/5.0" 1204
198.51.100.150 - - [02/Sep/2027:09:41:02 +0000] "POST /api/bookings HTTP/1.1" 500 88 "-" "Mozilla/5.0" 1188
198.51.100.150 - - [02/Sep/2027:09:42:31 +0000] "POST /api/bookings HTTP/1.1" 201 312 "-" "Mozilla/5.0" 402
192.0.2.240 - - [02/Sep/2027:10:05:00 +0000] "GET / HTTP/1.1" 200 5120 "-" "Mozilla/5.0" 61
192.0.2.240 - - [02/Sep/2027:10:05:11 +0000] "GET /assets/app.css HTTP/1.1" 304 0 "-" "Mozilla/5.0" 3
192.0.2.240 - - [02/Sep/2027:10:05:12 +0000] "GET /assets/app.js HTTP/1.1" 304 0 "-" "Mozilla/5.0" 3
203.0.113.7 - - [02/Sep/2027:10:22:18 +0000] "GET /api/sailings?route=HLW HTTP/1.1" 200 9044 "-" "curl/8.4.0" 344
198.51.100.24 - - [02/Sep/2027:11:00:41 +0000] "GET /timetable HTTP/1.1" 200 8241 "-" "Mozilla/5.0" 85
198.51.100.24 - - [02/Sep/2027:11:00:58 +0000] "GET /fares HTTP/1.1" 200 6612 "-" "Mozilla/5.0" 74
203.0.113.99 - - [02/Sep/2027:11:31:26 +0000] "GET /timetable HTTP/1.1" 200 8241 "-" "Mozilla/5.0" 90
203.0.113.99 - - [02/Sep/2027:11:31:44 +0000] "GET /missing-page HTTP/1.1" 404 152 "-" "Mozilla/5.0" 6
192.0.2.115 - - [02/Sep/2027:12:14:09 +0000] "GET /fares HTTP/1.1" 200 6612 "-" "Mozilla/5.0" 71
192.0.2.115 - - [02/Sep/2027:12:14:22 +0000] "POST /api/bookings HTTP/1.1" 201 312 "-" "Mozilla/5.0" 398
198.51.100.203 - - [02/Sep/2027:13:02:11 +0000] "GET /timetable HTTP/1.1" 200 8241 "-" "Mozilla/5.0" 86
198.51.100.203 - - [02/Sep/2027:13:02:40 +0000] "GET /api/sailings?route=NCR HTTP/1.1" 200 3120 "-" "Mozilla/5.0" 118
203.0.113.7 - - [02/Sep/2027:14:18:52 +0000] "GET /timetable HTTP/1.1" 200 8241 "-" "curl/8.4.0" 80
203.0.113.7 - - [02/Sep/2027:14:19:30 +0000] "GET /api/routes HTTP/1.1" 304 0 "-" "curl/8.4.0" 7
192.0.2.31 - - [02/Sep/2027:15:44:03 +0000] "GET /timetable HTTP/1.1" 200 8241 "-" "Mozilla/5.0" 94
192.0.2.31 - - [02/Sep/2027:15:44:29 +0000] "GET /fares HTTP/1.1" 200 6612 "-" "Mozilla/5.0" 77
192.0.2.31 - - [02/Sep/2027:15:45:02 +0000] "POST /api/bookings HTTP/1.1" 422 210 "-" "Mozilla/5.0" 96
192.0.2.31 - - [02/Sep/2027:15:45:40 +0000] "POST /api/bookings HTTP/1.1" 201 312 "-" "Mozilla/5.0" 388
198.51.100.24 - - [02/Sep/2027:16:30:14 +0000] "GET /timetable HTTP/1.1" 200 8241 "-" "Mozilla/5.0" 83
203.0.113.166 - - [02/Sep/2027:17:02:44 +0000] "GET / HTTP/1.1" 200 5120 "-" "Mozilla/5.0" 60
203.0.113.166 - - [02/Sep/2027:17:03:01 +0000] "GET /timetable HTTP/1.1" 200 8241 "-" "Mozilla/5.0" 87
203.0.113.166 - - [02/Sep/2027:17:04:22 +0000] "GET /api/sailings?route=HRB HTTP/1.1" 200 18422 "-" "Mozilla/5.0" 640
192.0.2.9 - - [02/Sep/2027:18:00:01 +0000] "GET /.env HTTP/1.1" 404 152 "-" "python-requests/2.31" 5
192.0.2.9 - - [02/Sep/2027:18:00:02 +0000] "GET /config.json HTTP/1.1" 404 152 "-" "python-requests/2.31" 4
198.51.100.77 - - [02/Sep/2027:19:12:33 +0000] "GET /timetable HTTP/1.1" 200 8241 "-" "Mozilla/5.0" 89
198.51.100.77 - - [02/Sep/2027:19:13:04 +0000] "GET /api/sailings?route=NCR HTTP/1.1" 503 66 "-" "Mozilla/5.0" 30012
198.51.100.77 - - [02/Sep/2027:19:14:10 +0000] "GET /api/sailings?route=NCR HTTP/1.1" 200 3120 "-" "Mozilla/5.0" 121
203.0.113.7 - - [02/Sep/2027:21:40:55 +0000] "GET /timetable HTTP/1.1" 200 8241 "-" "curl/8.4.0" 78
LOG
}

# ----------------------------------------------------------- argument parsing

while [ $# -gt 0 ]; do
  case "$1" in
    -n|--top)    [ $# -ge 2 ] || die "$1 needs a number"; top_count=$2; shift 2 ;;
    -s|--slow)   [ $# -ge 2 ] || die "$1 needs a number"; slow_ms=$2; shift 2 ;;
    --sample)    show_sample=1; shift ;;
    --colour|--color)
                 [ $# -ge 2 ] || die "$1 needs a value"; colour=$2; shift 2 ;;
    -h|--help)   usage; exit 0 ;;
    --)          shift; break ;;
    -)           break ;;
    -*)          die "unknown option $1 (try --help)" ;;
    *)           break ;;
  esac
done

case "$top_count" in
  ''|*[!0-9]*) die "--top wants a whole number, got '$top_count'" ;;
esac
case "$slow_ms" in
  ''|*[!0-9]*) die "--slow wants a whole number, got '$slow_ms'" ;;
esac
case "$colour" in
  always|never|auto) ;;
  *) die "--colour wants always, never, or auto" ;;
esac

if [ "$show_sample" -eq 1 ]; then
  sample_log
  exit 0
fi

setup_colour

# ------------------------------------------------------------- reading input

# A temporary file so the log can be scanned several times, whether it came
# from a file, from a pipe, or from the built-in sample.
work=$(mktemp "${TMPDIR:-/tmp}/log-report.XXXXXX") || die 'cannot create a temporary file'
trap 'rm -f "$work"' EXIT INT TERM

source_name='the built-in sample'
if [ $# -gt 0 ] && [ "$1" != '-' ]; then
  [ -r "$1" ] || die "cannot read $1"
  source_name=$1
  cat -- "$1" > "$work"
elif [ $# -gt 0 ] && [ "$1" = '-' ]; then
  source_name='standard input'
  cat > "$work"
else
  sample_log > "$work"
fi

total=$(wc -l < "$work" | tr -d ' ')
[ "$total" -gt 0 ] || die 'the log is empty'

# ---------------------------------------------------------------- the report

printf '%sAccess log report%s\n' "$BOLD" "$RESET"
printf '  source: %s\n' "$source_name"
printf '  lines:  %s\n' "$total"

heading 'By status class'
awk '
  { class = substr($9, 1, 1) "xx"; count[class]++; bytes[class] += $10 }
  END {
    order["1xx"] = 1; order["2xx"] = 2; order["3xx"] = 3
    order["4xx"] = 4; order["5xx"] = 5
    for (c in count) printf "%d\t%s\t%d\t%d\n", order[c], c, count[c], bytes[c]
  }
' "$work" | sort -n | awk -v total="$total" '
  { printf "  %-5s %5d  %5.1f%%  %10.1f KB\n", $2, $3, $3 * 100 / total, $4 / 1024 }
'

heading 'By exact status'
awk '{ count[$9]++ } END { for (s in count) printf "%s\t%d\n", s, count[s] }' "$work" \
  | sort -k2,2nr -k1,1n \
  | awk -v n="$top_count" 'NR <= n { printf "  %-6s %5d\n", $1, $2 }'

heading "Busiest paths (top $top_count)"
awk '{ print $7 }' "$work" \
  | sed 's/?.*//' \
  | sort | uniq -c | sort -rn \
  | awk -v n="$top_count" -v total="$total" '
      NR <= n { printf "  %5d  %5.1f%%  %s\n", $1, $1 * 100 / total, $2 }'

heading "Busiest clients (top $top_count)"
awk '{ print $1 }' "$work" | sort | uniq -c | sort -rn \
  | awk -v n="$top_count" 'NR <= n { printf "  %5d  %s\n", $1, $2 }'

heading 'By user agent family'
awk '{
  agent = $0
  sub(/^.*" "/, "", agent)
  sub(/" [0-9]+$/, "", agent)
  split(agent, parts, "/")
  print parts[1]
}' "$work" | sort | uniq -c | sort -rn \
  | awk '{ printf "  %5d  %s\n", $1, substr($0, index($0, $2)) }'

heading 'Response time'
# awk requires a function to be defined at the top level, never inside a rule
# or an END block, so the percentile helper sits above them.
awk '{ print $NF }' "$work" | sort -n | awk -v slow="$slow_ms" '
  function at(p, n) { return values[int((n - 1) * p / 100) + 1] }
  { values[NR] = $1; total += $1; if ($1 >= slow) slowCount++ }
  END {
    if (NR == 0) exit
    printf "  count      %8d\n", NR
    printf "  mean       %8.1f ms\n", total / NR
    printf "  min        %8d ms\n", values[1]
    printf "  p50        %8d ms\n", at(50, NR)
    printf "  p90        %8d ms\n", at(90, NR)
    printf "  p95        %8d ms\n", at(95, NR)
    printf "  p99        %8d ms\n", at(99, NR)
    printf "  max        %8d ms\n", values[NR]
    printf "  over %-4d  %8d request(s), %.1f%%\n", slow, slowCount + 0,
           (slowCount + 0) * 100 / NR
  }
'

heading 'Requests by hour'
awk '{
  time = $4
  sub(/^\[/, "", time)
  split(time, parts, ":")
  hour = parts[2]
  count[hour]++
} END {
  peak = 0
  for (h in count) if (count[h] > peak) peak = count[h]
  for (h = 0; h < 24; h++) {
    key = sprintf("%02d", h)
    n = count[key] + 0
    width = (peak > 0) ? int(n * 40 / peak) : 0
    bar = ""
    for (i = 0; i < width; i++) bar = bar "#"
    if (n > 0 || width > 0) printf "  %s  %3d  %s\n", key, n, bar
  }
}' "$work"

heading 'Worth a look'
{
  awk -v slow="$slow_ms" '$NF >= slow * 10 {
    printf "  slow      %6s ms  %s %s\n", $NF, $6, $7
  }' "$work" | sed 's/"//g'

  awk '$9 >= 500 { printf "  server    %6s     %s %s\n", $9, $6, $7 }' "$work" \
    | sed 's/"//g'

  # A client asking for many different paths and getting 404 for most of them
  # is being nosy rather than lost.
  awk '$9 == 404 { count[$1]++ } END {
    for (client in count) if (count[client] >= 3)
      printf "  probing   %6d 404s  %s\n", count[client], client
  }' "$work"
} | sort -u

heading 'Summary'
awk -v slow="$slow_ms" '
  { total++
    if ($9 >= 500) errors++
    if ($9 >= 400 && $9 < 500) clientErrors++
    if ($NF >= slow) slowCount++
    bytes += $10
    clients[$1] = 1
  }
  END {
    printf "  %d request(s) from %d client(s)\n", total, length(clients)
    printf "  %.1f MB served\n", bytes / 1048576
    printf "  %d client error(s), %d server error(s)\n", clientErrors + 0, errors + 0
    printf "  %d request(s) slower than %d ms\n", slowCount + 0, slow
    if (errors > 0)
      printf "  verdict: look at the server errors first\n"
    else if (slowCount * 100 / total > 10)
      printf "  verdict: no errors, but more than a tenth of requests are slow\n"
    else
      printf "  verdict: nothing urgent\n"
  }
' "$work"

printf '\n'
