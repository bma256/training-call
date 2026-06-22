#!/bin/bash
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
  echo "Could not find Chromium or Chrome installed. Edit this script to point at your browser, then run it again."
  exit 1
fi

"$BROWSER" --app="$URL" --window-size=1280,800 --window-position=0,0 >/dev/null 2>&1 &
disown 2>/dev/null
exit 0
