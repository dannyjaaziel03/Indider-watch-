import Foundation

struct DexPair: Codable, Identifiable {
    let chainId: String?
    let dexId: String?
    let url: String?
    let pairAddress: String?
    let baseToken: DexToken?
    let quoteToken: DexToken?
    let priceUsd: String?
    let txns: TimeWindowTransactions?
    let volume: TimeWindowValues?
    let priceChange: TimeWindowValues?
    let liquidity: Liquidity?
    let fdv: Double?
    let marketCap: Double?
    let pairCreatedAt: Double?

    var id: String { pairAddress ?? url ?? UUID().uuidString }
}

struct DexToken: Codable {
    let address: String?
    let name: String?
    let symbol: String?
}

struct TransactionCounts: Codable {
    let buys: Int?
    let sells: Int?
}

struct TimeWindowTransactions: Codable {
    let m5: TransactionCounts?
    let h1: TransactionCounts?
    let h6: TransactionCounts?
    let h24: TransactionCounts?
}

struct TimeWindowValues: Codable {
    let m5: Double?
    let h1: Double?
    let h6: Double?
    let h24: Double?
}

struct Liquidity: Codable {
    let usd: Double?
    let base: Double?
    let quote: Double?
}

enum SignalStatus: String, Codable {
    case buyWatch = "BUY WATCH"
    case neutral = "NEUTRAL"
    case highRisk = "HIGH RISK"
    case noData = "NO DATA"
}

struct TokenSignal: Identifiable {
    let tokenAddress: String
    let symbol: String
    let name: String
    let priceUSD: Double
    let marketCap: Double
    let liquidity: Double
    let buys5m: Int
    let sells5m: Int
    let volume5m: Double
    let priceChange5m: Double
    let score: Int
    let status: SignalStatus
    let reasons: [String]
    let chartURL: URL?

    var id: String { tokenAddress }
}

struct ScoreConfig {
    let buyWatch = 4
    let highRisk = -3
    let minTransactions = 8
    let priceSpikePercent = 5.0
    let priceDumpPercent = 10.0
    let volumeVelocityMultiplier = 2.0
    let liquidityAddPercent = 10.0
    let liquidityDropPercent = 20.0
    let lowLiquidityUSD = 10_000.0
}
