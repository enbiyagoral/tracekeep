#!/bin/sh
# tracekeep: facts for the /tracekeep:task skill. Prints, never decides.
# Usage: context.sh [slug]
state="${XDG_STATE_HOME:-$HOME/.local/state}/tracekeep/sessions"
evidence="$state/${CLAUDE_CODE_SESSION_ID:-unknown}.jsonl"

# Workspace = nearest ancestor of cwd holding a .tracekeep file; its direct
# subdirectories are the projects. Without one: project = git repository name.
d=$PWD; ws=
while [ -n "$d" ] && [ "$d" != / ]; do
  if [ -f "$d/.tracekeep" ]; then ws=$d; break; fi
  d=$(dirname "$d")
done

project=; how=
if [ -n "$ws" ]; then
  store=$(sed -n 's/^store=//p' "$ws/.tracekeep" | tail -1)
  case $store in '') store=$ws/tracekeep ;; /*) ;; *) store=$ws/$store ;; esac
  rel=${PWD#"$ws"}; rel=${rel#/}; project=${rel%%/*}
  how="first directory under workspace $ws"
  case $PWD/ in "$store"/*) project=; how="cwd is inside the store itself" ;; esac
else
  store=$HOME/tracekeep
  if top=$(git rev-parse --show-toplevel 2>/dev/null); then
    project=$(basename "$top"); how="git repository name ($top)"
  else
    how="no .tracekeep workspace above cwd and not inside a git repository"
  fi
fi

events=0; [ -f "$evidence" ] && events=$(wc -l < "$evidence" | tr -d ' ')
records=$({
  [ -n "$project" ] && ls -d "$store/$project"/*/*/
  find "$store" -mindepth 4 -maxdepth 4 -name README.md -mtime -30 | sed 's|/README.md$||'
  [ -n "$1" ] && ls -d "$store"/*/*/"$1"/
} 2>/dev/null | sed "s|^$store/||; s|/\$||" | sort -u | sed 's/^/  /')

echo "session_id: ${CLAUDE_CODE_SESSION_ID:-UNKNOWN}"
echo "evidence_file: $evidence ($events events captured)"
echo "utc_date: $(date -u +%F)"
echo "utc_now: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "cwd: $PWD"
echo "workspace: ${ws:-none}"
echo "store: $store"
echo "project: ${project:-UNKNOWN} ($how)"
echo "slug_argument: ${1:-none}"
echo "existing_records (this project; anything updated in the last 30 days; anything matching the slug):"
echo "${records:-  (none)}"
