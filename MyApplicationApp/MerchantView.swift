import MySDK
import SwiftUI

struct MerchantView: View {
    @Environment(LedgerViewModel.self) private var ledger

    var body: some View {
        List {
            Section("Balance") {
                LabeledContent("Available", value: Money.format(ledger.merchant?.balance ?? 0))
                    .font(.headline)
                LabeledContent("Pending", value: Money.format(ledger.merchant?.pendingBalance ?? 0))
            }

            Section {
                LabeledContent("Next settlement") {
                    if let next = ledger.nextSettlement, next > .now {
                        Text(timerInterval: Date.now...next, countsDown: true)
                            .monospacedDigit()
                    } else {
                        Text("Settling…")
                    }
                }
                Button("Settle now") { Task { await ledger.settleNow() } }
                    .disabled(ledger.pendingTransactions.isEmpty)
            } header: {
                Text("Settlement")
            } footer: {
                Text("Pending payments are settled every 5 minutes. A \((ledger.feeRate as NSDecimalNumber).doubleValue.formatted(.percent)) fee is deducted from each one.")
            }

            Section("Pending transactions") {
                if ledger.pendingTransactions.isEmpty {
                    Text("Nothing pending").foregroundStyle(.secondary)
                }
                ForEach(ledger.pendingTransactions) { transaction in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(Money.format(transaction.amount)).font(.headline)
                            Spacer()
                            Text(transaction.createdAt, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("Fee \(Money.format(transaction.fee)) · Net \(Money.format(transaction.netAmount))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Settlements") {
                if ledger.settlements.isEmpty {
                    Text("No settlements yet").foregroundStyle(.secondary)
                }
                ForEach(ledger.settlements) { settlement in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("+\(Money.format(settlement.netAmount))")
                                .font(.headline)
                            Spacer()
                            Text(settlement.executedAt, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(settlement.transactionCount) transaction(s) · Gross \(Money.format(settlement.grossAmount)) · Fees \(Money.format(settlement.totalFees))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
