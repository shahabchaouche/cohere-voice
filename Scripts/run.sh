#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -z "${DEVELOPMENT_TEAM:-}" ]]; then
  print -u2 "Set DEVELOPMENT_TEAM to your Apple development team ID before running this signed installer."
  print -u2 "For a build without signing, use the xcodebuild command in README.md."
  exit 2
fi

if ! xcodebuild -version >/dev/null 2>&1 && [[ -z "${DEVELOPER_DIR:-}" ]]; then
  xcode_app=""
  for candidate in /Applications/Xcode*.app(N); do
    [[ -x "${candidate}/Contents/Developer/usr/bin/xcodebuild" ]] || continue
    [[ "${candidate}" == *Beta* ]] || xcode_app="${candidate}"
  done
  if [[ -z "${xcode_app}" ]]; then
    for candidate in /Applications/Xcode*.app(N); do
      [[ -x "${candidate}/Contents/Developer/usr/bin/xcodebuild" ]] && xcode_app="${candidate}"
    done
  fi
  if [[ -n "${xcode_app}" ]]; then
    export DEVELOPER_DIR="${xcode_app}/Contents/Developer"
    echo "Using DEVELOPER_DIR=${DEVELOPER_DIR}"
    echo "To make this permanent: sudo xcode-select -s ${xcode_app}"
  fi
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  print -u2 "Xcode is required. Set DEVELOPER_DIR to an Xcode.app/Contents/Developer path and retry."
  exit 2
fi

xcodebuild -project CohereVoice.xcodeproj -scheme CohereVoice \
  -configuration Debug -derivedDataPath build build \
  "DEVELOPMENT_TEAM=${DEVELOPMENT_TEAM}"

BUILT="build/Build/Products/Debug/CohereVoice.app"
APP_BUNDLE_ID="com.shahab.coherevoice"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
DEST="${INSTALL_DIR}/CohereVoice.app"
[[ -d "${BUILT}" ]] || { print -u2 "Built app not found at ${BUILT}."; exit 1; }
[[ "${INSTALL_DIR}" == /* ]] || { print -u2 "INSTALL_DIR must be an absolute path."; exit 2; }
if ! codesign --verify --strict "${BUILT}"; then
  print -u2 "The built app's code signature is not trusted. Check that your Apple Development certificate is valid and trusted, then retry."
  exit 1
fi

if [[ -e "${DEST}" || -L "${DEST}" ]]; then
  [[ -d "${DEST}" && ! -L "${DEST}" ]] || { print -u2 "Refusing to replace a non-app path at ${DEST}."; exit 1; }
  installed_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${DEST}/Contents/Info.plist" 2>/dev/null || true)"
  [[ "${installed_id}" == "${APP_BUNDLE_ID}" ]] || { print -u2 "Refusing to replace an app with a different bundle ID at ${DEST}."; exit 1; }
  [[ -t 0 ]] || { print -u2 "Confirmation is required to replace ${DEST}; run this script interactively."; exit 2; }
  printf 'Replace existing %s? [y/N] ' "${DEST}"
  read -r reply
  case "${reply}" in
    y|Y|yes|YES) ;;
    *) echo "Install cancelled."; exit 0 ;;
  esac

  installed_executable="${DEST}/Contents/MacOS/CohereVoice"
  if lsof -t "${installed_executable}" >/dev/null 2>&1; then
    osascript -e "tell application id \"${APP_BUNDLE_ID}\" to quit"
    for (( attempt = 0; attempt < 20; attempt++ )); do
      lsof -t "${installed_executable}" >/dev/null 2>&1 || break
      sleep 0.5
    done
    if lsof -t "${installed_executable}" >/dev/null 2>&1; then
      print -u2 "The installed app is still running. Close it before replacing ${DEST}."
      exit 1
    fi
  fi
fi

mkdir -p "${INSTALL_DIR}"
staging_root="$(mktemp -d "${INSTALL_DIR}/.CohereVoice-install.XXXXXX")"
cleanup() {
  if [[ -d "${staging_root}/previous.app" && ! -e "${DEST}" ]]; then
    mv "${staging_root}/previous.app" "${DEST}" || {
      print -u2 "Could not restore the previous app; it remains at ${staging_root}/previous.app."
      return
    }
  fi
  rm -rf "${staging_root}"
}
trap cleanup EXIT

ditto "${BUILT}" "${staging_root}/new.app"
if [[ -d "${DEST}" ]]; then
  mv "${DEST}" "${staging_root}/previous.app"
fi
mv "${staging_root}/new.app" "${DEST}"
echo "Installed to ${DEST}"
open "${DEST}"
echo "Launched ${DEST}"
