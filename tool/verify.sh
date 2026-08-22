#!/usr/bin/env bash
#
# Runs every db_exporter path against a real device and verifies the output.
#
#   ./tool/verify.sh              # first connected device
#   ./tool/verify.sh -d <id>      # a specific device
#   ./tool/verify.sh --pull       # also copy the exported files back here
#
# Unlike `flutter test`, this executes on the device, so it exercises the parts
# that only exist there: path_provider directories, the real SQLite build, and
# scoped storage.
set -euo pipefail

cd "$(dirname "$0")/.."
FLUTTER=${FLUTTER:-$(command -v flutter || echo "fvm flutter")}
DEVICE=""
PULL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--device) DEVICE="$2"; shift 2 ;;
    --pull)      PULL=true; shift ;;
    -h|--help)   sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)           echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

step() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }
fail() { printf '\033[1;31mFAILED:\033[0m %s\n' "$1" >&2; exit 1; }

# ---------------------------------------------------------------- device ----
if [[ -z "$DEVICE" ]]; then
  step "Looking for a device"
  DEVICE=$($FLUTTER devices --machine 2>/dev/null \
    | python3 -c "
import json,sys
try: devices = json.load(sys.stdin)
except Exception: devices = []
usable = [d for d in devices
          if d.get('targetPlatform','').startswith(('android','ios'))
          and not d.get('emulator', False) or d.get('emulator', False)]
mobile = [d for d in usable
          if 'android' in d.get('targetPlatform','')
          or 'ios' in d.get('targetPlatform','')]
print(mobile[0]['id'] if mobile else '')
")
  [[ -n "$DEVICE" ]] || fail "no Android or iOS device connected. Start an emulator/simulator, or pass -d <id>."
fi
echo "Device: $DEVICE"

# ------------------------------------------------------------- analysis ----
step "Analysing the package"
$FLUTTER pub get >/dev/null
$FLUTTER analyze || fail "package analysis"

step "Analysing the example"
(cd example && $FLUTTER pub get >/dev/null && $FLUTTER analyze) \
  || fail "example analysis"

# ------------------------------------------------------------ unit tests ----
step "Unit tests"
$FLUTTER test || fail "unit tests"

# ----------------------------------------------------- on-device tests ----
step "On-device export tests (every database x format x destination)"
(cd example && $FLUTTER test integration_test/export_test.dart -d "$DEVICE") \
  || fail "integration tests"

# ----------------------------------------------------------------- pull ----
if $PULL; then
  step "Pulling exported files"
  mkdir -p build/exports
  if $FLUTTER devices --machine | grep -q "\"$DEVICE\".*android"; then
    PKG=com.example.db_exporter_example
    adb -s "$DEVICE" exec-out run-as "$PKG" tar c files 2>/dev/null \
      | tar x -C build/exports 2>/dev/null \
      || echo "  (could not pull — app may not be debuggable)"
    echo "  -> build/exports/"
  else
    echo "  (iOS: use Xcode > Devices to download the app container)"
  fi
fi

printf '\n\033[1;32mAll checks passed.\033[0m\n'
