# CLAUDE.md — training-call (gym box)

This repo runs a WebRTC remote-training call system used for **live sessions with a
remote trainer (Maria)**. A bug here can take down a real session on the other side of
the world. Optimize for **not breaking the live call**, then for progress. When in
doubt, do less and ask.

Repo root is `~/training-call/webrtc-app` (the git root). The desktop launcher icon
hardcodes this path.

---

## The three load-bearing files
Treat these as high-consequence. Every edit prompts, and every edit triggers the
recovery-bundle rule below.
- `public/index.html` — the live app (also contains the dormant KINESIS module)
- `ops/gymcam-dualcam-remap-launch.sh` — the only valid launcher (serial-keyed, bwrap NVIDIA binds)
- `server.js` — the Render signaling server

The repo-root pair `TrainingCall.desktop` + `launch-training-call.sh` is a **footgun**;
never use it. The correct launcher lives in `ops/`.

---

## Working rhythm
- **One step at a time.** Propose exactly one action, then wait. Do not stack steps.
- **Discuss → options → decide → execute.** The permission approval prompt IS the
  decision-to-execute step. Don't route around it.
- Summaries and next steps in replies; no long reasoning walkthroughs unless asked.

## Prove-then-promote (non-negotiable)
- Build/prove under a **unique test filename** or a local test server, verify, then
  promote **byte-identical**. Never edit a load-bearing file in place and push without
  the prove step.
- `sha256sum` at source AND destination before deploying. `cmp` to confirm byte-identity.
- `node --check public/index.html` before any handoff of index.html.
- The **only valid proof environment is the gym box** at correct camera distance.
  Desk-range pose readings are garbage and must not be used to tune thresholds. For
  KINESIS, serving the file via `python3 -m http.server` and opening it through the
  **real launcher** at `http://localhost:PORT/...` is valid (the launcher fixes camera
  identity by serial before the page loads).

## Git discipline
- **`git add` by explicit filename only. Never `git add -A` or `git add .`.**
  (Both bulk forms are also denied in settings; `.gitignore` is the real backstop.)
- Commit messages: short, factual, present-tense.
- `git push` is gated behind approval on purpose — the push IS the promote decision, and
  Render auto-deploys from `origin/main`. Confirm intent before pushing.
- `&&` chains stop on the first non-zero exit. A re-run `git commit` with nothing new
  exits non-zero and will silently skip a chained `git push`. Check
  `git log origin/main..HEAD` for a waiting commit and push it on its own.
- `git check-ignore -v` and `grep -c` exit non-zero on "no match / zero" — that is
  expected, not an error. Read the output, not the exit code. Run expected-non-zero
  commands standalone, never in an `&&` chain.

## Never commit (enforced by .gitignore + deny rules; also do not attempt)
- The 40MB Vosk model: `public/vendor/vosk/*.tar.gz`
- Any backup: `*.bak`, `*.bak-*`
- The broken launcher variant: `ops/gymcam-dualcam-remap-launch-nvidia.sh`
- `.claude/settings.json` (box-local permission posture)
- Never read or print secrets: `.env*`, `**/*.pem`, `~/.ssh/**`. Credentials live in
  Proton Pass, not in files or chat.

## Recovery-bundle trigger (standing rule — flag it EVERY time)
Any change to **`public/index.html`, `ops/`, or `server.js`** means the recovery bundle
is now stale and must be **rebuilt + redistributed to all 5 surfaces** (MEDICAL USB fob,
iCloud, Claude project box, Proton email, Gmail) with a re-sent dated email
(`training-call recovery bundle YYYY-MM-DD`). A stale bundle is the key failure mode.
The bundle must carry the two Vosk files (`vosk.js` + the model) + `ops/fetch-vosk.sh`,
because the model is not in git. Build the bundle **on the gym box** (authoritative
artifact rule); a rebuild elsewhere gets a different sha and breaks verification. When a
load-bearing file changes, say so and remind that the bundle is now due.

## System / irreversible actions
- **Simulate before execute**: `apt install -s`, and read the package set before the
  real run. Never `curl | bash` unverified — use signed repositories.
- `rm` bypasses Trash; there is no undo for terminal deletes. Prefer moving to a scratch
  dir over deleting; if deleting, name the exact path.

## KINESIS invariants
- KINESIS is a **dormant, flag-gated (`?kinesis=1`), read-only** module inside
  `index.html`. A plain URL (Maria's sessions) must show **zero** KINESIS trace.
- It writes only to its own panel/log — never to WebRTC, PTZ, or framing code.
- The **skeleton adapter** (named joints only) is the only code touching raw MediaPipe
  landmark indices. All exercise logic uses named joints. Keep it anatomically honest.
- L/R mirror is fixed in **EMEET firmware**, not in the adapter.

## Camera identity
- **Serial-keyed resolution at launch is the only correct approach.** `deviceId` is
  cold-boot-unstable. Never re-introduce a `deviceId → role` map.
- Physical lens-cover test is the authoritative identity proof.

---

## What stays manual (Code does not do these)
- **The physical pushup proof** — validating the rep counter needs Alex in front of the
  lens at correct distance.
- **Token / credential rotation** — needs Proton Pass; done off-camera by Alex.
- **The promote decision** — which is why `git push` is gated.

## Current open items (context, not a to-do for Code to run unprompted)
- Recovery bundle rebuild is **overdue** (KINESIS V5 promote at commit `8464785`).
- Launcher bug: prints `FATAL … Aborting` on a missing serial but keeps going; needs a
  hard `exit 1` after the FATAL line. A launcher edit re-triggers the bundle rebuild.
- Leaked GitHub PAT from a screenshot needs rotation; a lost old token needs deleting.
- No git credential helper configured yet (keyring-backed `libsecret` preferred).
