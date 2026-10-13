# Uptick React Native Demo

This repository contains a small Expo app that shows the **Uptick React Native Web SDK** (`uptick-ads/react-native-web-sdk`) on a mock order-confirmation screen. One `UptickFlow` is mounted in the page flow; it renders inline or as a popup depending on the placement's template on the Uptick side.
Use it to see the integration working end to end, to try the SDK against a test environment, and as a reference when wiring the component into your own app.

Setup is a one-time pass through [One-time setup](#one-time-setup), then [Run the app](#run-the-app) each day. If something goes wrong, check [Troubleshooting](#troubleshooting) first; every entry there is a problem that has actually come up.

## One-time setup

Do these in order. Each step ends with a command that confirms it worked.

### 1. mise, Node and Java

[mise](https://mise.jdx.dev) provides Node for Expo and the JDK for Android builds.

```
brew install mise
echo 'eval "$(mise activate zsh)"' >> ~/.zshrc    # skip if ~/.zshrc already has it
exec zsh

mise use -g node@24.13.0
mise use -g java@temurin-21
```

Check: `node -v` prints v24.13.0, `java -version` prints 21, and `echo $JAVA_HOME` points into `~/.local/share/mise/installs/java`.

The Node version must match the same version used for the `react-native-web-sdk` project in order for the `npm link @uptick-ads/react-native-web-sdk` to work correctly.

Use JDK 17 or 21. Android Studio ships JDK 25, and pointing `JAVA_HOME` at it makes the Android build fail in `configureCMakeDebug` with `A restricted method in java.lang.System has been called`.

### 2. Xcode (iOS)

1. Install Xcode from the App Store, open it once and accept the components it offers, including an iOS simulator runtime.
2. Point the command line tools at Xcode. Without this, `xcrun simctl` fails and `expo start` prints `Unable to run simctl … code 72`:

   ```
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```

Check: `xcrun simctl list devices available` lists iPhones. The examples use `iPhone 18 Pro`; any listed name works.

### 3. Android Studio (Android)

1. Install [Android Studio](https://developer.android.com/studio) and open it once so it installs the SDK.
2. **More Actions → Virtual Device Manager**, then add a device. The examples use `Pixel_10a`.
3. Put the SDK tools on your PATH by adding this to `~/.zshrc`, then `exec zsh`:

   ```
   export ANDROID_HOME="$HOME/Library/Android/sdk"
   export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"
   ```

   Don't set `JAVA_HOME` here; mise sets it (step 1).

Check: `emulator -list-avds` lists your device and `adb version` runs.

### 4. The project

```
npm install
cp .env.example .env.local
```

Then edit `.env.local`:

| Variable | Value |
| --- | --- |
| `EXPO_PUBLIC_UPTICK_HOST` | API host, e.g. `api.uptick.test` for a local Uptick API ([below](#testing-against-a-local-uptick-api)) |
| `EXPO_PUBLIC_UPTICK_INTEGRATION_ID` | An integration's public id ([how to choose](#choosing-an-integration-and-placements)) |
| `EXPO_PUBLIC_UPTICK_INLINE_PLACEMENT` | A placement that integration actually has, usually `order_confirmation`. The example's `checkout` doesn't exist in the local seed data and returns a 422 |
| `EXPO_PUBLIC_UPTICK_POPUP_PLACEMENT` | Same, for the popup chip |
| `EXPO_PUBLIC_UPTICK_INLINE_INTEGRATION_ID` / `EXPO_PUBLIC_UPTICK_POPUP_INTEGRATION_ID` | Optional; set when the inline and popup placements live on different integrations |

Expo reads `.env.local` only when Metro starts, so restart Metro after editing it.

## Run the app

Everything is available from VS Code's **Tasks: Run Task**; each task runs a script in `tools/` that also works from a terminal.

| Task | Script | What it does |
| --- | --- | --- |
| Start Metro | `tools/metro.sh` | Starts the bundler both platforms load the app from. Runs when the folder opens. If this project's Metro is already serving port 8081, it reuses it instead of stopping at Expo's "Use port 8082 instead?" prompt; if another project's is, it stops and says how to free the port |
| Android: Start proxy | `tools/android_proxy.sh` | Runs the [resolver proxy](#android-emulator) on port 8899 (`PROXY_PORT=` to change). Runs when the folder opens and does nothing if the proxy is already up |
| SDK: npm link | `tools/sdk_link.sh link` | Links the local SDK checkout (`../react-native-web-sdk`, or `SDK_DIR=`) into this app, then restarts Metro with `--clear`. See [Working on the SDK](#working-on-the-sdk-and-the-demo-together) |
| SDK: npm unlink | `tools/sdk_link.sh unlink` | Removes the local link, restores the registry copy from `package-lock.json`, then restarts Metro with `--clear` |
| iOS: Start simulator | `tools/ios_simulator.sh start` | Boots the simulator (`IOS_DEVICE=` to change), opens its window and trusts puma-dev's CA. Stays running; ending the task shuts the simulator down |
| iOS: Open app in Expo Go | `tools/ios_simulator.sh open` | Installs Expo Go if the simulator lacks it, then opens the app. Takes a path, e.g. `"/--/?target=popup"` |
| iOS: Stop simulator | `tools/ios_simulator.sh stop` | Shuts the simulator down |
| Android: Start emulator | `tools/android_emulator.sh start` | Boots the emulator (`AVD=` to change) as `emulator-5554` (`EMULATOR_PORT=` to change), so it works with a phone or another emulator attached; forwards Metro's port and points the emulator at the [resolver proxy](#android-emulator), starting the proxy only if it isn't already running. Stays running and shows the proxy log; ending the task, running the stop task or closing the emulator window undoes all of it |
| Android: Build and install dev app | `tools/android_dev_build.sh` | Builds the app with puma-dev's CA built in and installs it. Needed for the local API on Android |
| Android: Regenerate native project and rebuild | `CLEAN=1 tools/android_dev_build.sh` | Recreates `android/` from `app.json`, config plugins and the Expo version, then builds and installs. Use after changing any of those |
| Android: Stop emulator | `tools/android_emulator.sh stop` | Clears the emulator's proxy setting, then stops the proxy and the emulator |
| Web: Serve demo page | `tools/web.sh` | Serves the [browser page](#web-browser) on port 8090 (`WEB_PORT=` to change) and opens it. Stays running; ending the task stops the server |

**Metro and the Android proxy start when the folder opens**, and the device tasks don't start Metro for you, so leave Metro running. VS Code asks once whether to allow automatic tasks on folder open; accept it, or they won't start on load. Run **SDK: npm link** or **SDK: npm unlink** and they restart Metro for you.

### iOS

1. **Start Metro**
2. **iOS: Start simulator**, and wait until it reports `ready:`
3. Open the app:
   - **The first time on this Mac:** click into the **Start Metro** terminal and press `i`. Expo CLI downloads Expo Go, installs it on the booted simulator and opens the app. **iOS: Open app in Expo Go** can't do this step, because it installs Expo Go only from Expo CLI's download cache, which is empty until then.
   - **Every time after that:** **iOS: Open app in Expo Go**. It also reinstalls Expo Go from the cache on a simulator that doesn't have it.

On first launch, Expo Go shows a developer menu introduction over the app; tap **Continue**.

### Android

1. **Start Metro**
2. **Android: Start emulator**, and wait until it reports `ready:`
3. Open the app:
   - **Against a local Uptick API:** run **Android: Build and install dev app**. The first build downloads Gradle and dependencies and takes several minutes; later builds take seconds. After that, relaunch it with the **Uptick Demo** icon or `adb shell monkey -p com.anonymous.rnwebviewdemo 1`. JavaScript changes don't need a rebuild; Metro serves them. After a native change, rebuild with the right task:
     - New or updated native package (`npm install`): **Android: Build and install dev app**.
     - `app.json`, a config plugin, or an Expo upgrade: **Android: Regenerate native project and rebuild** (`CLEAN=1 tools/android_dev_build.sh`). The plain build task reuses the existing `android/` folder, which is generated from those files only when it's missing, so without regenerating, the change never reaches the app.
   - **Against a public API host, in Expo Go:** the first time, click into the **Start Metro** terminal and press `a`; Expo CLI installs Expo Go on the emulator and opens the app. After that, `adb shell am start -a android.intent.action.VIEW -d exp://127.0.0.1:8081 host.exp.exponent`.

Use the Metro terminal's keys rather than a second `npx expo start --ios` or `--android`: a second Expo CLI finds port 8081 taken and stops at "Use port 8082 instead?". The keys don't work when **Start Metro** reused a Metro that was already running (it says `Metro already running on 8081; using it`); press them in that Metro's own terminal instead.

On a fresh launch the events panel often shows `webview_error net::ERR_NAME_NOT_RESOLVED`; tap **Reload**. See [Troubleshooting](#troubleshooting) for why.

### Web (browser)

The Expo app doesn't run on web: the SDK renders through `react-native-webview`, which has no browser implementation. Instead, `web/index.html` shows the same order confirmation with the Uptick web SDK installed the way a publisher site installs it ([docs](https://docs.uptick.com/publishers/web)). It doesn't use the React Native SDK at all, so use it to check an integration and placement on their own, and to tell an integration problem from a WebView problem.

Run **Web: Serve demo page**. It writes `web/config.js` from `.env.local`, so the chips load the same integrations and placements as the app's; rerun it after editing `.env.local`. The page takes the same [launch parameters](#launch-parameters) in its URL, e.g. `http://localhost:8090/?target=popup&host=api.uptick.com&id=<integration id>`. `offers.js` is loaded from the API host with `api.` swapped for `app.`; add `script_host=` to override that.

Against a local Uptick API, nothing extra is needed in Safari or Chrome: the Mac resolves `*.uptick.test`, and both browsers trust puma-dev's CA through the keychain. Firefox keeps its own certificate store, so import the CA there or use another browser.

The events panel and status line work as in the app, and each event also prints in the browser console as `[uptick-demo] web …`. A `script_error` means `offers.js` didn't load (unknown integration id, or an untrusted certificate); `js_error Uptick Error: … Uptick Network Error` usually means the integration has no such placement.

### Without VS Code

The same steps by hand. Boot the device first, then start Metro in its own terminal and leave it running; the first time, press `i` (iOS) or `a` (Android) in that terminal to install Expo Go and open the app.

```
# iOS
xcrun simctl boot "iPhone 18 Pro"
open -a DeviceHub                                     # Simulator.app before Xcode 27
xcrun simctl keychain booted add-root-cert ~/Library/Application\ Support/io.puma.dev/cert.pem
npx expo start                                        # own terminal; first time, press i in it
xcrun simctl openurl booted exp://127.0.0.1:8081      # later runs, from another terminal

# Android
emulator -avd Pixel_10a &
adb wait-for-device
adb reverse tcp:8081 tcp:8081                         # repeat after every emulator restart
npx expo start                                        # own terminal
python3 tools/resolver_proxy.py 8899 &                # local API only
adb shell settings put global http_proxy 10.0.2.2:8899
tools/android_dev_build.sh                            # CLEAN=1 after app.json, config plugin or Expo changes
# when done: adb shell settings put global http_proxy :0
```

### Launch parameters

The chips switch between the two placements so both presentations can be seen. The mode can also be switched without touching the screen, which is handy for automated checks:

```
xcrun simctl openurl booted "exp://127.0.0.1:8081/--/?target=popup"                                             # iOS
adb shell am start -a android.intent.action.VIEW -d "exp://127.0.0.1:8081/--/?target=popup" host.exp.exponent   # Android, Expo Go
```

`target` is `inline` or `popup`; `host`, `id` and `placement` override the API host, integration id and placement for that session.

### Reading the app's events

The events panel at the bottom of the screen shows what the SDK did, newest first. The status line under the chips shows the integration and placement in use and ends in `rendered inline` or `rendered popup` once an offer shows. The same events print in Metro's terminal as `LOG  [uptick-demo] …`, and on iOS also land in the simulator log:

```
xcrun simctl spawn booted log show --last 5m --style compact --predicate 'eventMessage CONTAINS "uptick-demo"'
```

## Testing against a local Uptick API

The SDK loads `https://<host>/v1/places/<id>/embed` and the scripts and API it references (`api.uptick.test`, `app.uptick.test`), so the device has to resolve those names and trust their certificates.

Start the platform's dev server first (see the platform repo); puma-dev serves it as `*.uptick.test` with certificates signed by its CA at `~/Library/Application Support/io.puma.dev/cert.pem`. Check from the Mac before involving a device:

```
curl -s -o /dev/null -w "%{http_code}\n" https://api.uptick.test/
```

### iOS simulator

Nothing extra. The simulator resolves the Mac's names, including `*.test`, and Expo Go's WebView trusts the simulator keychain, which **iOS: Start simulator** adds puma-dev's CA to. Expo Go works as is, and the first load works without a Reload.

### Android emulator

The emulator doesn't see the Mac's `.test` resolver, and Expo Go's WebView trusts only system CAs, so Android needs two things, both handled by the tasks:

- **Name resolution:** `tools/resolver_proxy.py` is a small proxy on the Mac that resolves names for the emulator. It listens on `127.0.0.1` only, which the emulator reaches as `10.0.2.2`, so it isn't an open proxy to the rest of the network. **Android: Start proxy** runs it when the folder opens, and **Android: Start emulator** sets the emulator's proxy to `10.0.2.2:8899` and starts the proxy if it's missing. Its log shows `CONNECT api.uptick.test:443 -> 127.0.0.1` when the WebView goes through it.
- **Certificate trust:** **Android: Build and install dev app** builds the app with puma-dev's CA built in (from `PUMA_DEV_CA`, default the path above), so no certificate has to be installed in the emulator's Settings, which needs root on Google Play images anyway.

While the proxy setting is on and the proxy isn't running, the emulator has no network at all. **Android: Stop emulator** clears it; by hand, `adb shell settings put global http_proxy :0`.

### Choosing an integration and placements

`EXPO_PUBLIC_UPTICK_INTEGRATION_ID` is an integration's public id, listed at https://dashboard.uptick.test/integrations while the platform dev server runs (sign in first). `placement` is matched against the integration's placement pages (`render_page`), so it has to be one the integration actually has, usually `order_confirmation` or `order_status`; anything else returns `422 Integration placement not found`. Whether a placement renders inline or as a popup comes from its template, so pick an integration whose placement uses an inline template for the inline chip and one with a popup template for the popup chip.

Without the dashboard, the platform's development database lists them:

```
psql uptick_development -c "select i.public_id, i.name, p.render_page, t.name as template
  from integration_placements p
  join integration_places i on i.id = p.integration_place_id
  join integration_templates t on t.id = p.integration_template_id
  where p.enabled and t.kind = 'web' and t.discarded_at is null
  order by t.render_type, i.name"
```

Check a candidate from the Mac before touching the app; 200 means the integration and placement resolve:

```
curl -s -o /dev/null -w "%{http_code}\n" "https://api.uptick.test/v1/places/<id>/embed?placement=order_confirmation&variant=native"
```

These worked with the local seed data:

```
EXPO_PUBLIC_UPTICK_HOST=api.uptick.test
EXPO_PUBLIC_UPTICK_INTEGRATION_ID=6566682a-1bec-57de-b0de-4142debba234          # Northbound Outfitters, Web Template 1.2 (Popup)
EXPO_PUBLIC_UPTICK_INLINE_INTEGRATION_ID=29927783-d2f2-5fc9-9e43-e1cd5e991a13   # Pawsome Pet Supply, Web Template 1.2 (Inline)
EXPO_PUBLIC_UPTICK_INLINE_PLACEMENT=order_confirmation
EXPO_PUBLIC_UPTICK_POPUP_PLACEMENT=order_confirmation
```

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `expo start` prints `Unable to run simctl … code 72`, or `xcrun: unable to find utility "simctl"` | Command line tools point at the standalone Command Line Tools, not Xcode | `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| `open -a Simulator` fails | Xcode 27 replaced Simulator.app with DeviceHub | `open -a DeviceHub`; the iOS task handles both |
| Expo stops at `Use port 8082 instead? (Y/n)` | A second Expo CLI was started while Metro holds 8081, e.g. `npx expo start --ios` next to the Start Metro task | Press `i` or `a` in the running Metro's terminal instead, or stop it first: `lsof -ti tcp:8081 \| xargs kill` |
| Start Metro says port 8081 is held by something other than this project's Metro | Another project's Metro, or another server, is on 8081 | Stop it: `lsof -ti tcp:8081 \| xargs kill`, then rerun the task |
| **iOS: Open app in Expo Go** says Expo CLI hasn't downloaded Expo Go yet | First run on this Mac | Press `i` in the Start Metro terminal once |
| Edits to `.env.local` have no effect | Expo reads it only at startup | Restart Metro |
| Edits to the code don't reload | Metro was started with `CI=1`, which disables watching | Restart it with a plain `npx expo start` |
| `npx: command not found` from a task or script | The shell didn't load mise | `tools/metro.sh` adds mise's shims itself; elsewhere, check `eval "$(mise activate zsh)"` is in `~/.zshrc` |
| Android build fails in `configureCMakeDebug` with `A restricted method in java.lang.System has been called` | Building with Android Studio's JDK 25 | Use JDK 17 or 21 (setup step 1); `tools/android_dev_build.sh` picks mise's `temurin-21` when `JAVA_HOME` is unset |
| `./gradlew clean` fails in `externalNativeBuildClean` | React Native's CMake clean step | Delete the build output instead: `rm -rf android/app/build android/app/.cxx android/build node_modules/expo-modules-core/android/.cxx` |
| `SDK location not found` from Gradle | `ANDROID_HOME` not set in that shell | Setup step 3, or run Gradle through `tools/android_dev_build.sh` |
| Android: Expo Go sits on its loading spinner and Metro never logs `Android Bundled` | The emulator can't reach the Mac's LAN address Expo chose | Open over localhost: `adb reverse tcp:8081 tcp:8081`, then `adb shell am start -a android.intent.action.VIEW -d exp://127.0.0.1:8081 host.exp.exponent`. If Expo Go is hung from an earlier session, `adb shell am force-stop host.exp.exponent` first |
| Android: `webview_error net::ERR_NAME_NOT_RESOLVED` | Either the WebView's first request skipped the proxy (normal on a fresh launch), or the proxy isn't set up | Tap **Reload**. If it persists, check **Android: Start emulator** is running and `adb shell settings get global http_proxy` prints `10.0.2.2:8899` |
| Android: `js_error offers.js failed to load`, with `net_error -201` in `adb logcat` | puma-dev issued that host's certificate on the first request, timestamped a moment ahead of the emulator's clock; the WebView remembers the failure until the app restarts | `adb shell am force-stop com.anonymous.rnwebviewdemo`, relaunch, then tap **Reload** if needed |
| **Android: Start emulator** says `Port 8899 is in use by … not the resolver proxy` | Another program holds the proxy port | Stop it, or pick another port: `PROXY_PORT=8898 tools/android_emulator.sh start` |
| Android: no network in the emulator at all | The proxy setting outlived the proxy | `adb shell settings put global http_proxy :0`, or run **Android: Stop emulator** |
| Android: "System UI isn't responding" dialog | The emulator is busy, typically while booting | Tap **Wait** |
| `webview_http_error` with status 404 | The integration id doesn't exist on that host | [Choose an integration](#choosing-an-integration-and-placements) |
| `422 Integration placement not found` | The integration has no placement with that name, e.g. `checkout` | Use one it has, usually `order_confirmation` |
| `dashboard.uptick.test` redirects to sign in | The dashboard needs a login | Sign in, or use the `psql` query above |
| Metro: `TreeFS: Could not add directory node_modules/@uptick-ads/react-native-web-sdk … already exists in the file map as a file` | Metro's cached file map still has the package from a previous link or symlink | Run **SDK: npm unlink** (or **SDK: npm link**), which restarts Metro with `--clear`; or restart Metro with `npx expo start --clear` |
| Android: `Android: Start proxy` isn't running after opening the folder | VS Code hasn't allowed automatic tasks for this workspace | Accept the prompt, or run the task from **Tasks: Run Task** |

## Working on the SDK and the demo together

To run the demo against a local checkout of the SDK, use the **SDK: npm link** task. It expects the checkout at `../react-native-web-sdk` (set `SDK_DIR=` to use another path), runs `npm link` in the checkout and then in this app, and restarts Metro with `--clear` so the new resolution takes effect. **SDK: npm unlink** removes the link and restores the registry copy pinned in `package-lock.json`, then restarts Metro the same way.

A linked checkout brings its own `node_modules`, including its own copies of `react` and `react-native`, which can differ from the app's versions. If the app shows hook errors or a native view registered twice after linking, the two copies are the likely cause; the fix is to remove the SDK checkout's `node_modules` copies of those packages, or to keep the SDK's self-dependency out of its `package.json`. Unlink when you're done to go back to the pinned registry copy.

## License

See `LICENSE`.
