#!/usr/bin/env bash
# ${...} beyond substitution: defaults, assignment, errors, and the
# transformations bash adds on top.

set -uo pipefail

unset -v maybe_unset
empty=''
name='Alder Cross'

echo '--- defaults ---'
# :- uses the default when unset OR empty; - only when unset.
echo "unset  with :-  ${maybe_unset:-fallback}"
echo "empty  with :-  ${empty:-fallback}"
echo "empty  with  -  [${empty-fallback}]"
echo "set    with :-  ${name:-fallback}"

echo
echo '--- assigning a default in place ---'
# := assigns as well as substitutes, so the variable is set afterwards.
echo "value: ${configured:=a default that sticks}"
echo "configured is now: $configured"

echo
echo '--- the alternative value ---'
# :+ substitutes only when the variable is set and non-empty.
verbose=1
echo "flag: ${verbose:+--verbose}"
unset -v verbose
echo "flag: [${verbose:+--verbose}]"

echo
echo '--- failing on a missing value ---'
(
  set -e
  : "${required:?is not set, so this subshell exits}"
) 2>&1 | sed 's/^/  /' || echo '  the subshell exited, the script carried on'

echo
echo '--- length, offsets, and slices ---'
echo "length:  ${#name}"
echo "offset:  ${name:6}"
echo "slice:   ${name:0:5}"
echo "from the end: ${name: -5}"

echo
echo '--- case transformations ---'
echo "upper first: ${name^}"
echo "upper all:   ${name^^}"
echo "lower all:   ${name,,}"
echo "swap:        ${name~~}"

echo
echo '--- the @ operators ---'
path='/usr/local/bin'
echo "quoted (@Q):  ${name@Q}"
echo "escaped (@E): ${path@E}"
echo "declared (@A): ${name@A}"
echo "attributes (@a): [${name@a}]"

echo
echo '--- indirection and name matching ---'
station_name='Quill Wharf'
station_zone=3
pointer=station_name
echo "indirect: ${!pointer}"
echo "names starting with station_: ${!station_@}"

echo
echo '--- arrays ---'
lines=(Amber Cobalt Emerald)
echo "count:    ${#lines[@]}"
echo "indices:  ${!lines[@]}"
echo "slice:    ${lines[@]:1:2}"
echo "replaced: ${lines[@]/#/line-}"
echo "element length: ${#lines[1]}"

echo
echo '--- pattern removal and replacement ---'
file='datasets/csv/stations.csv'
echo "shortest prefix (#):  ${file#*/}"
echo "longest prefix (##):  ${file##*/}"
echo "shortest suffix (%):  ${file%/*}"
echo "longest suffix (%%):  ${file%%/*}"
echo "replace first:        ${file/csv/tsv}"
echo "replace all:          ${file//s/S}"
echo "anchored at start:    ${file/#datasets/data}"
echo "anchored at end:      ${file/%csv/CSV}"
