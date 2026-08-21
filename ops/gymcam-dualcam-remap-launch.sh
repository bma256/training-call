#!/usr/bin/env bash
#
# gymcam-dualcam-remap-launch.sh — SERIAL-KEYED dual-camera launcher (the cure)
# ---------------------------------------------------------------------------
# Retires the deviceId-swap fragility for good. The two EMEET PIXYs are identical
# to the browser ("EMEET PIXY: EMEET PIXY"), and Chromium's deviceId is a hash of
# the /dev/videoN NODE NUMBER, not of the physical camera (proven 2026-08-01 by
# lens-cover under remap). A cold boot can drop either camera onto either node, so
# a deviceId-keyed invert map cross-wires and both cameras run away.
#
# THE FIX: resolve each camera by its hardware SERIAL at launch, then bwrap-bind the
# nodes onto FIXED targets — DOOR onto /dev/video0 (+meta video1), RACK onto
# /dev/video2 (+meta video3). Chromium enumerates video-capture nodes in ascending
# node order, so it ALWAYS sees door first (index 0), rack second (index 1),
# regardless of the underlying USB enumeration. The order-keyed app
# (index-autoframe-family Guarantee-A-orderkey) reads role + inverts + the Door/Rack
# names off that index. A cold boot — voluntary or from a power cut — becomes a
# non-event: the serials never move, so the pinned order never moves.
#
# This is gymcam-dualcam-launch.sh with ONE structural change: the per-node binds
# are REMAPPED to fixed targets (src != dest) instead of bound at their real names.
# Everything else — the proven bwrap flag set, the persistent pre-permissioned
# profile, keeping Chromium's own sandbox (.deb build), the fail-loud guards — is
# unchanged. The rack is NOT hidden here (this is the dual-camera path); both are
# presented, but at fixed, serial-determined slots.
#
# REQUIRES the order-keyed app. Do NOT point this at the old hash-keyed build
# (live index.html before promotion) — that build keys on deviceId and would be
# cross-wired by the remap, the exact failure we're removing. Default URL is the
# live trainer URL; override with arg 1 to prove against the test path first:
#   ./gymcam-dualcam-remap-launch.sh "https://training-call.onrender.com/index-orderkey.html?room=gym&inv=door"
#
# Authoritative serial map (session B): DOOR = A260204000401950, RACK = A260204000406584.
# Live public/index.html and the existing launchers are UNTOUCHED by this file.
#
# 2026-08-20 NVIDIA fix: on the migrated ASRock/i7-7700K/GTX 1070 rig, the fresh
# --dev inside bwrap exposed /dev/dri but NOT the proprietary NVIDIA device nodes,
# so Chromium's GPU process could not create a GL context (ANGLE eglInitialize
# failed), GPU access was disabled, and the pose model fell to the CPU path — which
# SIGILLs on Kaby Lake (no AVX-512). Binding the five /dev/nvidia* nodes into the
# sandbox lets the NVIDIA driver init, restoring the GPU inference path. The nodes
# are bound fail-soft (skipped if absent) so this launcher still works unchanged on
# a machine without an NVIDIA GPU.
#
set -euo pipefail

# ---- Configuration --------------------------------------------------------
DOOR_SERIAL="A260204000401950"   # door/GymE-2 -> pinned to /dev/video0 (index 0 = Door)
RACK_SERIAL="A260204000406584"   # rack/GymE-1 -> pinned to /dev/video2 (index 1 = Rack)
BYID_DIR="/dev/v4l/by-id"

DEFAULT_URL="https://training-call.onrender.com/?room=gym&inv=door"
TARGET_URL="${1:-$DEFAULT_URL}"

PROFILE_DIR="$HOME/.config/gymcam-family-profile"   # primed profile: cam+mic+PTZ granted

# ---- Resolve one camera's index0 + index1 nodes by serial (fail-loud) ------
# Prints "node0 node1" (capture then metadata). Aborts on anything missing so we
# never bind a stale/absent node or fall back to "whatever is there".
resolve_cam() {
  local serial="$1" name="$2"
  local link0="${BYID_DIR}/usb-EMEET_EMEET_PIXY_${serial}-video-index0"
  local link1="${BYID_DIR}/usb-EMEET_EMEET_PIXY_${serial}-video-index1"
  if [[ ! -e "$link0" || ! -e "$link1" ]]; then
    echo "[REMAP] FATAL: ${name} serial ${serial} not fully enumerated under ${BYID_DIR}." >&2
    echo "[REMAP]        (unplugged, off, or wrong serial). Refusing to guess. Aborting." >&2
    exit 1
  fi
  local n0 n1
  n0="$(readlink -f "$link0" || true)"
  n1="$(readlink -f "$link1" || true)"
  for n in "$n0" "$n1"; do
    if [[ -z "$n" || ! -c "$n" ]]; then
      echo "[REMAP] FATAL: ${name} symlink did not resolve to a live character device (got '${n}'). Aborting." >&2
      exit 1
    fi
  done
  echo "$n0 $n1"
}

echo "[REMAP] Resolving DOOR by serial ${DOOR_SERIAL} ..."
read -r DOOR0 DOOR1 <<< "$(resolve_cam "$DOOR_SERIAL" DOOR)"
echo "[REMAP] Resolving RACK by serial ${RACK_SERIAL} ..."
read -r RACK0 RACK1 <<< "$(resolve_cam "$RACK_SERIAL" RACK)"

