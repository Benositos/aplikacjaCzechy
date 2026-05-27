# CLAUDE.md

You're helping port **Calma** (Android-complete) to **iOS**. Read this before touching code — it captures architectural decisions and pitfalls that aren't obvious from the source.

## What this is

Calma is a local-only step counter + screen time tracker built for a Polish high school IT project. Stack: Flutter. Data never leaves the device — no accounts, no backend, no analytics, no network calls of any kind. This is a hard requirement, not a preference.

**Repo state**: Android works on real devices (tested on Samsung One UI and stock Pixel-ish). iOS is the default Flutter scaffold — your job. The previous developer (working with Claude) finished Android, then handed the repo to a teammate (with you) to add iOS.

There's a related ongoing change in the original developer's local copy: a "hybrid" screen-time path that combines `queryEvents` with `queryAndAggregateUsageStats` to handle custom time-zone selection. That work is not in this repo and is **not relevant to the iOS port** — start with what's here. If the developer later pushes a `hybrid` branch, leave it alone unless asked.

## Stack — all versions pinned, keep them pinned

| Dependency | Version | Notes |
|---|---|---|
| Flutter | 3.44 | stable bleeding-edge as of May 2026 |
| Dart | 3.12 | |
| flutter_riverpod | 2.6.1 | state mgmt |
| go_router | 14.6.1 | StatefulShellRoute for tab nav |
| drift | 2.21.0 | SQLite ORM, code-gen |
| sqlite3 | 2.9.4 | |
| flutter_local_notifications | 17.2.4 | |
| fl_chart | 0.69.2 | |
| google_fonts | 6.3.3 | Inter + IBM Plex Mono |
| image_picker | 1.1.2 | avatar |
| permission_handler | 11.4.0 | |

We learned the hard way that caret ranges cause week-over-week breakage. **Don't add `^` to versions.**

## Architecture

```
lib/
  core/
    theme/        # design tokens (Inventors "Calm Dense" stylesheet — grayscale + 5 accents)
    router/       # go_router config with StatefulShellRoute (Steps / Focus / Profile / Settings tabs)
  data/
    local/        # Drift DB — database.dart + tables/ + database_provider.dart
    services/     # platform bridges: health_service.dart, usage_service.dart, notification_service.dart
    repositories/ # business layer composing services + DB
  features/
    steps/    focus/    profile/    settings/    onboarding/
android/app/src/main/kotlin/com/calma/calma/
  HealthChannel.kt    # androidx.health.connect.client (steps)
  UsageChannel.kt     # UsageStatsManager (screen time)
  MainActivity.kt     # FlutterFragmentActivity — required for registerForActivityResult
ios/Runner/             # default scaffold; your work goes here
```

**Drift code-gen**: `dart run build_runner build --delete-conflicting-outputs`. The `*.g.dart` files are gitignored — regenerate on every clone.

## What iOS needs to implement

Two `MethodChannel`s, defined in Dart, called from native. **Match the contracts exactly** so no Dart changes are needed.

### `com.calma.health` — steps via HealthKit

| Method | Args (Dart→native) | Returns | Behavior |
|---|---|---|---|
| `sdkStatus` | — | `Int` 1\|2\|3 | 1=unavailable, 2=needsUpdate, 3=available. iOS: return 3 if `HKHealthStore.isHealthDataAvailable()`, else 1. |
| `hasPermission` | — | `Bool` | true if read-authorization for `HKQuantityTypeIdentifierStepCount` is granted. Note HealthKit doesn't expose read-authorization directly — query a tiny sample and check if it errors with `.notDetermined`. |
| `requestPermission` | — | `Bool` | call `requestAuthorization(toShare: nil, read: [stepCount])`. Returns true if Sample query subsequently succeeds. |
| `getStepsForRange` | `startMs: Int64`, `endMs: Int64` | `List<Map>` of `{dateMs: Int64, steps: Int64}` | Aggregate per local day. Use `HKStatisticsCollectionQuery` with `intervalComponents = DateComponents(day: 1)` anchored at local midnight. `dateMs` = epoch ms of that local day's start. |

**iOS setup**:
- `Info.plist`: `NSHealthShareUsageDescription` with user-facing copy (App Store rejects without it)
- `Runner.entitlements`: enable HealthKit capability
- Read-only — never request write. We don't write steps.
- Real iPhone required for testing — simulator has no Health data.

### `com.calma.usage` — screen time

**⚠️ Apple does not let third-party apps read general screen time.**

