#!/bin/bash
# One-step launcher for Training Call.
#
# Double-click this (or the desktop icon pointing to it) and it opens the
# call page directly in a clean window — no address bar, no tabs — already
# full-screen. The page itself remembers your camera/mic choice and starts
# connecting automatically, so this single double-click is the entire
# startup procedure.

URL="https://training-call.onrender.com"

if command -v chromium-browser >/dev/null 2>&1; then
  BROWSER=chromium-browser
elif command -v chromium >/dev/null 2>&1; then
  BROWSER=chromium
elif command -v google-chrome >/dev/null 2>&1; then
  BROWSER=google-chrome
elif command -v google-chrome-stable >/dev/null 2>&1; then
  BROWSER=google-chrome-stable
else
  zenity --error --text="Could not find Chromium or Chrome installed.\n\nEdit launch-training-call.sh and set the BROWSER variable to your browser's command." 2>/dev/null \
    || echo "Could not find Chromium or Chrome installed. Edit this script to point at your browser, then run it again."
  exit 1
fi

# --app removes the address bar/tabs entirely (a clean app-style window).
# --start-fullscreen launches that window already filling the screen.
"$BROWSER" --app="$URL" --start-fullscreen >/dev/null 2>&1 &
disown 2>/dev/null

exit 0
