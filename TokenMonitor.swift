import Foundation
import UserNotifications

@MainActor
final class TokenMonitor: ObservableObject {
    @Published var signals: [TokenSignal] = []
    @Published var isLoading = false
    @Published var statusMessage = "Ready."
    @Published var lastUpdated: Date?
    @Published var autoRefresh = true {
        didSet { configureTimer() }
    }
    @Published var watchlist: [String] {
        didSet { UserDefaults.standard.set(watchlist, forKey: Self.watchlistKey) }
    }

    static let defaults = [
        "Ai66LHZG9MCzg1WKdawwqduVAX",
        "9cRCn9rGT8V2imeM2BaKs13yhMEais3ruM3rPvTGpump",
        "DuVgdHeEk7ejWPxWY5G3PQA99oEGGLmnbWuWWxpEpump",
        "FCaPNUJbWfECeeCeA3tvqkGUQ1BFPuon71KphJM5pump"
    ]

    private static let watchlistKey = "watchlist.v1"
    private let service = DexScreenerService()
    private let config = ScoreConfig()
    private var previousLiquidity: [String: Double] = [:]
    private var previousStatus: [String: SignalStatus] = [:]
    private var timer: Timer?

    init() {
        self.watchlist = UserDefaults.standard.stringArray(forKey: Self.watchlistKey) ?? Self.defaults
        configureTimer()
        Task { await refresh() }
    }

    deinit { timer?.invalidate() }

