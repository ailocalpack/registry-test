#!/usr/bin/env bash
# For a binary patch pack: fetches its archive from the pull request author's fork and checks it against the
# manifest. The app (task 60) uploads the archive as an asset of the fork's "patches" release and writes the
# registry's own URL into the manifest; this script checks that URL, downloads the fork's asset (size-limited),
# and compares size and SHA-256. auto-merge.yml then copies the checked file to this repository's "patches"
# release before merging, so the index never points at a missing asset. A recipe pack (no "patch") passes.
#
#   scripts/check-patch.sh <pack folder> <registry owner/repo> <head owner/repo> <download dir>
#
# Prints GITHUB_OUTPUT lines: archive=<downloaded file> and name=<asset name> (nothing for a recipe pack).
set -euo pipefail

pack="${1:?usage: check-patch.sh <pack folder> <registry> <head repo> <dir>}"
registry="${2:?registry}"
head_repo="${3:?head repo}"
dir="${4:?download dir}"
manifest="$pack/manifest.json"

if [[ "$(jq -r 'has("patch")' "$manifest")" != "true" ]]; then
  echo "$manifest: no binary patch" >&2
  exit 0
fi

fail() {
  echo "::error file=$manifest,title=patch::$1"
  exit 1
}

url="$(jq -r '.patch.url // empty' "$manifest")"
sha="$(jq -r '.patch.sha256 // empty' "$manifest")"
size="$(jq -r '.patch.size // empty' "$manifest")"
[[ "$sha" =~ ^[0-9a-f]{64}$ && "$size" =~ ^[0-9]+$ ]] || fail "patch.sha256 and patch.size are required"
(( size <= 2147483648 )) || fail "the patch archive is over 2 GiB (GitHub's limit for a release asset)"

# games/<game folder>/<language>/<id> → <game folder>-<language>-<id>-<revision>.zip
game="$(basename "$(dirname "$(dirname "$pack")")")"
language="$(basename "$(dirname "$pack")")"
id="$(basename "$pack")"
revision="$(jq -r '.revision' "$manifest")"
name="$game-$language-$id-$revision.zip"
expected="https://github.com/$registry/releases/download/patches/$name"
[[ "$url" == "$expected" ]] || fail "patch.url must be $expected (the registry's own release asset), found $url"

mkdir -p "$dir"
file="$dir/$name"
source="https://github.com/$head_repo/releases/download/patches/$name"
if ! curl -fsSL --retry 3 --max-filesize "$size" -o "$file" "$source"; then
  fail "can't download $source: publish the pack from the app (it uploads the archive to your fork's \"patches\" release)"
fi
actual_size="$(wc -c < "$file" | tr -d ' ')"
actual_sha="$(sha256sum "$file" | cut -d' ' -f1)"
[[ "$actual_size" == "$size" ]] || fail "$source is $actual_size bytes, the manifest says $size"
[[ "$actual_sha" == "$sha" ]] || fail "$source has SHA-256 $actual_sha, the manifest says $sha"

echo "$manifest: patch archive $name checked ($size bytes)" >&2
echo "archive=$file"
echo "name=$name"
