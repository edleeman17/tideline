#!/bin/sh
# Headless Connect IQ simulator session. Build the image from sim/Dockerfile, then:
#   docker run --rm -v <connectiq dir with sdk-9.3.0/ + jdk/>:/ciq:ro -v ~/.Garmin:/garmin-home/.Garmin \
#     -v $PWD:/t ciq-sim sh /t/sim/session.sh wait:20 Down Return Return Down Return shot:now
# Steps: a key name (Down, Up, Return = START, Escape = BACK), wait:N, tap:x,y,
# drag:x1,y1,x2,y2, relaunch, shot:name (saved to build/shots/name.png).
# The simulator ignores the first few keys while it warms up, hence the prefix above.
# DEV=<device id> picks the watch (default fenix847mm).
export DISPLAY=:9 HOME=/garmin-home PATH=/ciq/jdk/bin:$PATH
SDK=/ciq/sdk-9.3.0/bin
Xvfb :9 -screen 0 1400x1000x24 >/dev/null 2>&1 & sleep 2
$SDK/simulator >/tmp/sim.log 2>&1 & sleep 8
$SDK/monkeydo /t/build/Tideline.prg ${DEV:-fenix847mm} >/tmp/md.log 2>&1 & sleep 10
for k in "$@"; do
  case "$k" in
    shot:*) sh /t/sim/shot.sh "${k#shot:}";;
    wait:*) sleep "${k#wait:}";;
    relaunch) pkill -f monkeydo; sleep 2; $SDK/monkeydo /t/build/Tideline.prg ${DEV:-fenix847mm} >>/tmp/md.log 2>&1 & sleep 12;;
    tap:*) xy=${k#tap:}; xdotool mousemove ${xy%,*} ${xy#*,} click 1; sleep 4;;
    drag:*) a=${k#drag:}; set -- $(echo $a | tr ',' ' '); xdotool mousemove $1 $2 mousedown 1; for i in 1 2 3 4 5; do xdotool mousemove $(( $1 + ($3-$1)*i/5 )) $(( $2 + ($4-$2)*i/5 )); sleep 0.1; done; xdotool mouseup 1; sleep 2;;
    *) xdotool key "$k"; sleep 6;;
  esac
done
tail -5 /tmp/md.log
