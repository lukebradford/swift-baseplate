#!/usr/bin/env bash
#
# preflight.sh — fail-closed App Store submission checks for a built iOS .app bundle.
#
# Baseplate is a library, so this tool is for the APPS that consume it: run it against a
# built .app (Debug or Release) before you archive/submit, to catch the boring, recurring
# rejection classes that cost a full review cycle each — a missing usage-description string,
# an absent privacy manifest, a placeholder marketing version, an http:// legal URL.
#
# Usage:
#   Tools/preflight.sh /path/to/YourApp.app
#   Tools/preflight.sh /path/to/YourApp.app --support-url https://you.example/support \
#                                            --privacy-url https://you.example/privacy
#
# Exit code: 0 if no FAILs (WARNs are allowed), 1 if any FAIL, 2 on usage error.
#
# It never modifies anything. It reads the bundle and, only if you pass URLs, does a HEAD
# request to check they resolve. No dependency beyond macOS's plutil / PlistBuddy / strings.

set -u

APP=""
SUPPORT_URL=""
PRIVACY_URL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --support-url) SUPPORT_URL="${2:-}"; shift 2 ;;
    --privacy-url) PRIVACY_URL="${2:-}"; shift 2 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) APP="$1"; shift ;;
  esac
done

if [ -z "$APP" ]; then
  echo "usage: preflight.sh /path/to/YourApp.app [--support-url URL] [--privacy-url URL]" >&2
  exit 2
fi
if [ ! -d "$APP" ]; then
  echo "error: not a directory: $APP" >&2
  exit 2
fi

FAILS=0
WARNS=0
pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; WARNS=$((WARNS+1)); }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAILS=$((FAILS+1)); }
section() { printf '\n\033[1m%s\033[0m\n' "$1"; }

PLIST="$APP/Info.plist"
plist_get() { /usr/libexec/PlistBuddy -c "Print :$1" "$PLIST" 2>/dev/null; }

echo "Preflighting: $APP"

# ---------------------------------------------------------------------------
section "Bundle & Info.plist"
if [ ! -f "$PLIST" ]; then
  fail "Info.plist missing at $PLIST"
  echo; echo "Cannot continue without Info.plist."; exit 1
fi
if plutil -lint "$PLIST" >/dev/null 2>&1; then
  pass "Info.plist is valid"
else
  fail "Info.plist fails plutil -lint"
fi

BUNDLE_ID=$(plist_get "CFBundleIdentifier")
[ -n "$BUNDLE_ID" ] && pass "CFBundleIdentifier: $BUNDLE_ID" || fail "CFBundleIdentifier missing"

SHORT_VER=$(plist_get "CFBundleShortVersionString")
BUILD_VER=$(plist_get "CFBundleVersion")
case "$SHORT_VER" in
  ""|"0.0"|"0.0.0"|"1.0"|"\$(MARKETING_VERSION)") warn "CFBundleShortVersionString looks like a placeholder: '${SHORT_VER:-<empty>}'" ;;
  *) pass "CFBundleShortVersionString: $SHORT_VER" ;;
esac
[ -n "$BUILD_VER" ] && pass "CFBundleVersion: $BUILD_VER" || fail "CFBundleVersion missing"

# App icon present (either an actual file or the asset catalog primary icon name).
if plist_get "CFBundleIcons" >/dev/null 2>&1 || ls "$APP"/AppIcon* >/dev/null 2>&1; then
  pass "App icon reference present"
else
  warn "No CFBundleIcons / AppIcon* found — verify a marketing icon is set"
fi

# ---------------------------------------------------------------------------
section "Privacy manifest (required by App Store since 2024)"
if find "$APP" -name "PrivacyInfo.xcprivacy" -print -quit | grep -q .; then
  pass "PrivacyInfo.xcprivacy present"
else
  fail "No PrivacyInfo.xcprivacy in the bundle — Apple requires a privacy manifest"
fi

# ---------------------------------------------------------------------------
section "Permission usage-description strings"
# Map a symbol the binary might reference -> the Info.plist key Apple then requires.
BIN="$APP/$(plist_get CFBundleExecutable)"
if [ ! -f "$BIN" ]; then
  warn "Executable not found; skipping binary symbol scan"
else
  SYMS=$(strings -a "$BIN" 2>/dev/null)
  check_usage() { # <needle> <plist-key> <human>
    if grep -q "$1" <<<"$SYMS"; then
      if [ -n "$(plist_get "$2")" ]; then
        pass "$3: references $1 and declares $2"
      else
        fail "$3: binary references $1 but $2 is missing from Info.plist"
      fi
    fi
  }
  check_usage "AVCaptureDevice"       "NSCameraUsageDescription"           "Camera"
  check_usage "PHPhotoLibrary"        "NSPhotoLibraryUsageDescription"     "Photos"
  check_usage "CLLocationManager"     "NSLocationWhenInUseUsageDescription" "Location"
  check_usage "AVAudioApplication"    "NSMicrophoneUsageDescription"       "Microphone"
  check_usage "CNContactStore"        "NSContactsUsageDescription"         "Contacts"
  check_usage "EKEventStore"          "NSCalendarsUsageDescription"        "Calendars"
  check_usage "ATTrackingManager"     "NSUserTrackingUsageDescription"     "App Tracking"
  [ $FAILS -eq 0 ] && [ $WARNS -eq 0 ] && pass "No permission symbols without a matching usage string"
fi

# ---------------------------------------------------------------------------
section "StoreKit"
if grep -q "SKPaymentQueue\|StoreKit" <<<"${SYMS:-}"; then
  pass "StoreKit is linked (IAP-capable build)"
else
  warn "StoreKit not detected in the binary — fine if the app has no purchases"
fi

# ---------------------------------------------------------------------------
section "Legal URLs"
# Flag any http:// (non-TLS) URL embedded in Info.plist.
if /usr/bin/grep -aoE 'http://[^< ]+' "$PLIST" >/dev/null 2>&1; then
  warn "Info.plist contains http:// (non-HTTPS) URLs — App Review and ATS dislike these"
else
  pass "No http:// URLs in Info.plist"
fi
check_url() { # <url> <label>
  [ -z "$1" ] && return 0
  code=$(curl -sS -o /dev/null -w '%{http_code}' -I --max-time 12 "$1" 2>/dev/null)
  if [ "$code" = "200" ] || [ "$code" = "301" ] || [ "$code" = "302" ]; then
    pass "$2 resolves ($code): $1"
  else
    fail "$2 did not resolve (got '${code:-error}'): $1"
  fi
}
check_url "$SUPPORT_URL" "Support URL"
check_url "$PRIVACY_URL" "Privacy URL"

# ---------------------------------------------------------------------------
echo
if [ $FAILS -gt 0 ]; then
  printf '\033[31mPREFLIGHT FAILED\033[0m — %d fail(s), %d warning(s)\n' "$FAILS" "$WARNS"
  exit 1
else
  printf '\033[32mPREFLIGHT PASSED\033[0m — 0 fails, %d warning(s)\n' "$WARNS"
  exit 0
fi
