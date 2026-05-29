import SwiftUI
import Foundation
import AppKit

@main
struct DataAuditApp: App {
    
    init() {
        // Force the app to become the active foreground application
        // This is necessary when running via `swift run` from the terminal
        // otherwise keyboard focus stays in the terminal.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

