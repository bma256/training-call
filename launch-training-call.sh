#!/bin/bash

# Force extended-desktop mode (not mirrored) before launching, in case the
# OS display setting ever gets changed by another project. HDMI-1 stays
# primary; HDMI-2 is placed directly to its LEFT at the same resolution
# (swapped from the original right-side layout). If your second screen is
# ever physically on the RIGHT instead, change "--pos -1920x0" below to
# "--pos 1920x0".
xrandr --output HDMI-1 --primary --mode 1920x1080 --pos 0x0 --output HDMI-2 --mode 1920x1080 --pos -1920x0 2>/dev/null

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
