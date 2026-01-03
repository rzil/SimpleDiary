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
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
        .windowStyle(.titleBar)
        .commands {
            AppMenuCommands(appState: appState)
            VaultsMenuCommands(appState: appState)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        Group {
            switch appState.mode {
            case .initializing:
                ProgressView("Loading…")
                    .task {
                        await appState.initialize()
                    }
            case .needsSetup:
                SetupPasswordView()
            case .locked:
                UnlockView()
            case .unlocked:
                if let store = appState.journalStore {
                    JournalRootView()
                        .environmentObject(store)
                } else {
                    Text("Error: No store")
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                appState.lock()
            }
        }
        .onReceive(
            Timer.publish(every: 30, on: .main, in: .common).autoconnect()
        ) { _ in
            appState.checkIdleLock()
        }
    }
}
