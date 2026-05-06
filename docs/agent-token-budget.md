# Agent token budget

> Purpose: keep agent output useful, compact, and low-noise by default.

## Default behavior

Agents should prefer compact output unless the operator explicitly asks for a full report, full logs, monster prompt, complete diff, or deep audit.

Rules:

- Conclusions first, evidence second.
- Do not paste full logs unless the exact lines are needed.
- Summarize long command output.
- Include only the lines that prove the conclusion.
- Prefer file paths, headings, and line references over copied sections.
- Avoid repeating unchanged context from previous turns.
- Do not restate policy unless it changes the current decision.
- For successful routine checks, report one compact `PASS` line.
- For failures, show command, short error, likely cause, and next safe action.

## Reading large files

- Inspect headings or indexes first.
- Search targeted terms before reading whole files.
- Quote only relevant snippets.
- Do not dump full configs, inventories, logs, generated snapshots, or runtime exports.

## Repo work

- Use compact diff summaries.
- Show changed file list.
- Show verification commands and `PASS` / `WARN` / `FAIL`.
- Avoid pasting full diffs unless requested.

## Audit format

Use this compact shape by default:

```text
Status: PASS/WARN/FAIL

Finding:
- <1-3 bullets max>

Evidence:
- <minimal command/output/path>

Next:
- <single recommended action>
```

Verbose mode is allowed when explicitly requested.
