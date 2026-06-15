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
APPLICATIONS_APP="/Applications/$APP_NAME.app"
USER_APPLICATIONS_APP="$HOME/Applications/$APP_NAME.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
STALE_APP_ARCHIVE="$DERIVED_DATA/StaleApps"

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

unregister_app() {
  local app_path="$1"
  if [[ -e "$app_path" || -L "$app_path" ]]; then
    "$LSREGISTER" -u "$app_path" >/dev/null 2>&1 || true
  fi
}

archive_stale_app() {
  local app_path="$1"
  local archive_path

  if [[ ! -e "$app_path" && ! -L "$app_path" ]]; then
    return
  fi

  if [[ "$(cd "$(dirname "$app_path")" && pwd -P)/$(basename "$app_path")" == "$APP_BUNDLE" ]]; then
    return
  fi

  unregister_app "$app_path"

  if [[ -L "$app_path" ]]; then
    rm -f "$app_path"
    return
  fi

  mkdir -p "$STALE_APP_ARCHIVE"
  archive_path="$STALE_APP_ARCHIVE/$(basename "$app_path").$(date +%Y%m%d-%H%M%S)"
  echo "Archiving stale $APP_NAME bundle: $app_path -> $archive_path"
  mv "$app_path" "$archive_path"
}

normalize_launch_targets() {
  local global_derived_data="$HOME/Library/Developer/Xcode/DerivedData"

  archive_stale_app "$APPLICATIONS_APP"
  archive_stale_app "$USER_APPLICATIONS_APP"

  if [[ -d "$global_derived_data" ]]; then
    while IFS= read -r app_path; do
      archive_stale_app "$app_path"
    done < <(
      find "$global_derived_data" \
        -path "*/Build/Products/$CONFIGURATION/$APP_NAME.app" \
        -type d \
        -prune \
        -print 2>/dev/null || true
    )
  fi

  ln -s "$APP_BUNDLE" "$APPLICATIONS_APP"
  "$LSREGISTER" -f -R -trusted "$APP_BUNDLE" >/dev/null 2>&1 || true
  "$LSREGISTER" -f -R -trusted "$APPLICATIONS_APP" >/dev/null 2>&1 || true

  echo "$APPLICATIONS_APP -> $(readlink "$APPLICATIONS_APP")"
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
  /usr/bin/open -n "$APP_BUNDLE" --args --open "$ROOT_DIR"
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
build_app
normalize_launch_targets

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
