#!/bin/sh
# Self-check for hooks/capture.sh: feeds fixture events through the hook with an
# isolated state dir and asserts EVIDENCE INTEGRITY — every value is stored
# verbatim (nothing redacted or transformed), each event is one valid JSONL line,
# and failure events keep their error. Run: sh tests/capture.sh
set -e
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export XDG_STATE_HOME="$tmp" CLAUDE_CODE_SESSION_ID=test-session
out="$tmp/tracekeep/sessions/test-session.jsonl"
run() { printf '%s' "$1" | sh "$here/../hooks/capture.sh"; }
fail() { echo "FAIL: $1"; echo "---"; cat "$out"; exit 1; }
present() { grep -q -F -- "$1" "$out" || fail "not stored verbatim: $1"; }

# A Bash event carrying dummy secret-shaped values plus engineering context, a
# failure event, and a Read event with a dummy value in the file body. Every
# value below is deliberately fake — no real credential formats, nothing for
# secret scanners to flag.
run '{"session_id":"test-session","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"export EXAMPLE_TOKEN=dummy-token-0000 && curl -H \"Authorization: Bearer dummy.bearer.value\" https://secrets.internal.example:8200/v1/sys/health"},"tool_response":{"stdout":"password: dummy-pass-1\nEXAMPLE_SECRET_KEY=dummy-secret-key-0000\nexample_key_id = DUMMY0000\npostgres://app:dummy-db-pass@db.internal.example:5432/app\nnamespace: checkout cluster: prod-eu-1 node: 10.20.4.117 region: eu-central-1","stderr":"","interrupted":false,"isImage":false},"tool_use_id":"toolu_1"}'
run '{"session_id":"test-session","hook_event_name":"PostToolUseFailure","tool_name":"Bash","tool_input":{"command":"ls /nope"},"tool_use_id":"toolu_2","error":"Exit code 1\nls: /nope: No such file or directory","is_interrupt":false}'
run '{"session_id":"test-session","hook_event_name":"PostToolUse","tool_name":"Read","tool_input":{"file_path":"/repo/values.yaml"},"tool_response":{"type":"text","file":{"filePath":"/repo/values.yaml","content":"password: dummy-file-pass\nreplicas: 3\n","numLines":3,"startLine":1,"totalLines":3}},"tool_use_id":"toolu_3"}'

[ "$(wc -l < "$out")" -eq 3 ] || fail "expected 3 lines"
while IFS= read -r line; do printf '%s' "$line" | python3 -c 'import json,sys; json.loads(sys.stdin.read())' || fail "invalid JSON line"; done < "$out"

# Every dummy secret-shaped value and every context value is present, unchanged.
# Nothing is redacted.
for v in \
  'EXAMPLE_TOKEN=dummy-token-0000' \
  'Bearer dummy.bearer.value' \
  'password: dummy-pass-1' \
  'EXAMPLE_SECRET_KEY=dummy-secret-key-0000' \
  'example_key_id = DUMMY0000' \
  'postgres://app:dummy-db-pass@db.internal.example:5432/app' \
  'password: dummy-file-pass' \
  'replicas: 3' \
  'namespace: checkout cluster: prod-eu-1 node: 10.20.4.117 region: eu-central-1' \
  '"hook_event_name":"PostToolUseFailure"' \
  'Exit code 1' \
  '"file_path":"/repo/values.yaml"'; do present "$v"; done

# Nothing tracekeep-authored should appear in the stored evidence.
grep -q 'REDACTED\|omitted by tracekeep' "$out" && fail "evidence was altered" || true

echo "OK: 3 events stored verbatim, secrets and context intact, valid JSONL"
