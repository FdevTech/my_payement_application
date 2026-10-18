import Foundation
import MySDK
import Observation

@Observable
final class LedgerViewModel {
    private(set) var customer: AccountSnapshot?
    private(set) var merchant: AccountSnapshot?
    private(set) var transactions: [TransactionRecord] = []
    private(set) var settlements: [SettlementRecord] = []
    private(set) var nextSettlement: Date?
    private(set) var isProcessing = false
    private(set) var lastPayment: TransactionRecord?

    var errorMessage: String?

    private let ledger: Ledger?

    var pendingTransactions: [TransactionRecord] {
        transactions.filter { $0.status == .pending }
    }

    var feeRate: Decimal { ledger?.configuration.feeRate ?? 0 }

    init(configuration: LedgerConfiguration = .default) {
        do {
            ledger = try Ledger(configuration: configuration)
        } catch {
            ledger = nil
            errorMessage = error.localizedDescription
        }
    }

    func start() async {
        guard let ledger else { return }
        await ledger.startSettlementScheduler()
        await refresh()
        for await _ in NotificationCenter.default.notifications(named: Ledger.didChangeNotification).map({ _ in () }) {
            await refresh()
        }
    }

    func pay(amountText: String) async -> Bool {
        guard let ledger else { return false }
        guard let amount = Self.parseAmount(amountText) else {
            errorMessage = LedgerError.invalidAmount.localizedDescription
            return false
        }
        isProcessing = true
        defer { isProcessing = false }
        do {
            lastPayment = try await ledger.pay(amount: amount)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func settleNow() async {
        await run { try await $0.settleNow() }
    }

    func reset() async {
        lastPayment = nil
        await run { try await $0.reset() }
    }

    static func parseAmount(_ text: String) -> Decimal? {
        let separator = Locale.current.decimalSeparator ?? "."
        let normalized = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: separator, with: ".")
        guard !normalized.isEmpty, let amount = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        return amount
    }

    private func refresh() async {
        guard let ledger else { return }
        do {
            customer = try await ledger.customerAccount()
            merchant = try await ledger.merchantAccount()
            transactions = try await ledger.transactions()
            settlements = try await ledger.settlements()
            nextSettlement = try await ledger.nextSettlementDate()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func run(_ operation: (Ledger) async throws -> Void) async {
        guard let ledger else { return }
        do {
            try await operation(ledger)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
