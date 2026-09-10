#!/bin/sh
# tracekeep release: tag the current commit and pin the marketplace entry to it,
# so installs fetch an immutable ref+sha instead of whatever main happens to be.
# Usage: bump "version" in .claude-plugin/plugin.json, commit everything, then
#   sh scripts/release.sh
# and push what it tells you to push.
set -e
cd "$(dirname "$0")/.."

v=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' .claude-plugin/plugin.json | head -1)
[ -n "$v" ] || { echo "ERROR: no version in .claude-plugin/plugin.json"; exit 1; }
git diff --quiet && git diff --cached --quiet || { echo "ERROR: uncommitted changes — commit the release content first"; exit 1; }

tag="tracekeep--v$v"
claude plugin tag .                      # creates $tag on HEAD, validates manifests
sha=$(git rev-parse "$tag^{commit}")

python3 - "$tag" "$sha" <<'PY'
import json, sys
p = '.claude-plugin/marketplace.json'
d = json.load(open(p))
d['plugins'][0]['source'] = {
    'source': 'github',
    'repo': 'enbiyagoral/tracekeep',
    'ref': sys.argv[1],
    'sha': sys.argv[2],
}
open(p, 'w').write(json.dumps(d, indent=2) + '\n')
PY

git commit -am "chore(release): pin marketplace to v$v ($sha)"
echo
echo "Release v$v ready. Publish with:"
echo "  git push origin main $tag"
