//
//  SimpleDiaryApp.swift
//  SimpleDiary
//
//  Created by Ruben Zilibowitz on 22/11/2025.
//

import Combine
import SwiftUI

@main
struct SimpleDiaryApp: App {
    @StateObject private var authGate = AuthGate()
    @StateObject private var storeHolder = StoreHolder()

    var body: some Scene {
        WindowGroup {
            RootSwitcherView()
                .environmentObject(authGate)
                .environmentObject(storeHolder)
        }
        .windowStyle(.titleBar)
    }
}

/// Top-level view that chooses between lock screen and journal UI.
struct RootSwitcherView: View {
    @EnvironmentObject var authGate: AuthGate
    @EnvironmentObject var storeHolder: StoreHolder

    var body: some View {
        Group {
            if authGate.isUnlocked, let store = storeHolder.store {
                JournalRootView()
                    .environmentObject(store)
            } else {
                LockView()
            }
        }
    }
}

/// Holds the JournalStore so it can be created once on app startup
final class StoreHolder: ObservableObject {
    @Published var store: JournalStore?

    init() {
        do {
            self.store = try JournalStore()
        } catch {
            print("Failed to init JournalStore:", error)
            self.store = nil
        }
    }
}
