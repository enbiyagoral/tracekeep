---
name: task
description: Save this session's engineering work as an agent-handoff record (README.md + evidence.jsonl under <store>/<project>/<UTC-date>/<slug>/). Only runs when the user types /tracekeep:task.
argument-hint: "[slug]"
disable-model-invocation: true
---

# Save this session as a handoff record

Write down the work done in this session so that another Claude session — months
from now, with no shared context — can take it over without re-investigating.
**Current state can change. History must never disappear.**

## Context (collected now — do not guess any of it)

!`sh "${CLAUDE_PLUGIN_ROOT}/skills/task/context.sh" "$ARGUMENTS"`

## Steps

1. **Project.** Use `project` above. Override it only when the session itself
   settles it differently: the user said the work belongs to another project, or
   an existing record for this same work already lives under another project.
   If it is `UNKNOWN` and nothing in the session settles it, ask the user for the
   project name. Never invent one.
2. **Record directory.** If one of `existing_records` is this same piece of work
   (same slug, or the same topic continued on a later day), reuse that directory —
   never create a second dated directory for it, never rename or move the old one.
   Otherwise create `<store>/<project>/<utc_date>/<slug>/`:
   - slug = `slug_argument` if given, else a short kebab-case slug from the topic
     (`ingress-timeout-debug`, `postgres-failover-drill`, `cache-stampede-fix`);
   - date = `utc_date` above, never a guessed one. Status never changes the
     directory name (no `_DONE-` prefixes).
3. **Evidence.** Append this session's captured events to the record, skipping
   lines already there (safe to run more than once per session):
   ```bash
   mkdir -p <record> && touch <record>/evidence.jsonl && awk '!seen[\$0]++' <record>/evidence.jsonl <evidence_file> > <record>/evidence.jsonl.tmp && mv <record>/evidence.jsonl.tmp <record>/evidence.jsonl
   ```
   If `evidence_file` is missing or has 0 events, write that fact into the
   README's Status table (`evidence: none captured — hooks were not active`) and
   carry on. Do not fabricate evidence.
4. **README.md.** Write it (new record) or update it (existing record) per the
   rules below. Read the existing README first when updating.
5. Report both file paths to the user. Remind them that `evidence.jsonl` is
   captured verbatim and **unredacted** — it may contain secrets, tokens,
   internal IPs, paths and source code — so they should review it before
   committing or sharing. Do not commit, push or open a PR yourself.

## What README.md is

The README is the handoff document, not a summary. Length is not a concern;
missing context is. 1000 lines is fine when the work needs it. Write in the
language the user used during the session; keep the section headers below as
they are so records stay greppable.

**Facts vs. inference.** A claim is a fact only if it is backed by a command
that actually ran in this session (it is in evidence.jsonl) or a file that was
actually read. Everything else is marked `NOT MEASURED / INFERRED` together with
how to verify it. If you are not sure whether something is true, re-run the
read-only command instead of writing from memory — anything you run now is
captured as evidence too. Do not start new investigation while recording: the
record describes what this session did, not a new session. Never present a
command you are proposing for the future as something that ran.

## Sections, in this order

### Status
Table: started · last updated · severity · status · recurrence risk / blocker ·
what remains · evidence (event count). Then one line: the single most important
result so far.

### Current State
"As of <utc_now>": what is true right now, in a few lines. On an update this
section is rewritten — the facts it replaces are not deleted, they stay in
History and in the sections below with a note on when and why they changed.

### Environment
Everything the next agent would otherwise have to search for: kubeconfig context,
cluster name and version, namespaces, workload names, cloud account / project /
region IDs, repositories **with repo name and branch**, file paths, PR and
branch links, tool versions.

### Request / Alert
The triggering message verbatim — not paraphrased. Later changes of direction
by the user, also verbatim where they mattered.

### Summary
3–5 sentences: what happened, where it stands.

### Root cause chain
Step by step, timestamped. For non-incident work (bootstrap, PoC, migration)
this is the chain of what was done, what blocked, how it was unblocked.

### Measurements
Raw numbers in tables, each with its measurement time (UTC) and the command
that produced it. Undated numbers mislead.

### Refuted hypotheses
Every explanation that was considered and dropped:
hypothesis → verdict → why → the evidence (command / output). If your own
earlier suggestion turned out wrong, say so explicitly. Never delete an entry;
the next agent must not walk the same path again.

### Unknowns
Each: what is not known · why · how to verify it.

### Impact
What changed or was lost, who or what was affected, production or not.

### Open items
Numbered. Each with repo-qualified `file:line` references, rationale, status.
Items that were finished on an update get struck through, not removed.

### Won't do
Solutions considered and rejected: what was proposed · why rejected · if the
decision later changed, what happened. Never delete.

### Pitfalls
Optional. Things that cost time and would again: tool quirks, API surprises,
shell gotchas.

### Commands
Two subsections, clearly separated:
- **Executed / verified** — commands that actually ran in this session
  (present in evidence.jsonl), with real values, copy-paste ready, and the
  relevant result next to them.
- **Runbook / next steps** — commands proposed for the future. Never shown as
  evidence.

### History
Append-only. One entry per `/tracekeep:task` run:
`<utc_now> — what this update added, changed or corrected`.
When a statement elsewhere in the file turns out wrong, correct it in place by
appending `→ superseded <date>: <new fact, why>` after the old text instead of
editing the old text away. The next agent must be able to answer "why was it
believed on that day?".

## Writing rules

- Every number carries its measurement date.
- Mark information that goes stale and give the command that refreshes it.
- No placeholders in commands: `10.20.4.117`, not `<node>`.
- File paths complete, line-numbered and repo-qualified:
  `payments-gitops: apps/api-gateway/values/prod.yaml:42`.
- Assume no shared context. The next agent knows only this directory.
- Do not put explanations as comments into generated configs or manifests; they
  belong in this README.
- Secrets never go into the README even if they appeared on screen.

## Updating an existing record

Rewrite Status and Current State; append to History; add to Open items,
Refuted hypotheses, Won't do and Pitfalls; extend Commands; strike through what
is done. Do not delete, do not rename, do not move the directory — the date
directory is the day the work started and stays that way.
