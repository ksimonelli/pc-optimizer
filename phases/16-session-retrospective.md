# Phase 16 - Session Retrospective & Self-Improvement

Run this at the end of every optimization session, BEFORE the final reboot (Claude does not survive it).
This is how the framework gets smarter.

Privacy rule for everything written here: describe the machine and the decisions, not the person. No names,
e-mail addresses, Windows usernames in paths (write `%USERPROFILE%`), or hostnames that identify someone.
The retrospective may be shared; `profile.json`, `logs/`, `backup/` and `run/` are git-ignored because they
contain those details.

---

## Step 1: Generate the Retrospective

Create `session-retrospective-YYYY-MM-DD.md` with this structure:

```markdown
# Session Retrospective - [DATE]

## Machine
- OEM: [manufacturer]
- Model: [model]
- CPU: [name]
- GPU: [name]
- RAM: [total]
- Storage: [drives and sizes]
- OS: [edition and build]

## Results
| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| RAM at idle | X GB | Y GB | -Z GB |
| C: drive free | X GB | Y GB | +Z GB |
| Startup entries | N | M | -K |
| Services set to Manual | 0 | N | +N |
| Apps removed | 0 | N | +N |

## Phases Completed
- [x] Phase 00: Detect - [1 line summary]
- [x] Phase 01: Inventory - [1 line summary]
...
- [ ] Phase 12: Gaming - Skipped (not a gaming machine)
...

## What Went Well
- [specific things that worked efficiently]
- [techniques that saved time]
- [scripts that ran without issues]

## What Wasted Time
- [specific things that took longer than expected]
- [WHY they wasted time - root cause]
- [how to prevent it next time]

## What Failed
- [commands that errored]
- [services that re-enabled after reboot]
- [unexpected behavior]
- [workarounds used]

## New Gotchas Discovered
- [anything not already in gotchas.md that should be added]
- [include the specific error, the root cause, and the fix]

## Improvements for Next Run (Ranked)
1. [highest impact improvement]
2. [second highest]
3. ...

## Tokens/Time Analysis
- Total phases run: N
- Restarts required: N
- Phases that took longest: [list]
- Commands re-run due to errors: N
```

---

## Step 2: Update the Knowledge Base

### Update `gotchas.md`
Add any new gotchas discovered during this session. Include:
- The problem (what happened)
- The fix (exact commands)
- How to detect it early

### Update `lessons-learned.md`
Add any new lessons. Include:
- The lesson
- Source session (date, machine)
- Why it matters

### Update phase docs
If a phase doc was missing information or had incorrect commands, fix it.

### Update scripts
If a script needed modifications to work on this machine, update it.

---

## Step 3: Learning Ingestion (When Analyzing Another Session)

When asked to ingest another session's data:

1. **Read** the provided files (checkpoint, retrospective, optimization docs, action plans).

2. **Extract** each of these categories:
   - **New gotchas:** Problems encountered that aren't in `gotchas.md`
   - **New lessons:** Insights that aren't in `lessons-learned.md`
   - **Improved techniques:** Better ways to do things already in the phase docs
   - **New commands/scripts:** Commands that worked well and should be added
   - **Failed approaches:** Things that were tried and didn't work (anti-patterns)

3. **Compare** with existing knowledge:
   - Does this contradict something we already know? (update the existing entry)
   - Does this duplicate something? (skip it)
   - Does this extend something? (merge it into the existing entry)
   - Is this genuinely new? (add it)

4. **Merge** into the appropriate files:
   - `gotchas.md` for failure modes
   - `lessons-learned.md` for insights and best practices
   - Phase docs for technical details
   - Scripts for new automation

5. **Record** the ingestion in `lessons-learned.md` session history table.

---

## Step 4: Checkpoint Cleanup

The retrospective is written BEFORE the reboot, so `checkpoint.md` stays until the post-reboot report has been
read: set it to "waiting for reboot; post-reboot verification is automatic", then delete it once
`logs/VERIFY-REPORT.txt` shows ALL CHECKS PASSED (or its issues have been dealt with). The retrospective file
and `logs/` are the permanent record.

---

## Self-Improvement Metrics

Track these across sessions to measure framework improvement:

| Metric | Goal |
|---|---|
| Phases requiring manual intervention | Decrease over time |
| Commands that error on first run | Decrease over time |
| Time spent investigating unknown apps | Decrease (known-bloat DB growing) |
| Services that re-enable after reboot | Should be zero (gotchas capture these) |
| New gotchas per session | Decrease over time (framework is maturing) |
| Improvements suggested per session | Should converge toward zero |
