# Mr D Vendor Locator

A SwiftUI iOS app for browsing Mr D vendors, seeing them on a Google Map, and managing a session token stored in the iOS Keychain.

Built for the Mr D Senior iOS Engineer assignment. Design decisions and trade-offs are in [SOLUTION.md](SOLUTION.md); how AI was used is in [AI_USAGE.md](AI_USAGE.md).

| Vendors | Map | Session required |
|---|---|---|
| <img src="Screenshots/vendor-list-light.png" width="220"> | <img src="Screenshots/map-light.png" width="220"> | <img src="Screenshots/session-required.png" width="220"> |
| <img src="Screenshots/vendor-list-dark.png" width="220"> | <img src="Screenshots/map-dark.png" width="220"> | |

## Features

- **Vendor list** with favorites, pull to refresh, and loading, empty and error states with friendly messages.
- **Google Map** with a marker per vendor. Tapping a vendor in the list switches to the map and recenters on it.
- **Places address → coordinates:** vendors that only have an address are geocoded with the Google Places SDK and appear on the map.
- **Session token in the Keychain**, managed from Settings (masked by default, reveal, save, clear). Every API request sends it as a Bearer token.
- **Light and dark mode**, switching live.

The API is a local stub (`StubURLProtocol`), so no backend is needed. It requires a token (any value works) and returns 401 without one.

## Requirements

- **Xcode 27** (the project was created with it; the Google Maps and Places SDKs need Xcode 26 or later).
- **iOS 17.0+** deployment target. The brief asks for iOS 16, which Xcode 27 can no longer target — see [SOLUTION.md](SOLUTION.md#deviations-from-the-brief).
- Dependencies come from Swift Package Manager and resolve on first open: Google Maps SDK and Google Places SDK for iOS (11.2.0).

## Setup

1. Clone the repo and open `MrDVendorLocator/MrDVendorLocator.xcodeproj`.
2. **Add a Google Maps Platform API key** (optional, but needed for the map):
   - In Google Cloud, enable **Maps SDK for iOS** and **Places API (New)**, and restrict the key to the bundle ID `com.baloyi.mrdvendorlocator`.
   - Create `Config/Secrets.xcconfig` (it is gitignored) containing:
     ```
     GMS_API_KEY = your_key_here
     ```
   - Without a key the app still builds and runs: the Map tab explains that no key is set, and geocoding falls back to a built-in table (`MockGeocoder`).
3. Choose an iOS 17+ simulator and run (**Cmd+R**).
4. The first launch shows **Session required**. Open **Settings**, enter any token (for example `mrD_token_example_123`) and tap **Save**. The vendors load.

### Demoing error states

In Debug builds, **Settings → Developer → Stub API response** switches the stub to a **500** or **offline** response. Pull to refresh on the Vendors tab to see it, then set it back to **Success** and tap **Try Again**.

## Tests

34 XCTest unit tests. They never call Google or the network.

- In Xcode: **Cmd+U**.
- From the command line:
  ```
  xcodebuild test \
    -project MrDVendorLocator/MrDVendorLocator.xcodeproj \
    -scheme MrDVendorLocator \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -parallel-testing-enabled NO
  ```
- With Fastlane (`bundle install` first): `bundle exec fastlane test`, or `bundle exec fastlane build` for an unsigned simulator build.

**CI:** GitHub Actions ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs the tests on every push and pull request.

## Project structure

```
Config/                     App.xcconfig (committed), Secrets.xcconfig (gitignored), Info.plist
MrDVendorLocator/
  MrDVendorLocator/
    App/                    Entry point, composition root (AppDependencies), tab view
    Core/
      Networking/           APIClient, Endpoint, APIError
      Stub/                 StubURLProtocol + vendors.json (the local API)
      Security/             TokenStore, KeychainTokenStore
      Places/               Geocoding, GooglePlacesGeocoder, CachingGeocoder, MockGeocoder
    Data/                   Vendor model, VendorRepository, FavoritesStore
    Features/               VendorList, Map, Settings (views + view models)
    Shared/                 ViewState, UserFacingError
  MrDVendorLocatorTests/    Unit tests
```
