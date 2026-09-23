# Uptick React Native Demo

This repository contains a small Expo app that shows the **Uptick React Native Web SDK** (`uptick-ads/react-native-web-sdk`) on a mock order-confirmation screen. One `UptickFlow` is mounted in the page flow; it renders inline or as a popup depending on the placement's template on the Uptick side.
Use it to see the integration working end to end, to try the SDK against a test environment, and as a reference when wiring the component into your own app.

## Run

```
cp .env.example .env.local   # set EXPO_PUBLIC_UPTICK_INTEGRATION_ID
npm install
npx expo start --ios --android
```

The chips switch between two placements so both presentations can be seen: `EXPO_PUBLIC_UPTICK_INLINE_PLACEMENT` should use an inline template and `EXPO_PUBLIC_UPTICK_POPUP_PLACEMENT` a popup template. When the two placements belong to different integrations, set the per-target integration ids as well.

The mode can also be switched without touching the screen, which is handy for automated checks:

```
xcrun simctl openurl booted "exp://<host>:8081/--/?target=popup"
```

`target` is `inline` or `popup`; `host`, `id` and `placement` override the API host, integration id and placement for that session.

## Testing against a local Uptick API

The SDK talks to `https://<host>/v1/places/<id>/embed` and to the assets and API it references, so the device needs to resolve and trust your local hostnames.

- **iOS simulator** resolves the host machine's names. Trust the local development CA once with `xcrun simctl keychain booted add-root-cert <ca.pem>`.
- **Android emulator** does not see local resolver rules, and Expo Go's WebView trusts only system CAs. `tools/resolver_proxy.py` forwards guest traffic through the host's resolver (`adb shell settings put global http_proxy 10.0.2.2:8899`), install the development CA as a user certificate, and build the app with `tools/android_dev_build.sh`, which adds a network security config that trusts user CAs.
- Working on the SDK and the demo together: `npm install ../react-native-web-sdk` replaces the GitHub dependency with your checkout.

## License

See `LICENSE`.
