#!/bin/sh
# tracekeep hook for PostToolUse / PostToolUseFailure.
# Reads one hook event (JSON) on stdin and appends it VERBATIM, as one line, to
# this session's evidence file. No redaction, no transformation of tool inputs or
# responses: evidence integrity over sanitization. The evidence therefore MAY
# CONTAIN credentials, secrets, tokens, internal IPs, hostnames, paths and source
# code exactly as Claude saw them. Review it before you commit or share it — see
# the Evidence section of README.md. POSIX sh only. Never blocks Claude (exit 0).
#
# Evidence: ${XDG_STATE_HOME:-~/.local/state}/tracekeep/sessions/<session_id>.jsonl
# /tracekeep:task moves it into <store>/<project>/<date>/<slug>/evidence.jsonl.

dir="${XDG_STATE_HOME:-$HOME/.local/state}/tracekeep/sessions"
event=$(cat)
sid=${CLAUDE_CODE_SESSION_ID:-$(printf '%s' "$event" | sed -n 's/.*"session_id":"\([^"]*\)".*/\1/p')}
[ -n "$sid" ] && [ -n "$event" ] || exit 0
mkdir -p "$dir" || exit 0

# The only normalization: collapse newlines so each event is exactly one JSONL
# line. JSON encodes newlines inside string values as \n, so a raw newline can
# only sit between tokens — removing it keeps the JSON identical and alters no
# value. Nothing else is touched.
printf '%s\n' "$(printf '%s' "$event" | tr -d '\n')" >> "$dir/$sid.jsonl"
exit 0
