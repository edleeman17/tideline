#!/bin/sh
# shot.sh <name> : save the 454x454 watch display (round-masked) to /t/build/shots/<name>.png
mkdir -p /t/build/shots
import -window root /tmp/full.png
convert /tmp/full.png -crop 454x454+133+243 +repage \( -size 454x454 xc:black -fill white -draw "circle 227,227 227,0" \) -alpha off -compose CopyOpacity -composite /t/build/shots/$1.png
