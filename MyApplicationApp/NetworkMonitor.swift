import Network
import Observation

@Observable
final class NetworkMonitor {
    private(set) var isOnline = true

    @ObservationIgnored private let monitor = NWPathMonitor()

    init() {
        let update: @MainActor (Bool) -> Void = { [weak self] in self?.isOnline = $0 }
        monitor.pathUpdateHandler = { @Sendable path in
            let isOnline = path.status == .satisfied
            Task { @MainActor in update(isOnline) }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }

    deinit {
        monitor.cancel()
    }
}
