#!/bin/bash
# Builds and installs a debug Android app for the spike.
# Expo Go's WebView only trusts system CAs, so a dev build with a network security config that also trusts puma-dev's CA is needed to reach puma-dev's TLS from the emulator.
set -euo pipefail
cd "$(dirname "$0")/.."
# Needs JDK 17 or 21; Android Studio's bundled JDK 25 fails the React Native CMake configure step.
export JAVA_HOME="${JAVA_HOME:-$(mise where java@temurin-21 2>/dev/null)}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"

# android/ is generated from app.json, config plugins and the Expo version, and is only created when missing.
# After changing any of those, CLEAN=1 regenerates it so the change reaches the app; the CA and network config below are re-applied either way.
if [ "${CLEAN:-}" = 1 ]; then
  npx expo prebuild --platform android --clean --no-install
elif [ ! -d android ]; then
  npx expo prebuild --platform android --no-install
fi

# Bundle puma-dev's CA so the app trusts it without installing a user certificate through the emulator's Settings.
PUMA_DEV_CA="${PUMA_DEV_CA:-$HOME/Library/Application Support/io.puma.dev/cert.pem}"
mkdir -p android/app/src/main/res/raw
cp "$PUMA_DEV_CA" android/app/src/main/res/raw/puma_dev_ca.pem

mkdir -p android/app/src/main/res/xml
cat > android/app/src/main/res/xml/network_security_config.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
  <base-config cleartextTrafficPermitted="true">
    <trust-anchors>
      <certificates src="system" />
      <certificates src="user" />
      <certificates src="@raw/puma_dev_ca" />
    </trust-anchors>
  </base-config>
</network-security-config>
XML

MANIFEST=android/app/src/main/AndroidManifest.xml
if ! grep -q "networkSecurityConfig" "$MANIFEST"; then
  sed -i '' 's#<application #<application android:networkSecurityConfig="@xml/network_security_config" #' "$MANIFEST"
fi

# The app connects to the Metro already started by `expo start`, so skip a second bundler.
npx expo run:android --no-bundler
