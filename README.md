# Uptick React Native Demo

This repository contains a small Expo app that shows the **Uptick React Native Web SDK** (`uptick-ads/react-native-web-sdk`) on a mock order-confirmation screen, inline and as a native modal.
Use it to see the integration working end to end, to try the SDK against a test environment, and as a reference when wiring the component into your own app.

## Run

```
cp .env.example .env.local   # set EXPO_PUBLIC_UPTICK_INTEGRATION_ID
npm install
npx expo start --ios --android
```

The presentation must match the placement's template on your Uptick account: pick an inline-template placement to see the inline slot, a popup-template placement to see the modal.

The mode can also be switched without touching the screen, which is handy for automated checks:

```
xcrun simctl openurl booted "exp://<host>:8081/--/?mode=modal"
```

`mode` is `inline` or `modal`; `host`, `id` and `placement` override the API host, integration id and placement for that session.

## Testing against a local Uptick API

The SDK talks to `https://<host>/v1/places/<id>/embed` and to the assets and API it references, so the device needs to resolve and trust your local hostnames.

- **iOS simulator** resolves the host machine's names. Trust the local development CA once with `xcrun simctl keychain booted add-root-cert <ca.pem>`.
- **Android emulator** does not see local resolver rules, and Expo Go's WebView trusts only system CAs. `tools/resolver_proxy.py` forwards guest traffic through the host's resolver (`adb shell settings put global http_proxy 10.0.2.2:8899`), install the development CA as a user certificate, and build the app with `tools/android_dev_build.sh`, which adds a network security config that trusts user CAs.
- Working on the SDK and the demo together: `npm install ../react-native-web-sdk` replaces the GitHub dependency with your checkout.

## License

See `LICENSE`.
