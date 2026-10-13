# Solution — Mr D Vendor Locator

A SwiftUI app to browse Mr D vendors, see them on a Google Map, and manage a session token stored in the Keychain.

## At a glance

| Brief | Where it lives |
|---|---|
| Task 1: vendor list, favorites, reload, friendly errors, light/dark | `Features/VendorList`, `VendorsViewModel`, `UserFacingError` |
| Task 2: Google Map, markers, recenter on select, one Places feature | `Features/Map`, `Core/Places` |
| Task 3: Keychain token, Settings screen, token used by the network layer | `Core/Security`, `Features/Settings`, `URLSessionAPIClient` |
| Bonus: map ↔ list highlighting | Map card → list scroll + highlight; list → map recenter |
| Bonus: CI + Fastlane | `.github/workflows/ci.yml`, `fastlane/Fastfile` |
| Unit tests (XCTest) | `MrDVendorLocatorTests` — 40 tests |

## Architecture

**MVVM with a single composition root.**

```
Views (SwiftUI)  →  View models (@Observable, @MainActor)  →  Protocols  →  Concrete services
                                                              VendorRepository   RemoteVendorRepository
                                                              APIClient          URLSessionAPIClient + StubURLProtocol
                                                              TokenStore         KeychainTokenStore
                                                              Geocoding          GooglePlacesGeocoder / MockGeocoder (+ CachingGeocoder)
```

- **`AppDependencies`** is the only place that creates concrete services. View models receive protocols through `init`, which is what makes them testable without a network, Keychain or Google.
- **One shared `VendorsViewModel`** is owned at the app root and injected with `.environment(_:)`. The list and the map read the same instance, so favorites, load state and selection never drift apart. Selecting a vendor in the list switches to the Map tab and animates the camera to it.
- **`ViewState<T>`** (`idle / loading / loaded / empty / failed`) makes every screen state explicit, so there is no combination of booleans that can disagree.
- **Errors are mapped twice:** transport/HTTP errors become a typed `APIError`, and `APIError` becomes a `UserFacingError` with a title, a message and an action (`Try Again` or `Open Settings`). Views never see raw errors.

### Concurrency

- async/await throughout; no Combine.
- The target uses Xcode's default **MainActor isolation**, so UI code is main-actor by default and types that work off the main thread (models, networking, Keychain, geocoding) are explicitly `nonisolated` or an `actor`.
- **Reload cancels the in-flight load** before starting a new one, so pull-to-refresh can't race an older response onto the screen.
- Vendors without coordinates are geocoded **concurrently with a `TaskGroup`**. One failed address is logged and skipped; it doesn't fail the list.

## Networking: local stub instead of a real API

The brief asks for REST over JSON with no backend, so the app talks to `https://api.mrd.local/v1/vendors` through a **`URLProtocol` stub** that serves the bundled `vendors.json`.

I chose this over decoding the JSON file directly because the real code path still runs: `URLSession`, the `Authorization: Bearer` header, status-code handling, decoding and error mapping. Swapping in a real backend means changing the base URL and dropping the stub from the session — nothing else.

The stub:
- adds ~600 ms latency so loading states are visible,
- returns **401** when no token is sent,
- in Debug builds, can be switched in Settings → Developer to return a **500** or simulate **offline**, to demo the error states.

The stub is attached to its own `URLSession`, not registered globally, so it can't intercept unrelated requests.

## Places enhancement: address → coordinates

I chose **address → coordinates** (the brief asks for exactly one). Three vendors in `vendors.json` ship with an address but no coordinate; they are resolved at runtime and then appear as pins.

**Integration boundary:** the view model depends only on

```swift
protocol Geocoding: Sendable {
    func coordinate(for address: String) async throws -> Coordinate
}
```

Implementations:
- **`GooglePlacesGeocoder`** — Places SDK (Places API (New)) text search, biased to South Africa, returning only the coordinate field to keep requests cheap. Note: the SDK's `SearchByTextRequest` defaults `isOpenNow` to `true`, which would silently drop closed vendors, so it is set to `false` explicitly.
- **`CachingGeocoder`** — an `actor` that wraps any `Geocoding`. It caches by normalised address and shares in-flight lookups, so the same address is never requested twice at once. Failures aren't cached, so they can be retried.
- **`MockGeocoder`** — a fixed table, used in tests and as the fallback when no key is configured.

### How it connects to real keys

1. `Config/Secrets.xcconfig` (gitignored) sets `GMS_API_KEY`.
2. `Config/App.xcconfig` (committed) defaults it to empty and optionally includes `Secrets.xcconfig`, so a fresh clone builds without a key.
3. `Config/Info.plist` exposes it as `GMSApiKey = $(GMS_API_KEY)`.
4. At launch, `GoogleMapsPlatform` reads it and calls `GMSServices.provideAPIKey` and `PlacesClient.provideAPIKey`.

