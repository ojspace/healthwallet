//
//  HealthwalletApp.swift
//  Healthwallet
//
//  Created by oj on 24.01.26.
//

import SwiftUI
import RevenueCat

@main
struct HealthwalletApp: App {
    private static func infoPlistString(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    init() {
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif

        let apiKey = Self.infoPlistString("REVENUECAT_API_KEY") ?? ""

        #if DEBUG
        precondition(!apiKey.isEmpty, "Missing REVENUECAT_API_KEY in Info.plist")
        #else
        precondition(!apiKey.isEmpty, "Missing REVENUECAT_API_KEY in Info.plist")
        precondition(!apiKey.hasPrefix("test_"), "Release build must not use a RevenueCat test key")
        #endif

        Purchases.configure(withAPIKey: apiKey)
        Purchases.shared.delegate = RevenueCatDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
