#!/usr/bin/env bash
# =============================================================================
# fetch-vosk.sh — restore the Vosk voice-recognition assets for KINESIS.
#
# WHY THIS EXISTS
#   The KINESIS voice-arming feature (offline "start set" / "stop set") depends
#   on two files living under public/vendor/vosk/ :
#       - vosk.js                              (the WASM library; committed to git)
#       - vosk-model-small-en-us-0.15.tar.gz   (~40MB model; NOT in git)
#   The model is deliberately kept OUT of git (see .gitignore) to avoid bloating
#   history and Render deploys. This script is the authoritative way to restore
#   it on a fresh clone or a recovered machine. It is also carried in the
#   disaster-recovery bundle.
#
#   Run from the repo root:  bash ops/fetch-vosk.sh
#
# GUARANTEES
#   - Fail-loud: any download error or hash mismatch aborts (set -euo pipefail).
#   - Verifies BOTH files against pinned sha256 — a corrupted or substituted
#     download is rejected, never silently used.
#   - Idempotent: if a file already exists and its hash matches, it is left as-is.
# =============================================================================
set -euo pipefail

# --- pinned identities (recorded 2026-08-22, proven in the gym) --------------
LIB_URL="https://cdn.jsdelivr.net/npm/vosk-browser@0.0.8/dist/vosk.js"
LIB_SHA="29504515526e974f4cb053cf08811c4de5fb2a74007c0a5a957db50eaa8d5d0c"
LIB_NAME="vosk.js"

MODEL_URL="https://ccoreilly.github.io/vosk-browser/models/vosk-model-small-en-us-0.15.tar.gz"
MODEL_SHA="f0b24bb92a48ca575b6a96500d6b543f0f079c573dfe85bbe16001fc0404e1d8"
MODEL_NAME="vosk-model-small-en-us-0.15.tar.gz"

# --- resolve destination relative to THIS script (repo-root independent) -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${SCRIPT_DIR}/../public/vendor/vosk"
mkdir -p "$DEST"

verify() {   # verify <file> <expected_sha>  -> 0 if matches
  local f="$1" want="$2" got
  [ -f "$f" ] || return 1
  got="$(sha256sum "$f" | awk '{print $1}')"
  [ "$got" = "$want" ]
}

fetch_one() {   # fetch_one <url> <sha> <name>
  local url="$1" sha="$2" name="$3" path="${DEST}/$3"
  if verify "$path" "$sha"; then
    echo "[fetch-vosk] $name already present and verified — skipping."
    return 0
  fi
  echo "[fetch-vosk] downloading $name ..."
  curl -fSL -o "$path" "$url"
  if ! verify "$path" "$sha"; then
    echo "[fetch-vosk] FATAL: $name sha256 mismatch after download." >&2
    echo "[fetch-vosk]   expected: $sha" >&2
    echo "[fetch-vosk]   got:      $(sha256sum "$path" | awk '{print $1}')" >&2
    echo "[fetch-vosk]   The download was corrupted or the source changed. Refusing to use it." >&2
    rm -f "$path"
    exit 1
  fi
  echo "[fetch-vosk] $name OK ($(wc -c < "$path") bytes, sha256 verified)."
}

echo "[fetch-vosk] destination: $DEST"
fetch_one "$LIB_URL"   "$LIB_SHA"   "$LIB_NAME"
fetch_one "$MODEL_URL" "$MODEL_SHA" "$MODEL_NAME"

# --- model sanity: must be a real gzip, not an HTML error page ---------------
if ! gzip -t "${DEST}/${MODEL_NAME}" 2>/dev/null; then
  echo "[fetch-vosk] FATAL: ${MODEL_NAME} failed gzip integrity test." >&2
  exit 1
fi

echo "[fetch-vosk] all Vosk assets present and verified. KINESIS voice ready."