    func configureTimer() {
        timer?.invalidate()
        timer = nil
        guard autoRefresh else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    func addToken(_ raw: String) {
        let address = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty, !watchlist.contains(address) else { return }
        watchlist.append(address)
        Task { await refresh() }
    }

    func removeTokens(at offsets: IndexSet) {
        watchlist.remove(atOffsets: offsets)
        Task { await refresh() }
    }

    func requestNotifications() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            statusMessage = granted ? "Alerts enabled." : "Notifications were not enabled."
        } catch {
            statusMessage = "Could not enable alerts: \(error.localizedDescription)"
        }
    }

    func refresh() async {
        guard !isLoading else { return }
        guard !watchlist.isEmpty else {
            signals = []
            statusMessage = "Add a Solana token to start."
            return
        }

        isLoading = true
        statusMessage = "Checking live market data…"
        defer { isLoading = false }

        do {
            let pairs = try await service.fetchPairs(for: watchlist)
            let selected = selectBestPairs(pairs)
            var newSignals: [TokenSignal] = []

            for token in watchlist {
                if let pair = selected[token] {
                    let signal = score(token: token, pair: pair)
                    newSignals.append(signal)
                    await notifyOnTransition(signal)
                    previousLiquidity[token] = signal.liquidity
                    previousStatus[token] = signal.status
                } else {
                    newSignals.append(TokenSignal(
                        tokenAddress: token,
                        symbol: shortened(token), name: "No active DEX pair found",
                        priceUSD: 0, marketCap: 0, liquidity: 0,
                        buys5m: 0, sells5m: 0, volume5m: 0, priceChange5m: 0,
                        score: 0, status: .noData, reasons: ["No active Solana DEX pair was returned."], chartURL: nil
                    ))
                }
            }

            signals = newSignals
            lastUpdated = Date()
            statusMessage = "Live scan complete."
        } catch {
            statusMessage = "Could not load live data: \(error.localizedDescription)"
        }
    }

    private func selectBestPairs(_ pairs: [DexPair]) -> [String: DexPair] {
        var output: [String: DexPair] = [:]
        let tracked = Set(watchlist)
        for pair in pairs where pair.chainId == "solana" {
            let addresses = [pair.baseToken?.address, pair.quoteToken?.address].compactMap { $0 }
            for address in addresses where tracked.contains(address) {
                let currentLiq = output[address]?.liquidity?.usd ?? -1
                let candidateLiq = pair.liquidity?.usd ?? 0
                if output[address] == nil || candidateLiq > currentLiq { output[address] = pair }
            }
        }
        return output
    }

    private func score(token: String, pair: DexPair) -> TokenSignal {
        let tx = pair.txns?.m5
        let buys = tx?.buys ?? 0
        let sells = tx?.sells ?? 0
        let total = buys + sells
        let volume5m = pair.volume?.m5 ?? 0
        let volume1h = pair.volume?.h1 ?? 0
        let priceChange5m = pair.priceChange?.m5 ?? 0
        let liquidity = pair.liquidity?.usd ?? 0

        var score = 0
        var reasons: [String] = []

        if total >= config.minTransactions && Double(buys) >= max(3, Double(sells) * 1.5) {
            score += 2; reasons.append("Buy pressure \(buys)B/\(sells)S")
        }
        if priceChange5m >= config.priceSpikePercent {
            score += 2; reasons.append(String(format: "Price +%.1f%% in 5m", priceChange5m))
        }
        let fiveMinuteAverage = volume1h / 12
        if fiveMinuteAverage > 0 && volume5m >= fiveMinuteAverage * config.volumeVelocityMultiplier {
            score += 2; reasons.append(String(format: "Volume velocity %.1fx", volume5m / fiveMinuteAverage))
        }
        if priceChange5m <= -config.priceDumpPercent {
            score -= 3; reasons.append(String(format: "Price %.1f%% in 5m", priceChange5m))
        }
        if total >= config.minTransactions && Double(sells) >= max(3, Double(buys) * 2) {
            score -= 2; reasons.append("Sell pressure \(buys)B/\(sells)S")
        }
        if let old = previousLiquidity[token], old > 0 {
            let change = (liquidity - old) / old * 100
            if change >= config.liquidityAddPercent {
                score += 1; reasons.append(String(format: "Liquidity +%.1f%%", change))
            }
            if change <= -config.liquidityDropPercent {
                score -= 5; reasons.append(String(format: "LIQUIDITY DROP %.1f%%", change))
            }
        }
        if liquidity > 0 && liquidity < config.lowLiquidityUSD {
            score -= 1; reasons.append("Low liquidity \(CurrencyFormatter.compact(liquidity))")
        }

        let status: SignalStatus = score >= config.buyWatch ? .buyWatch : (score <= config.highRisk ? .highRisk : .neutral)
        let tokenInfo = pair.baseToken?.address == token ? pair.baseToken : pair.quoteToken
        let price = Double(pair.priceUsd ?? "") ?? 0

        return TokenSignal(
            tokenAddress: token,
            symbol: tokenInfo?.symbol ?? shortened(token),
            name: tokenInfo?.name ?? token,
            priceUSD: price,
            marketCap: pair.marketCap ?? pair.fdv ?? 0,
            liquidity: liquidity,
            buys5m: buys,
            sells5m: sells,
            volume5m: volume5m,
            priceChange5m: priceChange5m,
            score: score,
            status: status,
            reasons: reasons.isEmpty ? ["No strong trigger"] : reasons,
            chartURL: pair.url.flatMap(URL.init(string:))
        )
    }

    private func notifyOnTransition(_ signal: TokenSignal) async {
        guard let old = previousStatus[signal.tokenAddress], old != signal.status,
              signal.status == .buyWatch || signal.status == .highRisk else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(signal.symbol): \(signal.status.rawValue)"
        content.body = signal.reasons.joined(separator: " • ")
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func shortened(_ value: String) -> String {
        guard value.count > 10 else { return value }
        return "\(value.prefix(6))…\(value.suffix(4))"
    }
}

enum CurrencyFormatter {
    static func compact(_ value: Double) -> String {
        let sign = value < 0 ? "-" : ""
        let n = abs(value)
        if n >= 1_000_000_000 { return String(format: "%@$%.2fB", sign, n / 1_000_000_000) }
        if n >= 1_000_000 { return String(format: "%@$%.2fM", sign, n / 1_000_000) }
        if n >= 1_000 { return String(format: "%@$%.1fK", sign, n / 1_000) }
        return String(format: "%@$%.2f", sign, n)
    }

    static func price(_ value: Double) -> String {
        if value == 0 { return "$0" }
        if value < 0.000001 { return String(format: "$%.3e", value) }
        if value < 0.01 { return String(format: "$%.8f", value) }
        return String(format: "$%.4f", value)
    }
}
