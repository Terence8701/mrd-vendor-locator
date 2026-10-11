//
//  GoogleMapsPlatform.swift
//  MrDVendorLocator
//

import Foundation
import GoogleMaps
import GooglePlacesSwift

/// Reads the Google Maps Platform key and hands it to the Maps and Places SDKs.
enum GoogleMapsPlatform {
    /// The key from Info.plist (`GMSApiKey`, filled from `Secrets.xcconfig`),
    /// or `nil` when none is configured. Never log the returned value.
    static func apiKey(in bundle: Bundle = .main) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: "GMSApiKey") as? String else { return nil }
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let isPlaceholder = key.isEmpty || key == "PASTE_YOUR_KEY_HERE" || key.hasPrefix("$(")
        return isPlaceholder ? nil : key
    }

    static func configure(apiKey: String) {
        GMSServices.provideAPIKey(apiKey)
        _ = PlacesClient.provideAPIKey(apiKey)
    }
}
