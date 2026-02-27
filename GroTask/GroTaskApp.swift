import SwiftUI

@main
struct GroTaskApp: App {
    @State private var store = TaskStore()

    var body: some Scene {
        MenuBarExtra("GroTask", systemImage: "checklist") {
            TaskPopoverView(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
