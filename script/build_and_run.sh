#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/Dynamite.xcodeproj"
SCHEME="Dynamite"
CONFIGURATION="Debug"
APP_NAME="Dynamite"
DERIVED_DATA="$ROOT_DIR/.derivedData"
SOURCE_PACKAGES="$ROOT_DIR/.SourcePackages"
APP_BUNDLE="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
APP_EXECUTABLE="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
BUNDLE_ID="app.codeedit.Dynamite"
STALE_APPLICATIONS_APP="/Applications/$APP_NAME.app"

stop_existing_app() {
  local pids
  pids="$(pgrep -x "$APP_NAME" || true)"
  if [[ -z "$pids" ]]; then
    return
  fi

  echo "Stopping existing $APP_NAME processes:"
  for pid in $pids; do
    ps -p "$pid" -o pid=,command= || true
  done
  kill $pids >/dev/null 2>&1 || true

  for _ in {1..20}; do
    if ! pgrep -x "$APP_NAME" >/dev/null; then
      return
    fi
    sleep 0.25
  done

  echo "Force-stopping unresponsive $APP_NAME processes" >&2
  pkill -9 -x "$APP_NAME" >/dev/null 2>&1 || true
}

warn_about_stale_app_copy() {
  if [[ -d "$STALE_APPLICATIONS_APP" ]]; then
    echo "warning: $STALE_APPLICATIONS_APP exists and is not the branch build." >&2
    echo "warning: do not use Finder, open -a $APP_NAME, or $STALE_APPLICATIONS_APP for branch testing." >&2
    echo "warning: this script launches $APP_BUNDLE" >&2
  fi
}

build_app() {
  xcodebuild -resolvePackageDependencies \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -derivedDataPath "$DERIVED_DATA" \
    -clonedSourcePackagesDirPath "$SOURCE_PACKAGES"

  "$ROOT_DIR/scripts/apply-editor-perf-patch.sh"

  xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA" \
    -clonedSourcePackagesDirPath "$SOURCE_PACKAGES" \
    CODE_SIGNING_ALLOWED=NO
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE" --args "$ROOT_DIR"
}

verify_running_app() {
  local deadline=$((SECONDS + 20))
  local pids pid command

  while (( SECONDS < deadline )); do
    pids="$(pgrep -x "$APP_NAME" || true)"
    for pid in $pids; do
      command="$(ps -p "$pid" -o command= || true)"
      if [[ "$command" == "$APP_EXECUTABLE"* ]]; then
        echo "Verified $APP_NAME pid $pid"
        echo "Running binary: $APP_EXECUTABLE"
        return 0
      fi
    done
    sleep 1
  done

  echo "error: $APP_NAME did not launch from the expected branch build." >&2
  echo "expected: $APP_EXECUTABLE" >&2
  echo "running $APP_NAME processes:" >&2
  pids="$(pgrep -x "$APP_NAME" || true)"
  if [[ -n "$pids" ]]; then
    for pid in $pids; do
      ps -p "$pid" -o pid=,command= >&2 || true
    done
  else
    echo "none" >&2
  fi
  exit 1
}

stop_existing_app
warn_about_stale_app_copy
build_app

case "$MODE" in
  run)
    open_app
    verify_running_app
    ;;
  --debug|debug)
    lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    ;;
  --logs|logs)
    open_app
    verify_running_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    verify_running_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    verify_running_app
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