| Key present | Map | Geocoding |
|---|---|---|
| Yes | Google Maps | `GooglePlacesGeocoder` (cached) |
| No | "Map unavailable" message explaining how to add a key | `MockGeocoder` (cached) |

Tests never call Google.

## Map

- `GMSMapView` wrapped in a `UIViewRepresentable`; a coordinator is the `GMSMapViewDelegate`.
- **Markers are diffed by vendor ID** on each update instead of being recreated, so favorites and newly geocoded vendors update in place without flicker.
- Selection is a value with its own ID, so selecting the **same** vendor twice still recenters the map.
- Favorites use a different marker colour. Each marker's VoiceOver label is the vendor name, plus "favorite" where it applies.
- Tapping a marker shows a **SwiftUI card** for the vendor instead of Google's info window, so it matches the app's styling and dark mode. Tapping the map closes it.
- **Map → list:** tapping the card switches to the list, scrolls to that vendor and highlights it. If the search or filter would hide the vendor, they are cleared first.
- Map controls: re-frame all vendors, and switch between standard and satellite.
- The Maps SDK follows the system appearance, so light/dark switches live without extra code.

## Session token and Keychain

- `KeychainTokenStore`: generic password, fixed service/account, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (not backed up, not synced, unreadable while the device is locked).
- The API client **reads the token from the store on every request** rather than holding it in memory.
- Settings shows the token masked with a reveal toggle, plus Save and Clear (with confirmation). Saving or clearing reloads vendors immediately.
- A 401 clears the list and shows **Session required → Open Settings**, so data is never left on screen after the session is rejected.

## Search and filter

The list has a search bar (name or address, ignoring case and accents) and **All / Favorites** chips with a live count. The filtering lives in the view model as a computed `visibleVendors`, so it is unit-tested without any UI. An empty result says why: no search matches, or no favorites yet.

## Favorites

Toggling is **optimistic**: the heart updates immediately, and rolls back with an alert if the save fails. Favorites are stored locally as overrides on top of the API data (`UserDefaults`), since the stub API is read-only.

## Testing

XCTest only, 40 tests, no network or Google calls:

| Suite | Covers |
|---|---|
| `VendorDecodingTests` | Full vendor, missing coordinate, ISO 8601 dates, malformed JSON |
| `VendorsViewModelTests` | Load states, empty, errors, 401 clearing content, selection (incl. re-selecting the same vendor), optimistic favorites + rollback, geocoding only missing coordinates, a failed geocode not dropping the vendor, search (case/accent-insensitive), the favorites filter, revealing a vendor hidden by filters |
| `StubAPIClientTests` | 401 without token, success, 500, offline — through the real `URLSession` client |
| `CachingGeocoderTests` | Cache hits, address normalisation, in-flight sharing, failures not cached |
| `KeychainTokenStoreTests` | Save, read, overwrite, clear (isolated service per run) |
| `SettingsViewModelTests` | Masking, trimming, save/clear and reload notification |

## Deviations from the brief

- **iOS 17.0 instead of iOS 16.0.** Xcode 27 can't target iOS 16. Once iOS 17 was the floor, I used it deliberately: view models use the Observation framework (`@Observable`) rather than `ObservableObject`. Everything else would work on iOS 16.
- **Xcode 27 instead of Xcode 15+.** The Google Maps/Places SDKs (10+) need Xcode 26 or later, and the project was created with Xcode 27.

## Trade-offs and what I'd do next

- **Stub configuration is global** (`StubURLProtocol.configuration`). It's thread-safe, but tests that change it can't run in parallel. Acceptable for a local stub; a real backend would remove it.
- **Favorites are local only.** With a real API this becomes a `PUT`, and the existing optimistic update/rollback already handles failure.
- **No offline cache of vendors.** Offline shows a friendly error with retry. Next step: persist the last successful response and show it with a "last updated" banner.
- **`VendorsViewModel` owns loading, geocoding and favorites.** Fine at this size; if it grew, geocoding would move into its own coordinator.
- **No user location / "nearby" sorting.** Not required by any task, and it adds a permission flow. Next step: `CLLocationManager` behind a protocol and sort by distance.
- **No vendor images.** The API has no image URLs, so each vendor gets a coloured initials tile rather than invented photos. Next step: an optional `imageURL` in the model, loaded with `AsyncImage`, keeping the initials tile as the placeholder and fallback.
- **No marker clustering** — unnecessary for ten vendors; Google's iOS Utils library would be the route at scale.
