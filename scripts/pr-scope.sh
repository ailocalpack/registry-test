#!/usr/bin/env bash
# Classifies a pull request by the files it changes.
#
#   scripts/pr-scope.sh <checkout root> < changed-paths   (one path per line, as in the PR head)
#
# Prints GITHUB_OUTPUT lines:
#   kind=pack         every path is inside one games/<game>/<language>/<pack-id>/ folder that still has a
#                     manifest.json: a contributor PR that may be auto-merged
#   kind=maintenance  anything else (other files, several packs, a pack folder removed); maintainers only
#   kind=empty        no changed paths
#   pack=<folder>     for kind=pack
#   packs=<folders>   space-separated pack folders touched that still exist (to validate), any kind
#   reason=<text>     why a PR is not a pack PR
set -euo pipefail

root="${1:?usage: pr-scope.sh <checkout root> < paths}"
folders=""
other=""
count=0

while IFS= read -r path || [[ -n "$path" ]]; do
  [[ -z "$path" ]] && continue
  count=$((count + 1))
  if [[ "$path" =~ ^(games/[^/]+/[^/]+/[^/]+)/.+ ]]; then
    folders+="${BASH_REMATCH[1]}"$'\n'
  elif [[ -z "$other" ]]; then
    other="$path"
  fi
done

folders="$(printf '%s' "$folders" | sort -u)"
touched=0
existing=""
while IFS= read -r folder; do
  [[ -z "$folder" ]] && continue
  touched=$((touched + 1))
  [[ -f "$root/$folder/manifest.json" ]] && existing+="$folder "
done <<< "$folders"
echo "packs=${existing% }"

if (( count == 0 )); then
  echo "kind=empty"
  echo "reason=the pull request changes no files"
elif [[ -n "$other" ]]; then
  echo "kind=maintenance"
  echo "reason=it changes $other, outside games/<game>/<language>/<pack-id>/"
elif (( touched > 1 )); then
  echo "kind=maintenance"
  echo "reason=it changes $touched pack folders; a pack pull request changes exactly one"
elif [[ -f "$root/$folders/manifest.json" ]]; then
  echo "kind=pack"
  echo "pack=$folders"
else
  echo "kind=maintenance"
  echo "reason=it removes the pack $folders (or its manifest.json)"
fi
