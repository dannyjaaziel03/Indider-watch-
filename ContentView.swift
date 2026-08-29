import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var monitor: TokenMonitor
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingWatchlist = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryGrid
                    controls
                    statusBar
                    LazyVStack(spacing: 12) {
                        ForEach(monitor.signals) { signal in
                            SignalCard(signal: signal)
                        }
                    }
                    disclosure
                }
                .padding()
            }
            .navigationTitle("Insider Watch")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingWatchlist = true } label: { Image(systemName: "list.bullet") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await monitor.refresh() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }.disabled(monitor.isLoading)
                }
            }
            .sheet(isPresented: $showingWatchlist) { WatchlistView() }
            .refreshable { await monitor.refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await monitor.refresh() } }
            }
        }
    }

    private var summaryGrid: some View {
        HStack(spacing: 10) {
            SummaryTile(title: "Buy Watch", value: "\(monitor.signals.filter { $0.status == .buyWatch }.count)")
            SummaryTile(title: "High Risk", value: "\(monitor.signals.filter { $0.status == .highRisk }.count)")
            SummaryTile(title: "Updated", value: monitor.lastUpdated?.formatted(date: .omitted, time: .shortened) ?? "—")
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Toggle("Auto-refresh every 60s", isOn: $monitor.autoRefresh)
            Button {
                Task { await monitor.requestNotifications() }
            } label: {
                Label("Enable alerts", systemImage: "bell.badge")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            if monitor.isLoading { ProgressView().controlSize(.small) }
            Text(monitor.statusMessage).font(.footnote).foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var disclosure: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Signal meaning").font(.headline)
            Text("BUY WATCH means several public market signals align. HIGH RISK means selling, price, or liquidity risk is elevated. These signals are not proof of insider activity and are not investment advice.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct SummaryTile: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Text(value).font(.title3.bold()).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .padding(.horizontal, 6)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct SignalCard: View {
    let signal: TokenSignal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(signal.symbol).font(.title3.bold())
                    Text(signal.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Text(signal.status.rawValue)
                    .font(.caption2.bold())
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(statusColor.opacity(0.18), in: Capsule())
                    .foregroundStyle(statusColor)
            }

            if signal.status != .noData {
                HStack(alignment: .firstTextBaseline) {
                    Text(CurrencyFormatter.price(signal.priceUSD)).font(.title2.bold())
                    Spacer()
                    Text(String(format: "%+.1f%% / 5m", signal.priceChange5m))
                        .font(.subheadline.bold())
                        .foregroundStyle(signal.priceChange5m >= 0 ? Color.green : Color.red)
                }

                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                    GridRow { metric("Market cap", CurrencyFormatter.compact(signal.marketCap)); metric("Liquidity", CurrencyFormatter.compact(signal.liquidity)) }
                    GridRow { metric("5m buys", "\(signal.buys5m)"); metric("5m sells", "\(signal.sells5m)") }
                    GridRow { metric("5m volume", CurrencyFormatter.compact(signal.volume5m)); metric("Score", signal.score > 0 ? "+\(signal.score)" : "\(signal.score)") }
                }
            }

            Text(signal.reasons.joined(separator: " • "))
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let url = signal.chartURL {
                Link(destination: url) { Label("Open chart", systemImage: "arrow.up.right.square") }
                    .font(.footnote.bold())
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.bold()).lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusColor: Color {
        switch signal.status {
        case .buyWatch: return .green
        case .highRisk: return .red
        case .neutral: return .orange
        case .noData: return .secondary
        }
    }
}