The relevant API is `DeviceActivity` (Screen Time API, iOS 15+), which requires the `com.apple.developer.family-controls` entitlement. Apple grants this **only to apps in the Family/Parental Controls category**. A self-tracking app will not pass App Store review with this entitlement. Don't spend time fighting it.

**Recommended implementation**: stub the channel.

| Method | Behavior |
|---|---|
| `hasPermission` | return `false` unconditionally |
| `openSettings` | open `URL(string: "app-settings:")` |
| `queryUsage` | return empty `[]` |

Then add a banner in `lib/features/focus/focus_screen.dart` shown only when `Platform.isIOS`:

> Screen time tracking is Android-only — Apple doesn't allow third-party apps to read this data.

This is the honest answer. The teacher reviewing this project will understand a platform constraint; they won't understand a half-broken feature.

## Implementation order

1. **Clone & build**:
   ```bash
   flutter pub get
   dart run build_runner build --delete-conflicting-outputs
   cd ios && pod install && cd ..
   flutter run -d <iphone>
   ```
   The app will boot, onboarding will show. Steps and Focus tabs will be empty / log channel errors until you implement the native side.

2. **Implement `HealthChannel.swift`** in `ios/Runner/`. Register it from `AppDelegate.swift` using `FlutterMethodChannel(name: "com.calma.health", ...)`. Match the table above exactly.

3. **Manual test on a real iPhone with HealthKit data** (your own iPhone is fine — sync some steps via Apple Watch or the Health app's "Add Data" if you have none). Verify the HealthKit sheet appears on first launch, then Steps tab populates.

4. **Stub `UsageChannel.swift`** per the table above. Don't try to implement real screen time.

5. **Add the iOS screen-time banner** to `focus_screen.dart` behind `Platform.isIOS`.

6. **Polish**: app icon (iOS uses `flutter_launcher_icons` config in `pubspec.yaml` — already set up), splash screen (`flutter_native_splash` — already set up). Run the generators if assets look off.

7. **Archive & distribute**: TestFlight is the easy path. Don't put it on the App Store — the teacher just needs to see it run.

## Things that have already burned us — don't repeat

- **`health` package (Flutter)**: on Android, `requestAuthorization` returned before the user actually tapped Allow, causing permission flakiness. We rewrote against `androidx.health.connect.client` directly. **For iOS, prefer raw HealthKit over wrappers** for the same reason.
- **`usage_stats` / `app_usage` packages**: dependency hell, jcenter (removed). Custom channel was the right call. Don't reintroduce.
- **`FlutterActivity` vs `FlutterFragmentActivity`** (Android): Flutter 3.44 dropped `ComponentActivity` from `FlutterActivity`, breaking `registerForActivityResult`. We use `FlutterFragmentActivity`. This is Android-only — iOS doesn't have this concern.
- **`CupertinoPageTransitionsBuilder` removed from `material.dart`** in 3.44. We removed `pageTransitionsTheme` entirely. Don't add it back.
- **Drift `schemaVersion`**: currently 1. If you add or change a column, bump it AND write the `onUpgrade` migration. Forgetting the migration crashes existing installs.
- **Don't add network code.** Strict local-only. No Firebase, no analytics, no crash reporting, no `http` package. The project's privacy story is its main differentiator.
- **Don't refactor for refactor's sake.** The previous developer iterated heavily; the code is intentional. Ask before restructuring.

## Per-machine files that must NOT be committed

Already in `.gitignore`, but worth knowing:
- `android/local.properties` (Android SDK path)
- `android/key.properties` (if signing is set up)
- `ios/Pods/`, `ios/Flutter/Generated.xcconfig`, `ios/Flutter/flutter_export_environment.sh`
- `ios/Runner.xcodeproj/xcuserdata/` and `ios/Runner.xcworkspace/xcuserdata/` (your Xcode preferences)
- `*.g.dart` (regenerated by build_runner)

## When something's unclear

Read the Dart-side service files first (`lib/data/services/health_service.dart`, `lib/data/services/usage_service.dart`) — the method calls and expected return shapes are the source of truth for the channel contract.

Read the Kotlin implementation (`android/app/src/main/kotlin/com/calma/calma/`) for reference behavior — your iOS code should *behave* the same, not *look* the same. Different platforms, different idioms.

If a design decision seems weird, check the comments — most non-obvious choices have a `// reason:` line nearby. If still unclear, ask the developer rather than guessing what a Polish high school project might need.
