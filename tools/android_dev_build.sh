#!/bin/bash
# Builds and installs a debug Android app for the spike.
# Expo Go's WebView only trusts system CAs, so a dev build with a network security config that also trusts user CAs is needed to reach puma-dev's TLS from the emulator.
set -euo pipefail
cd "$(dirname "$0")/.."
export JAVA_HOME="${JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"

if [ ! -d android ]; then
  npx expo prebuild --platform android --no-install
fi

mkdir -p android/app/src/main/res/xml
cat > android/app/src/main/res/xml/network_security_config.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
  <base-config cleartextTrafficPermitted="true">
    <trust-anchors>
      <certificates src="system" />
      <certificates src="user" />
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
