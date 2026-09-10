# tracekeep

Record Claude Code engineering sessions as **agent-handoff documents**.

One command — `/tracekeep:task` — turns the current session into

```text
<store>/<project>/<YYYY-MM-DD>/<slug>/
├── README.md        # the handoff document
└── evidence.jsonl   # every tool call that really ran in the session
```

so that another Claude session, months later, can take the work over without
re-investigating: which cluster and repo, what was run and what it returned,
which hypotheses died and why, what was decided, what was rejected, what is
still unknown.

> Current state can change. History must never disappear.

tracekeep is not a memory system, a chat exporter, a database or a dashboard.
It is a plugin that makes one workflow disappear: remembering to write things
down properly.

## Install

```bash
claude plugin marketplace add enbiyagoral/tracekeep
claude plugin install tracekeep@tracekeep
```

That is all. The evidence hooks activate with the plugin. No settings edits,
no shell profile changes, no dependencies — POSIX `sh` only.

## Use

Work with Claude Code as usual. When the work is worth handing over:

```text
/tracekeep:task
```

Claude derives a slug from the session topic, or takes yours:

```text
/tracekeep:task postgres-failover-drill
```

It prints the two file paths. It does not commit or push.

Continue the same work another day and run `/tracekeep:task` again: the same
directory is updated. The date directory is the day the work **started** and is
never renamed; status never moves records around (no `_DONE-` prefixes).

## How it works

```text
Claude Code ── tool call ──▶ PostToolUse / PostToolUseFailure hook
                                   │  hooks/capture.sh (append verbatim)
                                   ▼
           ${XDG_STATE_HOME:-~/.local/state}/tracekeep/sessions/<session_id>.jsonl
                                   │
 /tracekeep:task ──▶ skills/task/context.sh (session id, UTC date, project, store,
                     existing records) ──▶ Claude writes README.md, merges the
                     session's events into evidence.jsonl
```

Only the user decides what becomes a record. Hooks collect; nothing is written
to the store until `/tracekeep:task` is typed. Session evidence files stay in
the state directory until then.

## Where records go

| Situation | project | store |
|---|---|---|
| A `.tracekeep` file exists in a directory above cwd (a *workspace*) | first directory under the workspace that contains cwd | `store=` in `.tracekeep`, relative to the workspace (default `tracekeep/`) |
| No `.tracekeep` above cwd | basename of the git repository containing cwd | `~/tracekeep` |
| Neither | Claude asks, unless the session already made it clear | `~/tracekeep` |

Example — a workspace of products, each holding several repositories:

```text
acme/
├── .tracekeep           # contains:  store=task
├── task/                # ← the store
├── payments/api-gateway/
├── identity/keycloak-config/
└── logistics/...
```

Running `/tracekeep:task` inside `acme/payments/api-gateway` records to
`acme/task/payments/<date>/<slug>/` — the project is `payments`, not
`api-gateway`.

The detection is a suggestion. If the user says during the session that the
work belongs elsewhere, or an existing record for the same work already lives
under another project (moved by hand, for example), Claude uses that instead.

## Evidence

`evidence.jsonl` holds the raw hook events, one JSON object per line, **exactly as
Claude Code delivered them** — `tool_name`, `tool_input`, `tool_response` (or
`error` for failures), `tool_use_id`, `session_id`, `cwd`, `duration_ms`. Read
file bodies and command outputs are kept in full. The record's whole value is
answering *"what exactly did Claude look at that day?"* months later, so nothing
that Claude actually saw is thrown away, altered or masked. The only normalization
is that newlines between JSON tokens are removed so each event is one line; no
value is ever changed.

> ⚠️ **Evidence is unredacted. Review before committing or sharing.**
>
> Because tracekeep never sanitizes what it captures, `evidence.jsonl` **may
> contain credentials, secret keys, API and Vault tokens, passwords, internal IP
> addresses and hostnames, file paths, and source code** — whatever appeared in a
> tool's input or output during the session. This is deliberate: a redacted record
> lies about what happened, and a text filter gives false confidence anyway.
>
> The consequence is yours to manage. Treat the store like shell history:
>
> - **Read the evidence** (and the generated README) before you `git add`, push,
>   or send it to anyone.
> - Keep the store outside any repo you publish, or add its path to `.gitignore`,
>   unless you have reviewed every line.
> - Rotate any credential that reaches a record you shared.

The README that `/tracekeep:task` writes is a curated, human-facing document and
should **not** reproduce secrets even when they appear in the evidence. Its
`Commands` section separates **executed / verified** commands (present in
`evidence.jsonl`) from **runbook** commands proposed for later; a proposed command
is never presented as evidence.

## Development

```bash
sh tests/capture.sh                 # hook self-check: verbatim capture, secrets intact, valid JSONL
claude plugin validate .            # manifests, hooks, skill frontmatter
claude --plugin-dir . # load the working copy without installing
```

## Deliberately not in this version

No CLI, no `/resume` `/search` `/list` `/status`, no MCP server, no database,
no vector or semantic search, no web UI, no daemon, no automatic record on
`SessionEnd`, no Obsidian integration, no providers other than Claude Code.
`/tracekeep:task` has to be excellent first.

## License

MIT

## Release (maintainers)

Versioning is [SemVer](https://semver.org) with a single source of truth:
`version` in `.claude-plugin/plugin.json`. Installs are pinned:
the marketplace entry points at an immutable git tag + commit SHA, so users get
exactly the released commit, never whatever `main` currently holds.

```bash
# 1. bump "version" in .claude-plugin/plugin.json  (fix→patch, feat→minor, breaking→major)
# 2. commit the release content (Conventional Commits)
sh scripts/release.sh   # tags tracekeep--v<version>, pins marketplace.json to its SHA, commits the pin
git push origin main tracekeep--v<version>
```
