# Locally patched `tracelet_ios`

This is a vendored copy of the published `tracelet_ios` package (pinned to
3.8.10, matching `pubspec.yaml`), wired in via a git `dependency_override`.

## Why vendored instead of a git dependency override

The upstream monorepo (github.com/Ikolvi/Tracelet) doesn't build standalone:
`packages/tracelet_ios` there depends on a separate `TraceletSDK` CocoaPods
pod (built from `sdk/ios/`) that only resolves inside their own workspace.
The *published* pub.dev package (what's vendored here) flattens that SDK
source directly into `tracelet_ios/Sources/tracelet_ios/TraceletSDK/` and
swaps the podspec to fetch a prebuilt `TraceletCore.xcframework` release
instead — that's the structure that actually builds standalone, so this
copy is taken from there rather than from a git checkout of the monorepo.

`TraceletCore.xcframework` itself is intentionally **not** committed — it's
fetched fresh by `ios/ensure_xcframework.rb` during `pod install`, exactly
as it would be for the unpatched published package (see `.gitignore`).

## The patches

1. **`TraceletSDK/location/LiveActivityManager.swift`, `startOnMain()`**:
   reconnects to an existing `Activity<TraceletActivityAttributes>` (via the
   static, OS-level `Activity.activities` list) instead of always ending it
   and requesting a fresh one. Upstream's unconditional end-and-recreate
   reliably failed to recreate the activity during a killed-state relaunch
   (`"Target is not foreground"`), which destroyed a perfectly good Live
   Activity and never replaced it.

2. **`TraceletIosPlugin.swift`, `requestTokenRefresh()`**: routes a
   killed-state 401 through `HeadlessRunner.requestHeadersRefresh()` instead
   of falling through to `syncBodyChannel.invokeMethod` with no live engine
   to answer it. Without this, a token refresh triggered while the app was
   killed just timed out after `dartCallbackTimeout`, and sync stayed broken
   for the rest of the process once the access token expired.

3. **`TraceletIosPlugin.swift` (new `setPluginRegistrantCallback` /
   `pluginRegistrantCallback`) + `HeadlessRunner.swift` `spawnEngine()`**: lets
   the host app register `GeneratedPluginRegistrant` on `HeadlessRunner`'s
   on-demand `FlutterEngine`, mirroring `workmanager_apple`'s
   `WorkmanagerPlugin.setPluginRegistrantCallback`. Without this, any plugin
   used inside a headless Dart callback (e.g. `flutter_secure_storage`,
   needed to read a refresh token in `registerHeadlessHeadersCallback`)
   throws `MissingPluginException` — the headless engine has no native
   handlers beyond the two channels `HeadlessRunner` wires by hand. The host
   app must call this once, e.g. in `AppDelegate.swift`:
   ```swift
   TraceletIosPlugin.setPluginRegistrantCallback { registry in
     GeneratedPluginRegistrant.register(with: registry)
   }
   ```

4. **`HeadlessRunner.swift`, `dispatchOrQueue()` / `onEngineReady()`**: holds
   the background task open until the Dart side's `invokeMethod` reply
   actually comes back, instead of firing the call and immediately treating
   the event as delivered. A headless callback that returns a `Future` could
   previously be silently cut off mid-work if the process suspended right
   after the fire-and-forget call.

5. **`TraceletSDK/location/TerminationSafeguardManager.swift`** (new file) +
   wiring in `TraceletSdk.swift` (`start()`/`stop()`/`setConfig` reset/init):
   a dedicated `CLLocationManager` running
   `startMonitoringSignificantLocationChanges()` for the lifetime of a
   tracking session, independent of the main location engine and
   `BackgroundActivitySessionManager`. Significant-location-change monitoring
   is one of the few things iOS will relaunch a terminated app for, so this
   gives continuous tracking an extra relaunch trigger beyond whatever the
   main engine's own background modes provide.

6. **`TraceletSDK/location/LiveActivityManager.swift`, pending refresh**:
   queues the latest `update` requested while a start is in flight and
   applies it once that start's activity exists. A live-stats refresh racing
   `ready()`'s auto-resume was otherwise dropped, leaving the activity on its
   static body.

7. **`TraceletIosPlugin.swift`, `requestTokenRefresh()` no-handler fallback**:
   when the primary engine answers "not implemented" instead of a `Bool`,
   routes to `HeadlessRunner.requestHeadersRefresh()` as patch 2 does for a
   nil primary. A host app that registers plugins on a throwaway engine during
   a location relaunch (so `autoResumeTracking()` gets wired) makes that
   engine the primary, yet it never runs the Dart code that installs the
   `requestTokenRefresh` handler — so a 401 there was never refreshed.
   `requestFreshHeaders()` is deliberately left alone: it runs before every
   batch, and a headless token refresh per batch would be wrong.

The pure-Dart half lives in `packages/tracelet/lib/src/tracelet.dart`: the
headless dispatcher awaits a `Future`-returning callback (pairs with patch 4).

Fork: https://github.com/chaser79/Tracelet, branch `hydrove/3.8.10`. None of
these had landed upstream as of 3.8.10 (checked against the published
`tracelet_ios-3.8.10` source).

## Upgrading

When bumping the `tracelet`/`tracelet_ios` version in `pubspec.yaml`, redo
this vendoring against the new version rather than hand-merging: copy the
new `~/.pub-cache/hosted/pub.dev/tracelet_ios-<version>` over this
directory (minus `TraceletCore.xcframework`, which never belongs here),
then reapply the patches above (diff the previous fork branch against
the previous published version to get them as a patch). Check upstream's changelog/PRs first —
drop whichever patch (and this whole directory, if all of them land) has
landed instead of reapplying it.
