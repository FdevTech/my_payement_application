import SwiftUI

@main
struct MyApplicationAppApp: App {
    @State private var ledger = LedgerViewModel()
    @State private var network = NetworkMonitor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(ledger)
                .environment(network)
        }
    }
}
