#!/usr/bin/env bash
# Build the Mac app (SaynataMac, menu bar) and install it on this Mac. An installed copy is replaced; the result
# cache and settings in its container are kept. The app is opened at the end. Safe to run again.
#
#   scripts/install-on-mac.sh                          # Release build into ~/Applications
#   CONFIG=Debug scripts/install-on-mac.sh             # default Release
#   INSTALL_DIR=/Applications scripts/install-on-mac.sh
#   AD_HOC=1 scripts/install-on-mac.sh                 # sign for this Mac only, no Apple ID (if signing fails)
#   NO_OPEN=1 scripts/install-on-mac.sh                # do not open the app at the end
#
# Run it on the Mac, from anywhere in the repo. Needs Xcode. After it, the Services item "Explain with Saynata"
# and its ⌘⇧E key are registered again, so a new build's Services changes show at once.
set -euo pipefail

cd "$(dirname "$0")/.."    # repo root

PROJECT="EnglishTranslation/EnglishTranslation.xcodeproj"
SCHEME="SaynataMac"
APP_NAME="SaynataMac.app"
CONFIG="${CONFIG:-Release}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
BUILD_DIR="build/mac"

# Stop before anything is changed when the inputs look wrong.
if [ "$(uname)" != "Darwin" ]; then
  echo "Run this on the Mac (it needs Xcode)." >&2
  exit 1
fi
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Install Xcode, then: sudo xcode-select -s /Applications/Xcode.app" >&2
  exit 1
fi
case "$CONFIG" in
  Debug|Release) ;;
  *) echo "CONFIG must be Debug or Release, not '$CONFIG'." >&2; exit 1 ;;
esac
if [ ! -d "$PROJECT" ]; then
  echo "Cannot find $PROJECT. Run the script from the saynata-old repo." >&2
  exit 1
fi

signing=(-allowProvisioningUpdates)
if [ "${AD_HOC:-0}" = "1" ]; then
  # "Sign to run locally": works on this Mac only, no Apple ID needed.
  signing=(CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER=)
  echo "Signing ad hoc (this Mac only)."
fi

echo "1/4 Building $SCHEME ($CONFIG)..."
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
  -destination "platform=macOS" -derivedDataPath "$BUILD_DIR" -quiet "${signing[@]}" build

BUILT="$BUILD_DIR/Build/Products/$CONFIG/$APP_NAME"
if [ ! -d "$BUILT" ]; then
  echo "The build finished but $BUILT is missing." >&2
  exit 1
fi

echo "2/4 Quitting the running copy..."
osascript -e 'tell application id "com.luke.EnglishTranslation.Mac" to quit' >/dev/null 2>&1 || true
for _ in 1 2 3 4 5; do
  pgrep -x SaynataMac >/dev/null || break
  sleep 1
done
pkill -x SaynataMac 2>/dev/null || true

echo "3/4 Installing into $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
rm -rf "${INSTALL_DIR:?}/$APP_NAME"
ditto "$BUILT" "$INSTALL_DIR/$APP_NAME"

echo "4/4 Registering the app and its Services item..."
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREGISTER" -f "$INSTALL_DIR/$APP_NAME" >/dev/null 2>&1 || true
/System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true

if [ "${NO_OPEN:-0}" != "1" ]; then
  open "$INSTALL_DIR/$APP_NAME"
  echo "Installed and opened: look for the two-cat icon in the menu bar. ⌥⇧Space opens the panel; ⌘⇧E explains selected text."
else
  echo "Installed: $INSTALL_DIR/$APP_NAME"
fi
