import MySDK
import SwiftUI

struct CustomerView: View {
    @Environment(LedgerViewModel.self) private var ledger
    @Environment(NetworkMonitor.self) private var network
    @State private var amountText = ""
    @FocusState private var amountFocused: Bool

    private var amount: Decimal? { LedgerViewModel.parseAmount(amountText) }
    private var balance: Decimal { ledger.customer?.balance ?? 0 }

    private var validationMessage: String? {
        guard !amountText.isEmpty else { return nil }
        guard let amount, amount > 0 else { return "Enter a valid amount." }
        if amount > balance { return "This is more than your balance." }
        return nil
    }

    var body: some View {
        List {
            Section("Balance") {
                Text(Money.format(balance))
                    .font(.largeTitle.bold())
                    .contentTransition(.numericText())
            }

            Section {
                TextField("Amount (DZD)", text: $amountText)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                if let validationMessage {
                    Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                }
                Button(action: pay) {
                    HStack {
                        Text("Pay merchant")
                        Spacer()
                        if ledger.isProcessing { ProgressView() }
                    }
                }
                .disabled(amount == nil || ledger.isProcessing || !network.isOnline)
            } header: {
                Text("New payment")
            } footer: {
                if !network.isOnline {
                    Text("Payments are paused while you're offline.")
                } else if let payment = ledger.lastPayment {
                    Label("Paid \(Money.format(payment.amount)). Pending until the next settlement.", systemImage: "checkmark.circle.fill")
                }
            }

            Section("History") {
                if ledger.transactions.isEmpty {
                    Text("No payments yet").foregroundStyle(.secondary)
                }
                ForEach(ledger.transactions) { transaction in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(Money.format(transaction.amount))
                            Text(transaction.createdAt, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusBadge(status: transaction.status)
                    }
                }
            }
        }
        .animation(.default, value: balance)
    }

    private func pay() {
        amountFocused = false
        Task {
            if await ledger.pay(amountText: amountText) {
                amountText = ""
            }
        }
    }
}

struct StatusBadge: View {
    let status: TransactionStatus

    var body: some View {
        Text(status == .pending ? "Pending" : "Settled")
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.15), in: .capsule)
            .foregroundStyle(.secondary)
    }
}
