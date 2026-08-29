import SwiftUI

struct WatchlistView: View {
    @EnvironmentObject private var monitor: TokenMonitor
    @Environment(\.dismiss) private var dismiss
    @State private var tokenAddress = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Add Solana token") {
                    TextField("Token address", text: $tokenAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Add to watchlist") {
                        monitor.addToken(tokenAddress)
                        tokenAddress = ""
                    }
                    .disabled(tokenAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("Watchlist") {
                    ForEach(monitor.watchlist, id: \.self) { address in
                        Text(address).font(.caption.monospaced()).textSelection(.enabled)
                    }
                    .onDelete(perform: monitor.removeTokens)
                }
            }
            .navigationTitle("Watchlist")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