echo "[REMAP] DOOR ${DOOR_SERIAL}:  ${DOOR0} -> /dev/video0   ${DOOR1} -> /dev/video1"
echo "[REMAP] RACK ${RACK_SERIAL}:  ${RACK0} -> /dev/video2   ${RACK1} -> /dev/video3"
echo "[REMAP] Chromium will enumerate: index0 = /dev/video0 = DOOR , index1 = /dev/video2 = RACK"

mkdir -p "$PROFILE_DIR"

# ---- Single-instance guard (2026-08-12) -----------------------------------
# Chromium is single-instance PER PROFILE: if an instance is already running on
# this --user-data-dir, a second launch does NOT open a fresh browser -- it
# hands the URL to the running one as a new TAB and exits. Each tab auto-dials
# room=gym and holds a live signaling WebSocket, so "relaunch the icon to
# restart" silently STACKED live, room-occupying connections that only a full
# reboot cleared. (Diagnosed 2026-08-12 from Render logs: repeated REJECTED
# room-full with NO heartbeat-terminate -- the ghosts were alive, not dead.)
# Kill any Chromium bound to THIS profile first, so relaunch is a true restart.
# Scoped by the profile path, so no other browser you run is touched. The bwrap
# sandbox does not unshare the PID namespace, so a host-side pkill sees the
# child fine. pgrep/pkill never match their own process.
if pgrep -f "user-data-dir=$PROFILE_DIR" >/dev/null 2>&1; then
  echo "[REMAP] Existing Chromium on this profile detected -- terminating for a clean restart."
  pkill -TERM -f "user-data-dir=$PROFILE_DIR" 2>/dev/null || true
  for _ in 1 2 3 4 5 6; do
    pgrep -f "user-data-dir=$PROFILE_DIR" >/dev/null 2>&1 || break
    sleep 0.5
  done
  if pgrep -f "user-data-dir=$PROFILE_DIR" >/dev/null 2>&1; then
    echo "[REMAP] Still alive after TERM -- sending KILL."
    pkill -KILL -f "user-data-dir=$PROFILE_DIR" 2>/dev/null || true
    sleep 0.5
  fi
  echo "[REMAP] Previous instance cleared."
fi
# ---------------------------------------------------------------------------

# ---- NVIDIA device-node binds (2026-08-20) --------------------------------
# The fresh --dev below gives the sandbox a clean /dev with only the four remapped
# video nodes; /dev/dri is bound back for the DRM path. The proprietary NVIDIA
# driver ALSO needs its own character-device nodes (/dev/nvidia0, nvidiactl,
# nvidia-modeset, nvidia-uvm, nvidia-uvm-tools). Without them, Chromium's GPU
# process cannot create a GL context and disables GPU acceleration, forcing the
# pose model onto the CPU path (which SIGILLs on this Kaby Lake CPU). Build the
# bind args for whichever nodes exist, so the launcher stays portable to non-NVIDIA
# hosts (empty array = no extra binds = original behaviour).
NVIDIA_BINDS=()
for node in /dev/nvidia0 /dev/nvidiactl /dev/nvidia-modeset /dev/nvidia-uvm /dev/nvidia-uvm-tools; do
  if [[ -e "$node" ]]; then
    NVIDIA_BINDS+=( --dev-bind "$node" "$node" )
  fi
done
if [[ ${#NVIDIA_BINDS[@]} -gt 0 ]]; then
  echo "[REMAP] Binding ${#NVIDIA_BINDS[@]} NVIDIA arg-tokens into the sandbox for GPU access."
else
  echo "[REMAP] No /dev/nvidia* nodes found on host -- launching without NVIDIA binds."
fi
# ---------------------------------------------------------------------------

echo "[REMAP] Launching isolated Chromium at: ${TARGET_URL}"

# Proven bwrap flag set (session B), VERBATIM, with the four node binds REMAPPED
# to fixed targets. --dev installs a fresh /dev with no video nodes, so video0..3
# below are the only cameras inside, at exactly these numbers.
exec bwrap \
  --ro-bind /usr /usr \
  --ro-bind /bin /bin \
  --ro-bind /lib /lib \
  --ro-bind /lib64 /lib64 \
  --ro-bind /etc /etc \
  --ro-bind /sys /sys \
  --proc /proc \
  --dev /dev \
  --dev-bind "$DOOR0" /dev/video0 \
  --dev-bind "$DOOR1" /dev/video1 \
  --dev-bind "$RACK0" /dev/video2 \
  --dev-bind "$RACK1" /dev/video3 \
  --dev-bind /dev/dri /dev/dri \
  "${NVIDIA_BINDS[@]}" \
  --dev-bind /dev/snd /dev/snd \
  --tmpfs /tmp \
  --bind /run /run \
  --bind "$PROFILE_DIR" "$PROFILE_DIR" \
  --setenv DISPLAY "$DISPLAY" \
  --ro-bind "$HOME/.Xauthority" "$HOME/.Xauthority" \
  /usr/bin/chromium \
    --user-data-dir="$PROFILE_DIR" \
    --no-first-run \
    --no-default-browser-check \
    "$TARGET_URL"
