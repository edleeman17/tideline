#!/bin/sh
# shot.sh <name> : save the watch display to /t/build/shots/<name>.png.
# fenix847mm crop is known; other devices (DEV set) save the full screen as <name>-full.png.
mkdir -p /t/build/shots
import -window root /tmp/full.png
if [ "${DEV:-fenix847mm}" = fenix847mm ]; then
  convert /tmp/full.png -crop 454x454+133+243 +repage \( -size 454x454 xc:black -fill white -draw "circle 227,227 227,0" \) -alpha off -compose CopyOpacity -composite /t/build/shots/$1.png
else
  cp /tmp/full.png /t/build/shots/$1-full.png
fi
