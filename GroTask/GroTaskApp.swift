import SwiftUI

@main
struct GroTaskApp: App {
    var body: some Scene {
        MenuBarExtra("GroTask", systemImage: "checklist") {
            Text("GroTask is loading...")
                .padding()
        }
        .menuBarExtraStyle(.window)
    }
}
