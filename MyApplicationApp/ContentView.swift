import MySDK
import SwiftUI

enum Profile: String, CaseIterable, Identifiable {
    case customer = "Customer"
    case merchant = "Merchant"

    var id: Self { self }
}

struct ContentView: View {
    @Environment(LedgerViewModel.self) private var ledger
    @Environment(NetworkMonitor.self) private var network
    @State private var profile: Profile = .customer
    @State private var showOfflineAlert = false
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !network.isOnline {
                    Label("You're offline", systemImage: "wifi.slash")
                        .font(.footnote.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(.red)
                }
                switch profile {
                case .customer: CustomerView()
                case .merchant: MerchantView()
                }
            }
            .navigationTitle(profile.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu("Switch profile", systemImage: "person.crop.circle.fill") {
                        Picker("Profile", selection: $profile) {
                            ForEach(Profile.allCases) { Text($0.rawValue).tag($0) }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset", systemImage: "arrow.counterclockwise") { confirmReset = true }
                }
            }
            .confirmationDialog("Reset the ledger?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { Task { await ledger.reset() } }
            } message: {
                Text("The customer goes back to 5000 DZD, the merchant to 0, and all history is deleted.")
            }
        }
        .animation(.default, value: network.isOnline)
        .task { await ledger.start() }
        .onChange(of: network.isOnline) { _, isOnline in
            showOfflineAlert = !isOnline
        }
        .alert("No internet connection", isPresented: $showOfflineAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You're offline. Payments are paused until your connection is back.")
        }
        .alert("Something went wrong", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(ledger.errorMessage ?? "")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { ledger.errorMessage != nil },
            set: { if !$0 { ledger.errorMessage = nil } }
        )
    }
}

#Preview {
    ContentView()
        .environment(LedgerViewModel(configuration: .init(inMemory: true)))
        .environment(NetworkMonitor())
}
