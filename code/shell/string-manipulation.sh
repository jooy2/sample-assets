#!/usr/bin/env bash
# String handling without leaving the shell: length, case, search, replace.

set -euo pipefail

line='Alder Cross,Amber,2,true'
path='/Users/sample/datasets/csv/stations.csv'

echo "length: ${#line}"
echo "upper:  ${line^^}"
echo "lower:  ${line,,}"
echo "first character upper: ${line^}"

# Substrings by offset and length; a negative offset counts from the end.
echo "substring: ${line:0:11}"
echo "from 12:   ${line:12}"
echo "last four: ${line: -4}"

# Removing a prefix or suffix, shortest (#, %) and longest (##, %%) match.
echo "basename:  ${path##*/}"
echo "dirname:   ${path%/*}"
echo "extension: ${path##*.}"
echo "stem:      ${path##*/}" | sed 's/\.[^.]*$//'
echo "no prefix: ${line#*,}"
echo "no suffix: ${line%,*}"
echo "first field: ${line%%,*}"
echo "last field:  ${line##*,}"

# Replacing: first match, all matches, anchored at the start or the end.
echo "one:    ${line/,/;}"
echo "all:    ${line//,/;}"
echo "start:  ${line/#Alder/ALDER}"
echo "end:    ${line/%true/false}"
echo "delete: ${line//,/}"

# A pattern in the replacement form deletes every character it matches.
echo "without lowercase: ${line//[a-z]/}"

# Padding and alignment belong to printf.
printf 'padded: |%-20s|%20s|%08.3f|\n' left right 3.14159
printf 'repeat: %s\n' "$(printf '%.0s-' {1..24})"

# Testing and matching.
[[ $line == *Amber* ]] && echo "contains Amber"
[[ $line == Alder* ]] && echo "starts with Alder"
[[ $line == *true ]] && echo "ends with true"

if [[ $line =~ ^([^,]+),([^,]+),([0-9]+) ]]; then
  echo "captured: ${BASH_REMATCH[1]} / ${BASH_REMATCH[2]} / zone ${BASH_REMATCH[3]}"
fi

# Splitting into an array, and joining one back together.
IFS=, read -ra fields <<< "$line"
echo "fields: ${#fields[@]}"
printf 'joined: %s\n' "$(IFS=' | '; echo "${fields[*]}")"

# Trimming whitespace with parameter expansion alone.
padded='   spaced out   '
trimmed=${padded#"${padded%%[![:space:]]*}"}
trimmed=${trimmed%"${trimmed##*[![:space:]]}"}
echo "trimmed: [$trimmed]"

# A slug, without leaving the shell.
slug=${line,,}
slug=${slug//[^a-z0-9]/-}
while [[ $slug == *--* ]]; do slug=${slug//--/-}; done
echo "slug: ${slug#-}"

# Indirect expansion and the length of a variable's name.
station_name='Alder Cross'
variable=station_name
echo "indirect: ${!variable}"
