#!/usr/bin/env bash
# Records a real run on an iOS simulator and takes App Store screenshots.
#
#   tool/store_capture.sh <simulator udid> <out dir> <preview WxH>
#
# e.g. tool/store_capture.sh 394464AE-... output/store/iphone-6.9 886x1920
#      tool/store_capture.sh DA203691-... output/store/ipad-13   1200x1600
#
# Drives integration_test/store_capture_test.dart, watches the phase file the
# test writes, shoots each phase with `simctl io screenshot`, then trims and
# scales the recording into an App Preview (H.264, 30 fps, silent AAC track).
set -euo pipefail
UDID=$1; OUT=$2; PREVIEW=$3
BUNDLE=com.ivan9527945.ropeEscape
cd "$(dirname "$0")/.."
mkdir -p "$OUT"
rm -f "$OUT"/*.png "$OUT"/*.mov "$OUT"/*.mp4

xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator --args -CurrentDeviceUDID "$UDID"
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged \
  --batteryLevel 100 --cellularBars 4 --wifiBars 3 2>/dev/null || true
# Stale phase file from a previous run would fire screenshots too early.
CONTAINER=$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data 2>/dev/null || true)
[ -n "$CONTAINER" ] && rm -f "$CONTAINER/Documents/capture-phase.txt"

REC_START=$(date +%s.%N)
xcrun simctl io "$UDID" recordVideo --codec h264 --force "$OUT/raw.mov" &
REC_PID=$!
flutter test integration_test/store_capture_test.dart -d "$UDID" >"$OUT/test.log" 2>&1 &
TEST_PID=$!

now() { echo "$(date +%s.%N) - $REC_START" | bc; }
LAST=""; N=0; T_PLAY=""; T_RESULT=""; T_HINT=""
while kill -0 "$TEST_PID" 2>/dev/null; do
  if [ -z "$CONTAINER" ]; then
    CONTAINER=$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data 2>/dev/null || true)
  fi
  FILE="$CONTAINER/Documents/capture-phase.txt"
  if [ -n "$CONTAINER" ] && [ -f "$FILE" ]; then
    PHASE=$(cat "$FILE" 2>/dev/null || true)
    if [ -n "$PHASE" ] && [ "$PHASE" != "$LAST" ]; then
      LAST=$PHASE
      case $PHASE in
        hint) T_HINT=$(now) ;;
        play) [ -z "$T_PLAY" ] && T_PLAY=$(now) ;;
        result) T_RESULT=$(now) ;;
      esac
      if [ "$PHASE" != resume ] && [ "$PHASE" != done ]; then
        sleep 0.6
        N=$((N + 1))
        xcrun simctl io "$UDID" screenshot "$OUT/$(printf %02d "$N")-$PHASE.png" >/dev/null
        echo "shot $PHASE at $(now)s"
      fi
    fi
  fi
  sleep 0.2
done
wait "$TEST_PID" || { echo "integration test failed, see $OUT/test.log"; kill -INT "$REC_PID"; exit 1; }
kill -INT "$REC_PID"; wait "$REC_PID" || true

# Clip: the 30 s App Preview starts just before the first move; if the run
# ended sooner, back up so the clip is still at least 15 s long.
START=$(echo "${T_HINT:-0} - 0.5" | bc)
END=$(echo "$START + 29" | bc)
LIMIT=$(echo "${T_RESULT:-$(now)} + 2.5" | bc)
if [ "$(echo "$END > $LIMIT" | bc)" = 1 ]; then END=$LIMIT; fi
if [ "$(echo "$END - $START < 15" | bc)" = 1 ]; then START=$(echo "$END - 15" | bc); fi
[ "$(echo "$START < 0" | bc)" = 1 ] && START=0
W=${PREVIEW%x*}; H=${PREVIEW#*x}
ffmpeg -loglevel error -y -ss "$START" -to "$END" -i "$OUT/raw.mov" \
  -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
  -vf "scale=$W:$H:force_original_aspect_ratio=increase,crop=$W:$H,fps=30,format=yuv420p" \
  -c:v libx264 -profile:v high -crf 25 -preset slow -c:a aac -b:a 96k -shortest -movflags +faststart \
  "$OUT/preview-$PREVIEW.mp4"
echo "clip ${START}s → ${END}s"
ls -la "$OUT"
