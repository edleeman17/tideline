#!/bin/sh
# Build Tideline. Usage: ./build.sh [device]   (default fenix847mm)
#   ./build.sh export   -> Store package build/Tideline.iq (all devices in manifest)
set -e
cd "$(dirname "$0")"
D=${CIQ:-$HOME/opt/connectiq}  # holds sdk-9.3.0/ and jdk/
export PATH=$D/jdk/bin:$PATH
KEY=${TIDELINE_KEY:-./developer_key.der}  # your Connect IQ developer key (never commit it)
mkdir -p build
if [ "$1" = export ]; then
  "$D/sdk-9.3.0/bin/monkeyc" -f app/monkey.jungle -e -r -y "$KEY" -l 0 -w -o build/Tideline.iq
  echo "Built build/Tideline.iq"
else
  DEV=${1:-fenix847mm}
  "$D/sdk-9.3.0/bin/monkeyc" -f app/monkey.jungle -d "$DEV" -y "$KEY" -l 0 -w -o build/Tideline.prg
  echo "Built build/Tideline.prg ($DEV)"
fi
